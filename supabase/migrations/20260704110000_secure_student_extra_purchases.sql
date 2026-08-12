-- Paid Extra/video entitlements must be granted only by staff or the
-- service-role fulfillment RPC, never by a student client.
DROP POLICY IF EXISTS student_extra_purchases_student_insert_own
  ON public.student_extra_purchases;

DROP POLICY IF EXISTS student_extra_purchases_student_update_own
  ON public.student_extra_purchases;
