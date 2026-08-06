-- Keep staff-only assignment metadata out of student PostgREST responses.
--
-- RLS filters rows, not columns. The previous student SELECT policy therefore
-- exposed both assigned_quizzes.staff_note and the copy stored in
-- generation_params. Students now receive an explicit safe projection through
-- an RPC, while staff retain their existing direct-table policy.

DROP POLICY IF EXISTS assigned_quizzes_student_select
  ON public.assigned_quizzes;

CREATE OR REPLACE FUNCTION public.get_my_assigned_quizzes()
RETURNS SETOF jsonb
LANGUAGE plpgsql
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
  SELECT jsonb_build_object(
    'id', aq.id,
    'public_code', aq.public_code,
    'student_id', aq.student_id,
    'student_user_id', aq.student_user_id,
    'license_category', aq.license_category,
    'title', aq.title,
    'status', aq.status,
    'question_count', aq.question_count,
    'repeat_policy', aq.repeat_policy,
    'max_attempts', aq.max_attempts,
    'created_at', aq.created_at,
    'assigned_at', aq.assigned_at,
    'expires_at', aq.expires_at,
    'archived_at', aq.archived_at
  )
  FROM public.assigned_quizzes aq
  WHERE aq.student_user_id = v_uid
    AND aq.status = 'assigned'
  ORDER BY aq.assigned_at DESC;
END;
$$;

COMMENT ON FUNCTION public.get_my_assigned_quizzes() IS
  'Studente: elenca le assegnazioni proprie senza staff_note o generation_params.';

REVOKE ALL ON FUNCTION public.get_my_assigned_quizzes() FROM PUBLIC;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    REVOKE ALL ON FUNCTION public.get_my_assigned_quizzes() FROM anon;
  END IF;

  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    GRANT EXECUTE ON FUNCTION public.get_my_assigned_quizzes()
      TO authenticated;
  END IF;
END
$$;
