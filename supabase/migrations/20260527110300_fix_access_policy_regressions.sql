-- =============================================================================
-- Critical access-policy regressions
-- =============================================================================
-- - keep instructor accounts inside the staff RLS boundary
-- - prevent staff users from self-granting higher roles through school_user_roles
-- - prevent students from self-recording Extra purchases and unlocking paid video URLs
-- =============================================================================

CREATE OR REPLACE FUNCTION public.is_school_staff()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.school_user_roles sur
    WHERE sur.user_id = auth.uid()
      AND sur.role IN ('admin', 'school_admin', 'staff', 'instructor')
  );
$$;

CREATE OR REPLACE FUNCTION public.is_school_role_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.school_user_roles sur
    WHERE sur.user_id = auth.uid()
      AND sur.role IN ('admin', 'school_admin')
  );
$$;

DROP POLICY IF EXISTS school_roles_staff_write ON public.school_user_roles;
CREATE POLICY school_roles_staff_write ON public.school_user_roles
  FOR INSERT
  WITH CHECK (
    public.is_school_role_admin()
    AND user_id <> auth.uid()
  );

DROP POLICY IF EXISTS school_roles_staff_update ON public.school_user_roles;
CREATE POLICY school_roles_staff_update ON public.school_user_roles
  FOR UPDATE
  USING (
    public.is_school_role_admin()
    AND user_id <> auth.uid()
  )
  WITH CHECK (
    public.is_school_role_admin()
    AND user_id <> auth.uid()
  );

DROP POLICY IF EXISTS student_extra_purchases_student_insert_own
  ON public.student_extra_purchases;
DROP POLICY IF EXISTS student_extra_purchases_student_update_own
  ON public.student_extra_purchases;

DROP POLICY IF EXISTS extra_video_items_select_purchased
  ON public.extra_video_items;
CREATE POLICY extra_video_items_select_purchased ON public.extra_video_items
  FOR SELECT USING (
    public.is_school_staff()
    OR EXISTS (
      SELECT 1
      FROM public.student_extra_purchases sep
      WHERE sep.product_id = extra_video_items.product_id
        AND sep.status = 'purchased'
        AND public.is_own_student(sep.student_id)
    )
  );

COMMENT ON FUNCTION public.is_school_role_admin IS
  'True for roles allowed to manage school_user_roles. Staff/instructor are intentionally excluded.';
