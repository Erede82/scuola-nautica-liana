-- Allow students to finish attempts that were already started before an
-- assignment expired or was archived. Availability gates apply only when a
-- new attempt would be created.
CREATE OR REPLACE FUNCTION public.start_assigned_quiz_attempt(p_assignment_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid;
  v_assignment public.assigned_quizzes%ROWTYPE;
  v_current_category text;
  v_attempt public.assigned_quiz_attempts%ROWTYPE;
  v_attempts_used integer;
  v_next_attempt_number integer;
  v_question_count integer;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  IF p_assignment_id IS NULL THEN
    RAISE EXCEPTION 'assignment_id_required';
  END IF;

  SELECT *
  INTO v_assignment
  FROM public.assigned_quizzes aq
  WHERE aq.id = p_assignment_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'assignment_not_found';
  END IF;

  IF v_assignment.student_user_id IS DISTINCT FROM v_uid THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  -- Resuming is not a new attempt. Keep saved work reachable even if staff
  -- archives the assignment or its deadline passes while the player is closed.
  SELECT a.*
  INTO v_attempt
  FROM public.assigned_quiz_attempts a
  WHERE a.assignment_id = p_assignment_id
    AND a.user_id = v_uid
    AND a.status = 'in_progress'
  LIMIT 1;

  IF FOUND THEN
    SELECT count(*)::integer
    INTO v_question_count
    FROM public.assigned_quiz_items i
    WHERE i.assignment_id = p_assignment_id;

    SELECT count(*)::integer
    INTO v_attempts_used
    FROM public.assigned_quiz_attempts a
    WHERE a.assignment_id = p_assignment_id
      AND a.user_id = v_uid
      AND a.status IN ('in_progress', 'submitted', 'abandoned');

    RETURN jsonb_build_object(
      'attempt_id', v_attempt.id,
      'attempt_number', v_attempt.attempt_number,
      'resumed', true,
      'question_count', v_question_count,
      'max_attempts', v_assignment.max_attempts,
      'attempts_used', v_attempts_used
    );
  END IF;

  IF v_assignment.status <> 'assigned' THEN
    RAISE EXCEPTION 'assignment_not_available';
  END IF;

  IF v_assignment.expires_at IS NOT NULL AND v_assignment.expires_at <= now() THEN
    RAISE EXCEPTION 'assignment_expired';
  END IF;

  v_current_category := public.resolve_student_quiz_license_category(v_assignment.student_id);
  IF v_current_category IS DISTINCT FROM v_assignment.license_category THEN
    RAISE EXCEPTION 'assignment_category_mismatch';
  END IF;

  SELECT count(*)::integer
  INTO v_attempts_used
  FROM public.assigned_quiz_attempts a
  WHERE a.assignment_id = p_assignment_id
    AND a.user_id = v_uid
    AND a.status IN ('in_progress', 'submitted', 'abandoned');

  IF v_assignment.repeat_policy = 'limited'
     AND v_attempts_used >= v_assignment.max_attempts THEN
    RAISE EXCEPTION 'attempt_limit_reached';
  END IF;

  SELECT COALESCE(max(a.attempt_number), 0) + 1
  INTO v_next_attempt_number
  FROM public.assigned_quiz_attempts a
  WHERE a.assignment_id = p_assignment_id;

  BEGIN
    INSERT INTO public.assigned_quiz_attempts (
      assignment_id,
      student_id,
      user_id,
      attempt_number,
      status,
      started_at
    )
    VALUES (
      p_assignment_id,
      v_assignment.student_id,
      v_uid,
      v_next_attempt_number,
      'in_progress',
      now()
    )
    RETURNING * INTO v_attempt;

    INSERT INTO public.assigned_quiz_attempt_answers (
      attempt_id,
      assignment_item_id,
      position,
      selected_option,
      correct_option,
      is_correct,
      answered_at
    )
    SELECT
      v_attempt.id,
      i.id,
      i.position,
      NULL,
      i.correct_option,
      NULL,
      NULL
    FROM public.assigned_quiz_items i
    WHERE i.assignment_id = p_assignment_id
    ORDER BY i.position;

    GET DIAGNOSTICS v_question_count = ROW_COUNT;

    IF v_question_count <> v_assignment.question_count THEN
      RAISE EXCEPTION 'assigned_quiz_attempt_answers_incomplete';
    END IF;
  EXCEPTION
    WHEN unique_violation THEN
      SELECT a.*
      INTO v_attempt
      FROM public.assigned_quiz_attempts a
      WHERE a.assignment_id = p_assignment_id
        AND a.user_id = v_uid
        AND a.status = 'in_progress'
      LIMIT 1;

      IF NOT FOUND THEN
        RAISE EXCEPTION 'attempt_start_conflict';
      END IF;

      SELECT count(*)::integer
      INTO v_question_count
      FROM public.assigned_quiz_items i
      WHERE i.assignment_id = p_assignment_id;

      SELECT count(*)::integer
      INTO v_attempts_used
      FROM public.assigned_quiz_attempts a
      WHERE a.assignment_id = p_assignment_id
        AND a.user_id = v_uid
        AND a.status IN ('in_progress', 'submitted', 'abandoned');

      RETURN jsonb_build_object(
        'attempt_id', v_attempt.id,
        'attempt_number', v_attempt.attempt_number,
        'resumed', true,
        'question_count', v_question_count,
        'max_attempts', v_assignment.max_attempts,
        'attempts_used', v_attempts_used
      );
  END;

  v_attempts_used := v_attempts_used + 1;

  RETURN jsonb_build_object(
    'attempt_id', v_attempt.id,
    'attempt_number', v_attempt.attempt_number,
    'resumed', false,
    'question_count', v_question_count,
    'max_attempts', v_assignment.max_attempts,
    'attempts_used', v_attempts_used
  );
END;
$$;

COMMENT ON FUNCTION public.start_assigned_quiz_attempt(uuid) IS
  'Studente: riprende sempre il proprio tentativo in_progress; disponibilità, scadenza e limiti bloccano solo nuovi tentativi.';

REVOKE ALL ON FUNCTION public.start_assigned_quiz_attempt(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.start_assigned_quiz_attempt(uuid) TO authenticated;
