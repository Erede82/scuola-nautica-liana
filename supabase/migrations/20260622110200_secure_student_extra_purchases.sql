-- =============================================================================
-- Secure Extra entitlements against client-side self-grants
-- =============================================================================
-- Entitlement rows must be written only by staff/server-side fulfillment. Earlier
-- bootstrap policies allowed students to INSERT/UPDATE their own rows, which lets
-- any authenticated student mint or restore paid videocourse access directly.
-- =============================================================================

DROP POLICY IF EXISTS student_extra_purchases_student_insert_own
  ON public.student_extra_purchases;

DROP POLICY IF EXISTS student_extra_purchases_student_update_own
  ON public.student_extra_purchases;

COMMENT ON TABLE public.student_extra_purchases IS
  'Extra/videocourse entitlements. Students may read their rows, but writes are reserved to staff/server fulfillment.';
