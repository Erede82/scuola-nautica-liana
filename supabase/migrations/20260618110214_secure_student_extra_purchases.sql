-- =============================================================================
-- Secure Extra purchases: only staff/server-side confirmation may write grants.
-- =============================================================================
-- Earlier checkout scaffolding let an authenticated student insert or update their
-- own student_extra_purchases rows. Because status defaults to 'purchased', a
-- direct Supabase request could unlock paid videocorsi without PSP confirmation.
-- Keep student SELECT for the app, but remove all student-side writes.
-- =============================================================================

DROP POLICY IF EXISTS student_extra_purchases_student_insert_own
  ON public.student_extra_purchases;

DROP POLICY IF EXISTS student_extra_purchases_student_update_own
  ON public.student_extra_purchases;

ALTER TABLE public.student_extra_purchases
  ALTER COLUMN status DROP DEFAULT;

COMMENT ON TABLE public.student_extra_purchases IS
  'Extra videocourse purchase/access grants. Students may read their grants only; writes require staff policy or server-side payment confirmation.';
