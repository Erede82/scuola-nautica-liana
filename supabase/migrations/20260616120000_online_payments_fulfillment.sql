-- =============================================================================
-- Pagamenti online — fulfillment server-side (P4C.2)
--
-- RPC e helper per sblocco videocorsi/extra dopo pagamento confermato (Stripe webhook).
-- Separato da Contabilità: non tocca payments, record_payment,
-- student_financial_summaries, policy RLS student_extra_purchases.
--
-- Idempotente. Solo service_role può eseguire le RPC esposte.
-- Nessuna Edge Function in questa migration.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Contatore progressivo order_code (ONL-YYYY-NNNNN) — uso interno server-side
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.online_order_code_counters (
  year integer PRIMARY KEY
    CHECK (year >= 2020 AND year <= 9999),
  last_value integer NOT NULL DEFAULT 0
    CHECK (last_value >= 0)
);

COMMENT ON TABLE public.online_order_code_counters IS
  'Contatore annuale per generate_online_order_code(). Solo uso interno (service role / RPC).';

ALTER TABLE public.online_order_code_counters ENABLE ROW LEVEL SECURITY;

-- Nessuna policy client: accesso via funzioni SECURITY DEFINER / service role.

-- ---------------------------------------------------------------------------
-- Helper: prodotti da sbloccare (allineato a ExtraBundleCatalog Dart)
--   ex-bundle → ex-bundle, ex-theory, ex-chart, ex-drive
--   altro     → [product_id]
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.extra_products_to_grant_on_access(p_product_id text)
RETURNS text[]
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $$
  SELECT CASE
    WHEN p_product_id = 'ex-bundle' THEN
      ARRAY['ex-bundle', 'ex-theory', 'ex-chart', 'ex-drive']::text[]
    ELSE
      ARRAY[p_product_id]::text[]
  END;
$$;

COMMENT ON FUNCTION public.extra_products_to_grant_on_access(text) IS
  'Replica SQL di ExtraBundleCatalog.productsToGrantOnAccess (Flutter). '
  'Helper interno per fulfill_extra_online_order.';

REVOKE ALL ON FUNCTION public.extra_products_to_grant_on_access(text) FROM PUBLIC;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    REVOKE ALL ON FUNCTION public.extra_products_to_grant_on_access(text) FROM anon;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    REVOKE ALL ON FUNCTION public.extra_products_to_grant_on_access(text) FROM authenticated;
  END IF;
END
$$;

-- ---------------------------------------------------------------------------
-- Helper: genera order_code server-side (es. ONL-2026-00001)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.generate_online_order_code()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_year integer;
  v_seq integer;
BEGIN
  v_year := extract(year FROM timezone('utc', now()))::integer;

  INSERT INTO public.online_order_code_counters AS counters (year, last_value)
  VALUES (v_year, 1)
  ON CONFLICT (year) DO UPDATE
    SET last_value = counters.last_value + 1
  RETURNING last_value INTO v_seq;

  RETURN 'ONL-' || v_year::text || '-' || lpad(v_seq::text, 5, '0');
END;
$$;

COMMENT ON FUNCTION public.generate_online_order_code() IS
  'Genera codice ordine progressivo ONL-YYYY-NNNNN (UTC). Solo service_role (Edge Function checkout).';

REVOKE ALL ON FUNCTION public.generate_online_order_code() FROM PUBLIC;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    REVOKE ALL ON FUNCTION public.generate_online_order_code() FROM anon;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    REVOKE ALL ON FUNCTION public.generate_online_order_code() FROM authenticated;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
    GRANT EXECUTE ON FUNCTION public.generate_online_order_code() TO service_role;
  END IF;
END
$$;

