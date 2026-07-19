-- Internal staff notes must never cross the student API boundary. Students
-- read a deliberately limited projection; staff retain direct table access
-- through the existing staff RLS policy.
CREATE OR REPLACE FUNCTION public.list_my_assigned_quizzes()
RETURNS TABLE (
  id uuid,
  public_code text,
  student_id uuid,
  student_user_id uuid,
  license_category text,
  title text,
  status text,
  question_count integer,
  repeat_policy text,
  max_attempts integer,
  created_at timestamptz,
  assigned_at timestamptz,
  expires_at timestamptz,
  archived_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  RETURN QUERY
  SELECT
    aq.id,
    aq.public_code,
    aq.student_id,
    aq.student_user_id,
    aq.license_category,
    aq.title,
    aq.status,
    aq.question_count,
    aq.repeat_policy,
    aq.max_attempts,
    aq.created_at,
    aq.assigned_at,
    aq.expires_at,
    aq.archived_at
  FROM public.assigned_quizzes aq
  WHERE aq.student_user_id = v_uid
    AND aq.status IN ('assigned', 'archived')
  ORDER BY aq.assigned_at DESC;
END;
$$;

COMMENT ON FUNCTION public.list_my_assigned_quizzes() IS
  'Studente: elenca i propri quiz senza campi interni staff.';

-- RLS is row-level, not column-level: remove direct student table reads so
-- staff_note cannot be requested through PostgREST. The staff SELECT policy
-- remains in force for authenticated school staff.
DROP POLICY IF EXISTS assigned_quizzes_student_select
  ON public.assigned_quizzes;

REVOKE ALL ON FUNCTION public.list_my_assigned_quizzes() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_my_assigned_quizzes() TO authenticated;
