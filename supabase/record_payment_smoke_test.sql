-- =============================================================================
-- record_payment smoke test (manual, production-safe only if run on a test student)
-- =============================================================================
-- Prerequisites:
-- 1. Apply/review the production compatibility migration first.
-- 2. Replace the two placeholders below:
--    - v_staff_user_id: auth user id of an admin/staff present in school_user_roles
--    - v_student_id: existing test student id in public.students
-- 3. Run from Supabase SQL Editor only after confirming this is a test student.
--
-- This script mutates data by design:
-- - creates/updates the test student's financial summary
-- - inserts test payments through public.record_payment()
-- - inserts backoffice activity events through the RPC
--
-- Do not run on a real student/accounting record.
-- =============================================================================

DO $$
DECLARE
  v_staff_user_id uuid := '00000000-0000-0000-0000-000000000000';
  v_student_id uuid := '00000000-0000-0000-0000-000000000000';
  v_before_paid integer;
  v_after_paid integer;
  v_after_remaining integer;
  v_expected_paid integer;
  v_payment_count integer;
  v_activity_count integer;
  v_same_key_count integer;
  v_key_a text := 'smoke-a-' || extract(epoch FROM clock_timestamp())::text;
  v_key_b text := 'smoke-b-' || extract(epoch FROM clock_timestamp())::text;
  v_same_key text := 'smoke-same-' || extract(epoch FROM clock_timestamp())::text;
  v_result_a jsonb;
  v_result_b jsonb;
  v_result_c jsonb;
  v_result_d jsonb;
BEGIN
  IF v_staff_user_id = '00000000-0000-0000-0000-000000000000'::uuid THEN
    RAISE EXCEPTION 'Set v_staff_user_id before running this smoke test.';
  END IF;

  IF v_student_id = '00000000-0000-0000-0000-000000000000'::uuid THEN
    RAISE EXCEPTION 'Set v_student_id before running this smoke test.';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.students
    WHERE id = v_student_id
  ) THEN
    RAISE EXCEPTION 'Test student % does not exist.', v_student_id;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.school_user_roles
    WHERE user_id = v_staff_user_id
      AND role IN ('admin', 'staff')
  ) THEN
    RAISE EXCEPTION 'Staff user % is not admin/staff in school_user_roles.', v_staff_user_id;
  END IF;

  -- Simulate the authenticated staff context used by auth.uid().
  PERFORM set_config(
    'request.jwt.claim.sub',
    v_staff_user_id::text,
    true
  );
  PERFORM set_config(
    'request.jwt.claim.role',
    'authenticated',
    true
  );

  INSERT INTO public.student_financial_summaries (
    student_id,
    registration_fee_cents,
    currency_code,
    total_paid_cents,
    remaining_balance_cents,
    last_updated_at
  )
  VALUES (
    v_student_id,
    100000,
    'EUR',
    0,
    100000,
    now()
  )
  ON CONFLICT (student_id) DO UPDATE
  SET
    registration_fee_cents = 100000,
    remaining_balance_cents = greatest(100000 - public.student_financial_summaries.total_paid_cents, 0),
    last_updated_at = now();

  SELECT total_paid_cents
  INTO v_before_paid
  FROM public.student_financial_summaries
  WHERE student_id = v_student_id;

  -- Test 1: two distinct idempotency keys should create two payments.
  SELECT public.record_payment(
    v_student_id,
    1000,
    'cash',
    now(),
    'Smoke test distinct key A',
    NULL,
    'Smoke payment A',
    'Smoke payment A',
    v_key_a
  )
  INTO v_result_a;

  SELECT public.record_payment(
    v_student_id,
    2500,
    'cash',
    now(),
    'Smoke test distinct key B',
    NULL,
    'Smoke payment B',
    'Smoke payment B',
    v_key_b
  )
  INTO v_result_b;

  SELECT total_paid_cents, remaining_balance_cents
  INTO v_after_paid, v_after_remaining
  FROM public.student_financial_summaries
  WHERE student_id = v_student_id;

  v_expected_paid := v_before_paid + 3500;

  IF v_after_paid <> v_expected_paid THEN
    RAISE EXCEPTION 'Distinct-key test failed: total_paid_cents %, expected %.',
      v_after_paid, v_expected_paid;
  END IF;

  IF v_after_remaining <> greatest(100000 - v_after_paid, 0) THEN
    RAISE EXCEPTION 'Distinct-key test failed: remaining_balance_cents %, expected %.',
      v_after_remaining, greatest(100000 - v_after_paid, 0);
  END IF;

  SELECT count(*)
  INTO v_payment_count
  FROM public.payments
  WHERE idempotency_key IN (v_key_a, v_key_b);

  IF v_payment_count <> 2 THEN
    RAISE EXCEPTION 'Distinct-key test failed: payments count %, expected 2.',
      v_payment_count;
  END IF;

  SELECT count(*)
  INTO v_activity_count
  FROM public.backoffice_activity_events
  WHERE student_id = v_student_id
    AND title IN ('Smoke payment A', 'Smoke payment B');

  IF v_activity_count <> 2 THEN
    RAISE EXCEPTION 'Distinct-key test failed: activity count %, expected 2.',
      v_activity_count;
  END IF;

  -- Test 2: same idempotency key should not create a duplicate payment.
  SELECT public.record_payment(
    v_student_id,
    4000,
    'cash',
    now(),
    'Smoke test same key first call',
    NULL,
    'Smoke payment same key',
    'Smoke payment same key',
    v_same_key
  )
  INTO v_result_c;

  SELECT public.record_payment(
    v_student_id,
    4000,
    'cash',
    now(),
    'Smoke test same key retry',
    NULL,
    'Smoke payment same key retry',
    'Smoke payment same key retry',
    v_same_key
  )
  INTO v_result_d;

  SELECT count(*)
  INTO v_same_key_count
  FROM public.payments
  WHERE idempotency_key = v_same_key;

  IF v_same_key_count <> 1 THEN
    RAISE EXCEPTION 'Same-key test failed: payments count %, expected 1.',
      v_same_key_count;
  END IF;

  RAISE NOTICE 'record_payment smoke test passed. result_a=%, result_b=%, result_c=%, result_d=%',
    v_result_a,
    v_result_b,
    v_result_c,
    v_result_d;
END
$$;
