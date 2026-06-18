-- =============================================================================
-- Pagamenti online — schema preparatorio (P4B)
--
-- Dominio separato da Contabilità iscrizione:
--   • nessuna tabella payments
--   • nessun RPC record_payment
--   • nessun aggiornamento student_financial_summaries
--   • nessuna modifica a student_extra_purchases
--
-- Idempotente. Nessun seed. Nessuna Edge Function.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- online_orders — testata ordine Pagamenti online
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.online_orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_code text NOT NULL UNIQUE,
  order_kind text NOT NULL
    CHECK (order_kind IN ('extra_video', 'privatist_service', 'gift', 'other')),
  product_id text
    REFERENCES public.extra_products (id) ON DELETE RESTRICT,
  amount_cents integer NOT NULL
    CHECK (amount_cents >= 0),
  currency_code text NOT NULL DEFAULT 'EUR',
  buyer_kind text NOT NULL
    CHECK (buyer_kind IN ('student', 'external', 'gift')),
  student_id uuid
    REFERENCES public.students (id) ON DELETE SET NULL,
  buyer_name text,
  buyer_email text,
  buyer_phone text,
  order_status text NOT NULL DEFAULT 'draft'
    CHECK (order_status IN (
      'draft', 'pending_payment', 'paid', 'failed', 'cancelled', 'refunded'
    )),
  fulfillment_status text NOT NULL DEFAULT 'not_applicable'
    CHECK (fulfillment_status IN (
      'not_applicable', 'pending', 'completed', 'awaiting_student_link', 'failed'
    )),
  fulfillment_error text,
  created_by_staff_id uuid,
  notes text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_online_orders_order_status_created
  ON public.online_orders (order_status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_online_orders_student_id
  ON public.online_orders (student_id);

CREATE INDEX IF NOT EXISTS idx_online_orders_buyer_email
  ON public.online_orders (buyer_email);

CREATE INDEX IF NOT EXISTS idx_online_orders_product_id
  ON public.online_orders (product_id);

CREATE INDEX IF NOT EXISTS idx_online_orders_fulfillment_status
  ON public.online_orders (fulfillment_status);

DROP TRIGGER IF EXISTS trg_online_orders_updated ON public.online_orders;
CREATE TRIGGER trg_online_orders_updated
  BEFORE UPDATE ON public.online_orders
  FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();

COMMENT ON TABLE public.online_orders IS
  'Ordini Pagamenti online (videocorsi/extra, privatisti, regali). '
  'Dominio separato da Contabilità: non scrive su payments, non usa record_payment, '
  'non aggiorna student_financial_summaries.';

-- ---------------------------------------------------------------------------
-- online_payment_transactions — movimenti PSP / link manuale
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.online_payment_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL
    REFERENCES public.online_orders (id) ON DELETE CASCADE,
  provider text NOT NULL
    CHECK (provider IN ('stripe', 'paypal', 'revolut', 'manual_link')),
  provider_checkout_session_id text UNIQUE,
  provider_payment_intent_id text UNIQUE,
  checkout_url text,
  payment_status text NOT NULL DEFAULT 'initiated'
    CHECK (payment_status IN ('initiated', 'completed', 'failed', 'refunded')),
  amount_cents integer NOT NULL
    CHECK (amount_cents >= 0),
  currency_code text NOT NULL DEFAULT 'EUR',
  paid_at timestamptz,
  raw_provider_payload jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_online_payment_transactions_order_id
  ON public.online_payment_transactions (order_id);

CREATE INDEX IF NOT EXISTS idx_online_payment_transactions_provider
  ON public.online_payment_transactions (provider);

CREATE INDEX IF NOT EXISTS idx_online_payment_transactions_checkout_session
  ON public.online_payment_transactions (provider_checkout_session_id)
  WHERE provider_checkout_session_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_online_payment_transactions_payment_intent
  ON public.online_payment_transactions (provider_payment_intent_id)
  WHERE provider_payment_intent_id IS NOT NULL;

DROP TRIGGER IF EXISTS trg_online_payment_transactions_updated
  ON public.online_payment_transactions;
CREATE TRIGGER trg_online_payment_transactions_updated
  BEFORE UPDATE ON public.online_payment_transactions
  FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();

COMMENT ON TABLE public.online_payment_transactions IS
  'Transazioni PSP collegate a online_orders. Solo staff legge raw_provider_payload. '
  'Scritture previste via service role (Edge Functions). '
  'Nessun collegamento a payments o record_payment.';

COMMENT ON COLUMN public.online_payment_transactions.raw_provider_payload IS
  'Payload provider (Stripe ecc.) — visibilità riservata allo staff; '
  'nessuna policy SELECT allievo su questa tabella.';

-- ---------------------------------------------------------------------------
-- online_fulfillment_events — audit sblocco / collegamento (append-only)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.online_fulfillment_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL
    REFERENCES public.online_orders (id) ON DELETE CASCADE,
  action text NOT NULL,
  target_student_id uuid
    REFERENCES public.students (id) ON DELETE SET NULL,
  product_id text
    REFERENCES public.extra_products (id) ON DELETE SET NULL,
  student_extra_purchase_id uuid,
  source text NOT NULL
    CHECK (source IN ('stripe_webhook', 'staff_manual', 'system')),
  performed_by_staff_id uuid,
  success boolean NOT NULL DEFAULT true,
  error_message text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_online_fulfillment_events_order_id
  ON public.online_fulfillment_events (order_id);

CREATE INDEX IF NOT EXISTS idx_online_fulfillment_events_target_student
  ON public.online_fulfillment_events (target_student_id);

COMMENT ON TABLE public.online_fulfillment_events IS
  'Audit fulfillment Pagamenti online (grant extra, link studente, errori). '
  'student_extra_purchase_id è soft link senza FK — collegamento opzionale in fase P4C+. '
  'Non modifica Contabilità né student_financial_summaries.';

COMMENT ON COLUMN public.online_fulfillment_events.student_extra_purchase_id IS
  'Riferimento opzionale a student_extra_purchases.id — senza FK in P4B.';

-- ---------------------------------------------------------------------------
-- online_payment_webhook_events — idempotenza webhook (service role only)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.online_payment_webhook_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider text NOT NULL DEFAULT 'stripe',
  provider_event_id text NOT NULL UNIQUE,
  event_type text NOT NULL,
  processed_at timestamptz,
  order_id uuid
    REFERENCES public.online_orders (id) ON DELETE SET NULL,
  payload jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_online_payment_webhook_events_provider_event
  ON public.online_payment_webhook_events (provider_event_id);

CREATE INDEX IF NOT EXISTS idx_online_payment_webhook_events_order_id
  ON public.online_payment_webhook_events (order_id);

COMMENT ON TABLE public.online_payment_webhook_events IS
  'Registro idempotenza webhook PSP. RLS attivo senza policy client: '
  'solo service role (Edge Function stripe-webhook). '
  'Separato da Contabilità e da record_payment.';

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
ALTER TABLE public.online_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.online_payment_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.online_fulfillment_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.online_payment_webhook_events ENABLE ROW LEVEL SECURITY;

-- online_orders: staff gestione completa; allievo SELECT propri ordini.
DROP POLICY IF EXISTS online_orders_staff_all ON public.online_orders;
CREATE POLICY online_orders_staff_all
  ON public.online_orders
  FOR ALL
  USING (public.is_school_staff())
  WITH CHECK (public.is_school_staff());

DROP POLICY IF EXISTS online_orders_student_select_own ON public.online_orders;
CREATE POLICY online_orders_student_select_own
  ON public.online_orders
  FOR SELECT
  USING (
    student_id IS NOT NULL
    AND public.is_own_student(student_id)
  );

-- online_payment_transactions: solo staff (raw_provider_payload non esposto agli allievi).
DROP POLICY IF EXISTS online_payment_transactions_staff_all
  ON public.online_payment_transactions;
CREATE POLICY online_payment_transactions_staff_all
  ON public.online_payment_transactions
  FOR ALL
  USING (public.is_school_staff())
  WITH CHECK (public.is_school_staff());

-- online_fulfillment_events: staff gestione completa.
DROP POLICY IF EXISTS online_fulfillment_events_staff_all
  ON public.online_fulfillment_events;
CREATE POLICY online_fulfillment_events_staff_all
  ON public.online_fulfillment_events
  FOR ALL
  USING (public.is_school_staff())
  WITH CHECK (public.is_school_staff());

-- online_payment_webhook_events: nessuna policy authenticated/anon (default deny).
-- Service role bypassa RLS per INSERT/UPDATE da Edge Function.
