-- =============================================================================
-- record_payment: registrazione pagamento atomica e concorrenza-safe
-- =============================================================================
-- Evita la race read -> insert -> update fatta dal client:
-- due pagamenti concorrenti sullo stesso student_id serializzano sul lock della
-- riga student_financial_summaries e aggiornano il totale partendo dal valore
-- corrente già committato.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.record_payment(
  p_student_id uuid,
  p_amount_cents integer,
  p_method text,
  p_received_at timestamptz,
  p_notes text DEFAULT NULL,
  p_receipt_reference text DEFAULT NULL,
  p_activity_title text DEFAULT 'Pagamento registrato',
  p_activity_description text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_payment_id uuid;
  v_registration_fee_cents integer;
  v_total_paid_cents integer;
  v_currency_code text;
  v_new_total integer;
  v_new_remaining integer;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  IF NOT public.is_school_staff() THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  IF p_student_id IS NULL THEN
    RAISE EXCEPTION 'student_id_required';
  END IF;

  IF p_amount_cents IS NULL OR p_amount_cents <= 0 THEN
    RAISE EXCEPTION 'amount_cents_must_be_positive';
  END IF;

  IF p_method IS NULL OR p_method NOT IN (
    'card', 'sepaBankTransfer', 'cash', 'check', 'other'
  ) THEN
    RAISE EXCEPTION 'invalid_payment_method';
  END IF;

  IF p_received_at IS NULL THEN
    RAISE EXCEPTION 'received_at_required';
  END IF;

  -- Crea il riepilogo se manca. In caso di chiamate concorrenti, la PK su
  -- student_id rende idempotente la creazione della riga.
  INSERT INTO public.student_financial_summaries (
    student_id,
    registration_fee_cents,
    currency_code,
    total_paid_cents,
    remaining_balance_cents,
    last_updated_at
  )
  VALUES (
    p_student_id,
    0,
    'EUR',
    0,
    0,
    now()
  )
  ON CONFLICT (student_id) DO NOTHING;

  -- Lock pessimista: tutte le registrazioni pagamento per lo stesso studente
  -- vengono serializzate su questa riga prima di calcolare i nuovi aggregati.
  SELECT
    registration_fee_cents,
    total_paid_cents,
    currency_code
  INTO
    v_registration_fee_cents,
    v_total_paid_cents,
    v_currency_code
  FROM public.student_financial_summaries
  WHERE student_id = p_student_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'financial_summary_not_found';
  END IF;

  v_new_total := v_total_paid_cents + p_amount_cents;
  v_new_remaining := greatest(v_registration_fee_cents - v_new_total, 0);

  INSERT INTO public.payments (
    student_id,
    amount_cents,
    currency_code,
    received_at,
    method,
    receipt_reference,
    notes,
    recorded_by_staff_id
  )
  VALUES (
    p_student_id,
    p_amount_cents,
    v_currency_code,
    p_received_at,
    p_method,
    p_receipt_reference,
    p_notes,
    auth.uid()
  )
  RETURNING id INTO v_payment_id;

  UPDATE public.student_financial_summaries
  SET
    total_paid_cents = v_new_total,
    remaining_balance_cents = v_new_remaining,
    last_updated_at = now()
  WHERE student_id = p_student_id;

  INSERT INTO public.backoffice_activity_events (
    student_id,
    event_type,
    title,
    description,
    actor_staff_id,
    occurred_at
  )
  VALUES (
    p_student_id,
    'paymentAdded',
    coalesce(nullif(trim(p_activity_title), ''), 'Pagamento registrato'),
    p_activity_description,
    auth.uid(),
    now()
  );

  RETURN v_payment_id;
END;
$$;

COMMENT ON FUNCTION public.record_payment(
  uuid, integer, text, timestamptz, text, text, text, text
) IS
  'Registra pagamento e aggiorna student_financial_summaries in modo atomico con SELECT FOR UPDATE.';

REVOKE ALL ON FUNCTION public.record_payment(
  uuid, integer, text, timestamptz, text, text, text, text
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.record_payment(
  uuid, integer, text, timestamptz, text, text, text, text
) TO authenticated;
