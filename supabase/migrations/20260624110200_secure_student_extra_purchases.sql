-- =============================================================================
-- Secure Extra entitlements after online-payments checkout/webhook work
-- =============================================================================
-- Students may read their own confirmed grants, but they must not be able to
-- self-insert or self-update student_extra_purchases through PostgREST. Online
-- purchases are fulfilled by service-role webhook/RPC; staff writes continue to
-- use student_extra_purchases_staff_all.
-- =============================================================================

DROP POLICY IF EXISTS student_extra_purchases_student_insert_own
  ON public.student_extra_purchases;

DROP POLICY IF EXISTS student_extra_purchases_student_update_own
  ON public.student_extra_purchases;
