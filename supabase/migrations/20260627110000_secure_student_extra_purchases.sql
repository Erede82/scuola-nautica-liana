-- =============================================================================
-- Secure Extra entitlements after Stripe checkout wiring
-- =============================================================================
-- Entitlements are granted by staff/service-role flows only. Students must be
-- able to read their own rows, but not create/update purchased rows directly.

DROP POLICY IF EXISTS student_extra_purchases_student_insert_own
  ON public.student_extra_purchases;

DROP POLICY IF EXISTS student_extra_purchases_student_update_own
  ON public.student_extra_purchases;