-- ---------------------------------------------------------------------------
-- RPC: fulfillment ordine extra_video pagato → student_extra_purchases
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fulfill_extra_online_order(p_order_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order public.online_orders%ROWTYPE;
  v_products text[];
  v_grant_product_id text;
  v_purchase_id uuid;
BEGIN
  IF p_order_id IS NULL THEN
    RAISE EXCEPTION 'fulfill_extra_online_order: order_id_required';
  END IF;

  SELECT *
  INTO v_order
  FROM public.online_orders
  WHERE id = p_order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'fulfill_extra_online_order: order_not_found';
  END IF;

  -- Idempotenza: già completato → no-op.
  IF v_order.fulfillment_status = 'completed' THEN
    RETURN;
  END IF;

  IF v_order.order_status IS DISTINCT FROM 'paid' THEN
    RAISE EXCEPTION 'fulfill_extra_online_order: order_not_paid (status=%)', v_order.order_status;
  END IF;

  IF v_order.order_kind IS DISTINCT FROM 'extra_video' THEN
    RAISE EXCEPTION 'fulfill_extra_online_order: invalid_order_kind (kind=%)', v_order.order_kind;
  END IF;

  IF v_order.student_id IS NULL THEN
    RAISE EXCEPTION 'fulfill_extra_online_order: student_id_required';
  END IF;

  IF v_order.product_id IS NULL OR btrim(v_order.product_id) = '' THEN
    RAISE EXCEPTION 'fulfill_extra_online_order: product_id_required';
  END IF;

  v_products := public.extra_products_to_grant_on_access(v_order.product_id);

  BEGIN
    FOREACH v_grant_product_id IN ARRAY v_products
    LOOP
      INSERT INTO public.student_extra_purchases (
        student_id,
        product_id,
        status,
        purchased_at,
        amount_cents,
        currency_code,
        payment_reference,
        recorded_by_staff_id
      )
      VALUES (
        v_order.student_id,
        v_grant_product_id,
        'purchased',
        timezone('utc', now()),
        v_order.amount_cents,
        v_order.currency_code,
        v_order.id::text,
        NULL
      )
      ON CONFLICT ON CONSTRAINT student_extra_purchase_unique_product DO UPDATE
      SET
        status = 'purchased',
        purchased_at = EXCLUDED.purchased_at,
        amount_cents = EXCLUDED.amount_cents,
        currency_code = EXCLUDED.currency_code,
        payment_reference = EXCLUDED.payment_reference,
        updated_at = timezone('utc', now())
      RETURNING id INTO v_purchase_id;

      INSERT INTO public.online_fulfillment_events (
        order_id,
        action,
        target_student_id,
        product_id,
        student_extra_purchase_id,
        source,
        performed_by_staff_id,
        success,
        error_message
      )
      VALUES (
        p_order_id,
        'grant_extra_access',
        v_order.student_id,
        v_grant_product_id,
        v_purchase_id,
        'stripe_webhook',
        NULL,
        true,
        NULL
      );
    END LOOP;

    UPDATE public.online_orders
    SET
      fulfillment_status = 'completed',
      fulfillment_error = NULL
    WHERE id = p_order_id;

  EXCEPTION
    WHEN OTHERS THEN
      UPDATE public.online_orders
      SET
        fulfillment_status = 'failed',
        fulfillment_error = SQLERRM
      WHERE id = p_order_id;

      INSERT INTO public.online_fulfillment_events (
        order_id,
        action,
        target_student_id,
        product_id,
        student_extra_purchase_id,
        source,
        performed_by_staff_id,
        success,
        error_message
      )
      VALUES (
        p_order_id,
        'grant_extra_access',
        v_order.student_id,
        v_order.product_id,
        NULL,
        'stripe_webhook',
        NULL,
        false,
        SQLERRM
      );

      RAISE;
  END;
END;
$$;

COMMENT ON FUNCTION public.fulfill_extra_online_order(uuid) IS
  'Sblocca videocorsi/extra per ordine online pagato (extra_video). '
  'Upsert su student_extra_purchases; audit in online_fulfillment_events. '
  'Usa payment_reference esistente (= online_orders.id::text). '
  'Non scrive su payments, non chiama record_payment, non aggiorna student_financial_summaries. '
  'Solo service_role (Edge Function stripe-webhook).';

REVOKE ALL ON FUNCTION public.fulfill_extra_online_order(uuid) FROM PUBLIC;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    REVOKE ALL ON FUNCTION public.fulfill_extra_online_order(uuid) FROM anon;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    REVOKE ALL ON FUNCTION public.fulfill_extra_online_order(uuid) FROM authenticated;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
    GRANT EXECUTE ON FUNCTION public.fulfill_extra_online_order(uuid) TO service_role;
  END IF;
END
$$;
