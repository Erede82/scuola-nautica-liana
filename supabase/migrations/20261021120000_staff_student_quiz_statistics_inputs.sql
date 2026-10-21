-- STAFF.STUDENT.STATS.1 — PATH B
-- Read-only SECURITY DEFINER RPC: staff statistics inputs for one student + category.
--
-- Does NOT:
--   - alter RLS policies
--   - alter tables
--   - mutate data
--   - implement Laplace / accuracy / ranking formulas (remain in Dart aggregator)
--
-- Authorization mirrors students_admin_all:
--   school_user_roles.role IN ('school_admin', 'admin')
-- Plain role 'staff' is intentionally denied (cannot open student admin records).

CREATE OR REPLACE FUNCTION public.get_staff_student_quiz_statistics_inputs(
  p_student_id uuid,
  p_license_category text
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_category text;
  v_quiz_user_id uuid;
  v_empty jsonb;
BEGIN
  -- 1–2. Caller must be authenticated before any argument/target behavior.
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  -- 3. Same effective permission as students_admin_all (not plain is_school_staff).
  IF NOT EXISTS (
    SELECT 1
    FROM public.school_user_roles sur
    WHERE sur.user_id = v_uid
      AND sur.role = ANY (ARRAY['school_admin'::text, 'admin'::text])
  ) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  -- 4. Argument validation only after authorization.
  IF p_student_id IS NULL THEN
    RAISE EXCEPTION 'invalid_arguments';
  END IF;

  v_category := NULLIF(upper(btrim(COALESCE(p_license_category, ''))), '');
  IF v_category IS NULL OR v_category NOT IN ('A12', 'D1') THEN
    RAISE EXCEPTION 'invalid_category';
  END IF;

  -- Target student must exist; do not leak cross-student data.
  IF NOT EXISTS (
    SELECT 1
    FROM public.students s
    WHERE s.id = p_student_id
  ) THEN
    RAISE EXCEPTION 'student_not_found';
  END IF;

  SELECT COALESCE(s.user_id, s.auth_user_id)
  INTO v_quiz_user_id
  FROM public.students s
  WHERE s.id = p_student_id;

  v_empty := jsonb_build_object(
    'linked_user', false,
    'category', v_category,
    'lesson_attempts', '[]'::jsonb,
    'multi_attempts', '[]'::jsonb,
    'multi_answer_events', '[]'::jsonb,
    'exam_attempts', '[]'::jsonb,
    'exam_answer_events', '[]'::jsonb,
    'lesson_catalog', '[]'::jsonb
  );

  -- Unlinked student: valid empty inputs (no fabricated attempts).
  IF v_quiz_user_id IS NULL THEN
    RETURN v_empty;
  END IF;

  RETURN jsonb_build_object(
    'linked_user', true,
    'category', v_category,

    -- Normal lesson sheets: header + answer_count for completeness checks.
    -- Topic rollups use header counts in Dart (no raw answer snapshots).
    'lesson_attempts', COALESCE((
      SELECT jsonb_agg(row_to_json(x)::jsonb ORDER BY x.completed_at DESC NULLS LAST, x.id)
      FROM (
        SELECT
          qr.id,
          qr.quiz_set_id,
          qs.lesson_number,
          qs.sheet_number,
          qs.kind,
          qs.license_category,
          qr.total_questions,
          qr.correct_count,
          qr.wrong_count,
          qr.unanswered_count,
          qr.started_at,
          qr.completed_at,
          qr.created_at,
          qr.duration_seconds,
          (
            SELECT count(*)::integer
            FROM public.quiz_attempt_answers qaa
            WHERE qaa.quiz_result_id = qr.id
              AND qaa.user_id = v_quiz_user_id
          ) AS answer_count
        FROM public.quiz_results qr
        INNER JOIN public.quiz_sets qs
          ON qs.id = qr.quiz_set_id
        WHERE qr.user_id = v_quiz_user_id
          AND qs.kind = 'lesson'
          AND qs.license_category = v_category
      ) x
    ), '[]'::jsonb),

    -- Multischeda attempts (dedupe stays in Flutter on session_id + sheet_index).
    'multi_attempts', COALESCE((
      SELECT jsonb_agg(row_to_json(x)::jsonb ORDER BY x.completed_at DESC, x.id)
      FROM (
        SELECT
          a.id,
          a.session_id,
          a.sheet_index,
          a.license_category,
          a.completed_at,
          a.total_questions,
          a.correct_count,
          a.wrong_count,
          a.unanswered_count
        FROM public.multi_topic_quiz_attempts a
        WHERE a.user_id = v_quiz_user_id
          AND a.license_category = v_category
      ) x
    ), '[]'::jsonb),

    -- Sanitized Multi answer events (no selected_option / prompt text).
    'multi_answer_events', COALESCE((
      SELECT jsonb_agg(row_to_json(x)::jsonb ORDER BY x.attempt_id, x.position)
      FROM (
        SELECT
          ans.attempt_id,
          ans.position,
          ans.lesson_number_snapshot AS lesson_number,
          ans.is_correct,
          (
            ans.selected_option IS NULL
            OR btrim(ans.selected_option) = ''
          ) AS is_unanswered
        FROM public.multi_topic_quiz_attempt_answers ans
        INNER JOIN public.multi_topic_quiz_attempts a
          ON a.id = ans.attempt_id
        WHERE a.user_id = v_quiz_user_id
          AND a.license_category = v_category
      ) x
    ), '[]'::jsonb),

    -- Exam attempt headers (passed + counts; formulas stay in Dart).
    'exam_attempts', COALESCE((
      SELECT jsonb_agg(row_to_json(x)::jsonb ORDER BY x.completed_at DESC, x.id)
      FROM (
        SELECT
          e.id,
          e.license_category,
          e.completed_at,
          e.total_questions,
          e.correct_count,
          e.wrong_count,
          e.unanswered_count,
          e.passed
        FROM public.exam_quiz_attempts e
        WHERE e.user_id = v_quiz_user_id
          AND e.license_category = v_category
      ) x
    ), '[]'::jsonb),

    -- Exam answer events with lesson_number joined server-side (no question text).
    'exam_answer_events', COALESCE((
      SELECT jsonb_agg(row_to_json(x)::jsonb ORDER BY x.attempt_id, x.position)
      FROM (
        SELECT
          ans.attempt_id,
          ans.position,
          q.lesson_number,
          ans.is_correct,
          (
            ans.selected_option IS NULL
            OR btrim(ans.selected_option) = ''
          ) AS is_unanswered
        FROM public.exam_quiz_attempt_answers ans
        INNER JOIN public.exam_quiz_attempts e
          ON e.id = ans.attempt_id
        INNER JOIN public.questions q
          ON q.id = ans.question_id
        WHERE e.user_id = v_quiz_user_id
          AND e.license_category = v_category
          AND q.license_category = v_category
      ) x
    ), '[]'::jsonb),

    -- Dynamic denominator source: same population as student
    -- fetchLessonSheetCatalog (kind + license_category only).
    -- lesson_number > 0 filtering stays in Dart `_catalogEntries`.
    'lesson_catalog', COALESCE((
      SELECT jsonb_agg(row_to_json(x)::jsonb ORDER BY x.lesson_number, x.sheet_number, x.id)
      FROM (
        SELECT
          qs.id,
          qs.kind,
          qs.license_category,
          qs.lesson_number,
          qs.sheet_number
        FROM public.quiz_sets qs
        WHERE qs.kind = 'lesson'
          AND qs.license_category = v_category
      ) x
    ), '[]'::jsonb)
  );
END;
$$;

COMMENT ON FUNCTION public.get_staff_student_quiz_statistics_inputs(uuid, text) IS
  'STAFF.STUDENT.STATS.1: read-only inputs for staff student quiz statistics. '
  'Auth: school_admin/admin only (parity with students_admin_all). '
  'Resolves students.id → COALESCE(user_id, auth_user_id); never treats students.id as quiz user_id. '
  'Returns sanitized intermediate DTOs for Dart buildStudentQuizStatistics; no ranking formulas.';

REVOKE ALL ON FUNCTION public.get_staff_student_quiz_statistics_inputs(uuid, text) FROM PUBLIC;

DO $$
BEGIN
  BEGIN
    REVOKE ALL ON FUNCTION public.get_staff_student_quiz_statistics_inputs(uuid, text) FROM anon;
  EXCEPTION
    WHEN undefined_object THEN
      NULL;
  END;

  GRANT EXECUTE ON FUNCTION public.get_staff_student_quiz_statistics_inputs(uuid, text)
    TO authenticated;
END;
$$;
