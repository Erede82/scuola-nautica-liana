-- =============================================================================
-- Extra entitlements: remove client-side student writes after Stripe fulfillment
--
-- Purchases are granted by staff workflows or service-role fulfillment only.
-- Leaving the old student INSERT/UPDATE policies active lets any authenticated
-- student self-grant a `purchased` row and unlock paid videocourses.
-- =============================================================================

DROP POLICY IF EXISTS student_extra_purchases_student_insert_own
  ON public.student_extra_purchases;

DROP POLICY IF EXISTS student_extra_purchases_student_update_own
  ON public.student_extra_purchases;
