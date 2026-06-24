-- =============================================================================
-- Extra entitlements: only staff or server-side payment fulfillment may write.
--
-- The original phase-1 checkout allowed students to INSERT/UPDATE their own
-- student_extra_purchases rows. With paid Extra access now represented by
-- online_orders + service-role fulfillment, those policies let a normal student
-- self-grant purchased video access through direct PostgREST calls.
-- =============================================================================

DROP POLICY IF EXISTS student_extra_purchases_student_insert_own
  ON public.student_extra_purchases;

DROP POLICY IF EXISTS student_extra_purchases_student_update_own
  ON public.student_extra_purchases;

COMMENT ON TABLE public.student_extra_purchases IS
  'Extra/videocourse entitlements. Client students may read their own rows; writes are staff-only or service-role fulfillment.';
