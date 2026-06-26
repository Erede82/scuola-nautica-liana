-- =============================================================================
-- Extra entitlements — client writes disabled
--
-- Purchases are granted server-side by the Stripe webhook/RPC or staff tools.
-- Authenticated students must not be able to self-insert or self-update
-- student_extra_purchases rows, otherwise they can unlock paid Extra products
-- without a completed payment.
-- =============================================================================

DROP POLICY IF EXISTS student_extra_purchases_student_insert_own
  ON public.student_extra_purchases;

DROP POLICY IF EXISTS student_extra_purchases_student_update_own
  ON public.student_extra_purchases;
