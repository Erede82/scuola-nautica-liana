-- =============================================================================
-- Extra purchases: remove client-side entitlement writes
-- =============================================================================
-- Purchased rows unlock paid Extra videos through extra_video_items RLS. Students
-- may read their own grants, but grants/revocations must only be written by
-- staff tools or server-side payment fulfillment.
-- =============================================================================

DROP POLICY IF EXISTS student_extra_purchases_student_insert_own
  ON public.student_extra_purchases;

DROP POLICY IF EXISTS student_extra_purchases_student_update_own
  ON public.student_extra_purchases;

COMMENT ON TABLE public.student_extra_purchases IS
  'Extra product entitlements. Students can read their own rows; writes are reserved for staff/server-side fulfillment.';
