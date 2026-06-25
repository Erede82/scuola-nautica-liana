-- =============================================================================
-- Extra entitlement hardening after Pagamenti online.
--
-- Only staff workflows and service-role payment fulfillment may write
-- student_extra_purchases. Students can still SELECT their own purchases, but
-- must not be able to create/update rows that unlock paid video content.
-- =============================================================================

DROP POLICY IF EXISTS student_extra_purchases_student_insert_own
  ON public.student_extra_purchases;

DROP POLICY IF EXISTS student_extra_purchases_student_update_own
  ON public.student_extra_purchases;
