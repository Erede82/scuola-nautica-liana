-- =============================================================================
-- STUDIO.MULTISCHEDA.1 — Persistenza dedicata Multischede argomento
-- =============================================================================
-- Modulo separato da:
--   quiz_results / quiz_attempt_answers / quiz_sets
--   exam_quiz_attempts / exam_quiz_attempt_answers
--   assigned_quiz_*
--
-- Tentativo Multischeda: nasce solo al submit di una scheda conclusa.
-- Nessuna riga session; session_id è solo raggruppamento client-side.
-- Nessuno stato in_progress / ghost future sheets.
--
-- Idempotenza duale:
--   UNIQUE(user_id, client_submission_id)     → retry tecnico
--   UNIQUE(user_id, session_id, sheet_index)  → retry semantico
-- Entrambi confrontano payload_fingerprint prima di riusare o rifiutare.
--
-- Dimensione scheda (allineata a LessonQuizRules Flutter / exam RPC):
--   A12 → 20, D1 → 15  (enforce in RPC; NON in CHECK tabella).
--   Qualunque cambio futuro a LessonQuizRules richiede aggiornamento
--   coordinato di questa RPC.
--
-- NON tocca: Contabilità, Stripe, payments, record_payment,
-- student_financial_summaries, Guide, Esami, Documenti, Auth, PWA.
-- NON modifica Exam Simulation né Assigned Quiz né lesson sheets.
--
-- Applicare solo dopo approvazione esplicita (supabase db push).
-- =============================================================================

CREATE OR REPLACE FUNCTION public.multi_topic_lesson_numbers_valid(p_lessons integer[])
RETURNS boolean
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT
    p_lessons IS NOT NULL
    AND cardinality(p_lessons) >= 2
    AND NOT EXISTS (
      SELECT 1
      FROM unnest(p_lessons) AS u(n)
      WHERE u.n IS NULL OR u.n < 1
    )
    AND (
      SELECT count(*) = count(DISTINCT n)
      FROM unnest(p_lessons) AS u(n)
    );
$$;

COMMENT ON FUNCTION public.multi_topic_lesson_numbers_valid(integer[]) IS
  'True se lesson_numbers ha >=2 interi positivi senza duplicati.';

REVOKE ALL ON FUNCTION public.multi_topic_lesson_numbers_valid(integer[]) FROM PUBLIC;

-- ---------------------------------------------------------------------------
-- Tabelle
-- ---------------------------------------------------------------------------
CREATE TABLE public.multi_topic_quiz_attempts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE RESTRICT,
  client_submission_id uuid NOT NULL,
  session_id uuid NOT NULL,
  license_category text NOT NULL
    CHECK (license_category IN ('A12', 'D1')),
  lesson_numbers integer[] NOT NULL,
  sheet_index integer NOT NULL
    CHECK (sheet_index >= 1),
  total_sheets integer NOT NULL
    CHECK (total_sheets >= 1),
  total_questions integer NOT NULL
    CHECK (total_questions >= 1),
  correct_count integer NOT NULL
    CHECK (correct_count >= 0),
  wrong_count integer NOT NULL
    CHECK (wrong_count >= 0),
  unanswered_count integer NOT NULL
    CHECK (unanswered_count >= 0),
  started_at timestamptz NOT NULL,
  completed_at timestamptz NOT NULL DEFAULT now(),
  duration_seconds integer NOT NULL
    CHECK (duration_seconds >= 0),
  payload_fingerprint text NOT NULL
    CHECK (btrim(payload_fingerprint) <> ''),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT multi_topic_quiz_attempts_sheet_range_chk
    CHECK (total_sheets >= sheet_index),
  CONSTRAINT multi_topic_quiz_attempts_counts_chk
    CHECK (correct_count + wrong_count + unanswered_count = total_questions),
  CONSTRAINT multi_topic_quiz_attempts_lesson_numbers_chk
    CHECK (public.multi_topic_lesson_numbers_valid(lesson_numbers)),
  CONSTRAINT multi_topic_quiz_attempts_user_submission_uq
    UNIQUE (user_id, client_submission_id),
  CONSTRAINT multi_topic_quiz_attempts_user_session_sheet_uq
    UNIQUE (user_id, session_id, sheet_index)
);

COMMENT ON TABLE public.multi_topic_quiz_attempts IS
  'Schede Multischeda già concluse. Nessun in_progress: la riga nasce solo al submit RPC.';

COMMENT ON COLUMN public.multi_topic_quiz_attempts.client_submission_id IS
  'UUID idempotente per scheda (player). Stesso payload → stesso attempt; payload diverso → idempotency_conflict.';

COMMENT ON COLUMN public.multi_topic_quiz_attempts.session_id IS
  'UUID client della sessione Multischeda; raggruppa schede 1..N senza tabella session.';

COMMENT ON COLUMN public.multi_topic_quiz_attempts.lesson_numbers IS
  'Argomenti selezionati (lesson_number), ordinati ASC lato RPC.';

COMMENT ON COLUMN public.multi_topic_quiz_attempts.completed_at IS
  'Timestamp server-side di registrazione; non accettato dal client.';

COMMENT ON COLUMN public.multi_topic_quiz_attempts.total_questions IS
  'Conteggio effettivo. Regole prodotto A12=20/D1=15 enforce in RPC; allineate a LessonQuizRules Flutter.';

CREATE TABLE public.multi_topic_quiz_attempt_answers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  attempt_id uuid NOT NULL
    REFERENCES public.multi_topic_quiz_attempts (id) ON DELETE CASCADE,
  position integer NOT NULL
    CHECK (position >= 1),
  question_id uuid NOT NULL
    REFERENCES public.questions (id) ON DELETE RESTRICT,
  prompt_snapshot text NOT NULL,
  option_a_snapshot text NOT NULL,
  option_b_snapshot text NOT NULL,
  option_c_snapshot text NOT NULL,
  image_path_snapshot text,
  explanation_snapshot text,
  lesson_number_snapshot integer NOT NULL
    CHECK (lesson_number_snapshot >= 1),
  selected_option text
    CHECK (
      selected_option IS NULL
      OR selected_option IN ('A', 'B', 'C')
    ),
  correct_option text NOT NULL
    CHECK (correct_option IN ('A', 'B', 'C')),
  is_correct boolean NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT multi_topic_quiz_attempt_answers_is_correct_chk CHECK (
    is_correct = (
      selected_option IS NOT NULL
      AND selected_option = correct_option
    )
  ),
  CONSTRAINT multi_topic_quiz_attempt_answers_attempt_position_uq
    UNIQUE (attempt_id, position),
  CONSTRAINT multi_topic_quiz_attempt_answers_attempt_question_uq
    UNIQUE (attempt_id, question_id)
);

COMMENT ON TABLE public.multi_topic_quiz_attempt_answers IS
  'Snapshot risposte Multischeda (prompt/opzioni/immagine/explanation). Review indipendente da mutazioni future di questions.';

COMMENT ON COLUMN public.multi_topic_quiz_attempt_answers.explanation_snapshot IS
  'Copia di questions.explanation al submit; NULL se assente. Per review storica.';

COMMENT ON COLUMN public.multi_topic_quiz_attempt_answers.correct_option IS
  'Congelata server-side al submit; mai accettata dal client.';

COMMENT ON COLUMN public.multi_topic_quiz_attempt_answers.selected_option IS
  'NULL = non risposta.';

-- Solo history: i UNIQUE coprono già lookup per submission e session+sheet / position.
CREATE INDEX idx_multi_topic_quiz_attempts_user_completed
  ON public.multi_topic_quiz_attempts (user_id, completed_at DESC);

-- ---------------------------------------------------------------------------
-- RPC
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.submit_multi_topic_quiz_attempt(
  p_client_submission_id uuid,
  p_session_id uuid,
  p_license_category text,
  p_lesson_numbers integer[],
  p_sheet_index integer,
  p_total_sheets integer,
  p_started_at timestamptz,
  p_duration_seconds integer,
  p_answers jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid;
  v_category text;
  v_lessons integer[];
  v_student_id uuid;
  v_access_category text;
  v_existing public.multi_topic_quiz_attempts%ROWTYPE;
  v_attempt_id uuid;
  v_fingerprint text;
  v_completed_at timestamptz;
  v_correct integer := 0;
  v_wrong integer := 0;
  v_unanswered integer := 0;
  v_expected_questions integer;
  v_answer_count integer;
  v_distinct_positions integer;
  v_distinct_questions integer;
  v_invalid_option_count integer;
  v_invalid_position_count integer;
  v_missing_question_count integer;
  v_category_mismatch_count integer;
  v_lesson_mismatch_count integer;
  v_locked_lesson_count integer;
  v_constraint_name text;
  v_elem jsonb;
  v_pos_text text;
  v_qid_text text;
  v_sel_raw jsonb;
  v_position integer;
  v_question_id uuid;
  v_selected_option text;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  IF p_client_submission_id IS NULL THEN
    RAISE EXCEPTION 'client_submission_id_required';
  END IF;

  IF p_session_id IS NULL THEN
    RAISE EXCEPTION 'session_id_required';
  END IF;

  v_category := NULLIF(btrim(p_license_category), '');
  IF v_category IS NULL OR v_category NOT IN ('A12', 'D1') THEN
    RAISE EXCEPTION 'invalid_license_category';
  END IF;

  -- Allineato a LessonQuizRules Flutter / submit_exam_quiz_attempt.
  IF v_category = 'A12' THEN
    v_expected_questions := 20;
  ELSE
    v_expected_questions := 15;
  END IF;

  IF p_lesson_numbers IS NULL
     OR NOT public.multi_topic_lesson_numbers_valid(p_lesson_numbers) THEN
    RAISE EXCEPTION 'invalid_lesson_numbers';
  END IF;

  SELECT array_agg(n ORDER BY n)
  INTO v_lessons
  FROM unnest(p_lesson_numbers) AS u(n);

  IF p_sheet_index IS NULL OR p_sheet_index < 1 THEN
    RAISE EXCEPTION 'invalid_sheet_index';
  END IF;

  IF p_total_sheets IS NULL
     OR p_total_sheets < 1
     OR p_total_sheets < p_sheet_index THEN
    RAISE EXCEPTION 'invalid_total_sheets';
  END IF;

  IF p_started_at IS NULL THEN
    RAISE EXCEPTION 'started_at_required';
  END IF;

  IF p_duration_seconds IS NULL OR p_duration_seconds < 0 THEN
    RAISE EXCEPTION 'invalid_duration_seconds';
  END IF;

  IF p_answers IS NULL OR jsonb_typeof(p_answers) <> 'array' THEN
    RAISE EXCEPTION 'invalid_answers_payload';
  END IF;

  IF jsonb_array_length(p_answers) <> v_expected_questions THEN
    RAISE EXCEPTION 'invalid_answer_count';
  END IF;

  DROP TABLE IF EXISTS pg_temp.tmp_multi_topic_submit_answers;

  CREATE TEMP TABLE tmp_multi_topic_submit_answers (
    position integer NOT NULL,
    question_id uuid NOT NULL,
    selected_option text
  ) ON COMMIT DROP;

  FOR v_elem IN
    SELECT value
    FROM jsonb_array_elements(p_answers) AS t(value)
  LOOP
    IF jsonb_typeof(v_elem) <> 'object' THEN
      RAISE EXCEPTION 'invalid_answers_payload';
    END IF;

    IF NOT (v_elem ? 'position')
       OR (v_elem -> 'position') IS NULL
       OR jsonb_typeof(v_elem -> 'position') = 'null' THEN
      RAISE EXCEPTION 'invalid_answer_positions';
    END IF;

    v_pos_text := v_elem ->> 'position';
    IF v_pos_text IS NULL OR v_pos_text !~ '^[0-9]+$' THEN
      RAISE EXCEPTION 'invalid_answer_positions';
    END IF;

    v_position := v_pos_text::integer;
    IF v_position < 1 OR v_position > v_expected_questions THEN
      RAISE EXCEPTION 'invalid_answer_positions';
    END IF;

    IF NOT (v_elem ? 'question_id')
       OR (v_elem -> 'question_id') IS NULL
       OR jsonb_typeof(v_elem -> 'question_id') = 'null' THEN
      RAISE EXCEPTION 'invalid_question_id';
    END IF;

    IF jsonb_typeof(v_elem -> 'question_id') <> 'string' THEN
      RAISE EXCEPTION 'invalid_question_id';
    END IF;

    v_qid_text := NULLIF(btrim(v_elem ->> 'question_id'), '');
    IF v_qid_text IS NULL
       OR v_qid_text !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
      RAISE EXCEPTION 'invalid_question_id';
    END IF;

    v_question_id := v_qid_text::uuid;

    IF v_elem ? 'selected_option' THEN
      v_sel_raw := v_elem -> 'selected_option';
      IF v_sel_raw IS NULL OR jsonb_typeof(v_sel_raw) = 'null' THEN
        v_selected_option := NULL;
      ELSIF jsonb_typeof(v_sel_raw) <> 'string' THEN
        RAISE EXCEPTION 'invalid_answers_shape';
      ELSE
        v_selected_option := NULLIF(upper(btrim(v_elem ->> 'selected_option')), '');
        IF v_selected_option IS NOT NULL
           AND v_selected_option NOT IN ('A', 'B', 'C') THEN
          RAISE EXCEPTION 'invalid_answers_shape';
        END IF;
      END IF;
    ELSE
      v_selected_option := NULL;
    END IF;

    INSERT INTO tmp_multi_topic_submit_answers (
      position, question_id, selected_option
    )
    VALUES (v_position, v_question_id, v_selected_option);
  END LOOP;

  SELECT count(*)::integer,
         count(DISTINCT position)::integer,
         count(DISTINCT question_id)::integer,
         count(*) FILTER (
           WHERE position < 1 OR position > v_expected_questions
         )::integer,
         count(*) FILTER (
           WHERE selected_option IS NOT NULL
             AND selected_option NOT IN ('A', 'B', 'C')
         )::integer
  INTO v_answer_count,
       v_distinct_positions,
       v_distinct_questions,
       v_invalid_position_count,
       v_invalid_option_count
  FROM tmp_multi_topic_submit_answers;

  IF v_answer_count <> v_expected_questions
     OR v_distinct_positions <> v_expected_questions
     OR v_distinct_questions <> v_expected_questions
     OR v_invalid_position_count > 0
     OR v_invalid_option_count > 0 THEN
    RAISE EXCEPTION 'invalid_answers_shape';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM generate_series(1, v_expected_questions) AS expected(position)
    LEFT JOIN tmp_multi_topic_submit_answers t
      ON t.position = expected.position
    WHERE t.position IS NULL
  ) THEN
    RAISE EXCEPTION 'invalid_answer_positions';
  END IF;

  SELECT encode(
    extensions.digest(
      jsonb_build_object(
        'license_category', v_category,
        'session_id', p_session_id,
        'sheet_index', p_sheet_index,
        'total_sheets', p_total_sheets,
        'lesson_numbers', to_jsonb(v_lessons),
        'started_at', p_started_at,
        'duration_seconds', p_duration_seconds,
        'answers', coalesce(
          (
            SELECT jsonb_agg(
              jsonb_build_object(
                'position', t.position,
                'question_id', t.question_id,
                'selected_option', t.selected_option
              )
              ORDER BY t.position
            )
            FROM tmp_multi_topic_submit_answers t
          ),
          '[]'::jsonb
        )
      )::text,
      'sha256'::text
    ),
    'hex'
  )
  INTO v_fingerprint;

  -- Lock tecnico (token) + semantico (session+sheet).
  PERFORM pg_advisory_xact_lock(
    hashtextextended(
      'multi_topic_quiz_submit:' || v_uid::text || ':' || p_client_submission_id::text,
      0
    )
  );
  PERFORM pg_advisory_xact_lock(
    hashtextextended(
      'multi_topic_quiz_submit_sheet:' || v_uid::text || ':' ||
      p_session_id::text || ':' || p_sheet_index::text,
      0
    )
  );

  -- 1) Retry tecnico sullo stesso client_submission_id.
  SELECT *
  INTO v_existing
  FROM public.multi_topic_quiz_attempts a
  WHERE a.user_id = v_uid
    AND a.client_submission_id = p_client_submission_id;

  IF FOUND THEN
    IF v_existing.payload_fingerprint IS DISTINCT FROM v_fingerprint THEN
      RAISE EXCEPTION 'idempotency_conflict';
    END IF;

    RETURN jsonb_build_object(
      'attempt_id', v_existing.id,
      'session_id', v_existing.session_id,
      'sheet_index', v_existing.sheet_index,
      'total_sheets', v_existing.total_sheets,
      'license_category', v_existing.license_category,
      'lesson_numbers', to_jsonb(v_existing.lesson_numbers),
      'completed_at', v_existing.completed_at,
      'duration_seconds', v_existing.duration_seconds,
      'total_questions', v_existing.total_questions,
      'correct_count', v_existing.correct_count,
      'wrong_count', v_existing.wrong_count,
      'unanswered_count', v_existing.unanswered_count,
      'idempotent', true
    );
  END IF;

  -- 2) Retry semantico: stesso session+sheet, eventuale token diverso.
  SELECT *
  INTO v_existing
  FROM public.multi_topic_quiz_attempts a
  WHERE a.user_id = v_uid
    AND a.session_id = p_session_id
    AND a.sheet_index = p_sheet_index;

  IF FOUND THEN
    IF v_existing.payload_fingerprint IS DISTINCT FROM v_fingerprint THEN
      RAISE EXCEPTION 'session_sheet_conflict';
    END IF;

    RETURN jsonb_build_object(
      'attempt_id', v_existing.id,
      'session_id', v_existing.session_id,
      'sheet_index', v_existing.sheet_index,
      'total_sheets', v_existing.total_sheets,
      'license_category', v_existing.license_category,
      'lesson_numbers', to_jsonb(v_existing.lesson_numbers),
      'completed_at', v_existing.completed_at,
      'duration_seconds', v_existing.duration_seconds,
      'total_questions', v_existing.total_questions,
      'correct_count', v_existing.correct_count,
      'wrong_count', v_existing.wrong_count,
      'unanswered_count', v_existing.unanswered_count,
      'idempotent', true
    );
  END IF;

  SELECT s.id
  INTO v_student_id
  FROM public.students s
  WHERE s.user_id = v_uid;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'student_not_found';
  END IF;

  v_access_category := CASE v_category
    WHEN 'A12' THEN 'motore'
    WHEN 'D1' THEN 'd1'
  END;

  SELECT count(*)::integer
  INTO v_locked_lesson_count
  FROM unnest(v_lessons) AS u(lesson_number)
  WHERE NOT EXISTS (
    SELECT 1
    FROM public.lesson_quiz_sheet_unlocks urow
    WHERE urow.student_id = v_student_id
      AND urow.license_category = v_access_category
      AND urow.lesson_number = u.lesson_number
      AND urow.unlocked = true
  );

  IF v_locked_lesson_count > 0 THEN
    RAISE EXCEPTION 'multi_topic_access_denied';
  END IF;

  SELECT count(*) FILTER (WHERE q.id IS NULL)::integer,
         count(*) FILTER (
           WHERE q.license_category IS DISTINCT FROM v_category
         )::integer,
         count(*) FILTER (
           WHERE q.lesson_number IS NULL
             OR NOT (q.lesson_number = ANY (v_lessons))
         )::integer
  INTO v_missing_question_count,
       v_category_mismatch_count,
       v_lesson_mismatch_count
  FROM tmp_multi_topic_submit_answers t
  LEFT JOIN public.questions q ON q.id = t.question_id;

  IF v_missing_question_count > 0 THEN
    RAISE EXCEPTION 'question_not_found';
  END IF;

  IF v_category_mismatch_count > 0 THEN
    RAISE EXCEPTION 'question_category_mismatch';
  END IF;

  IF v_lesson_mismatch_count > 0 THEN
    RAISE EXCEPTION 'question_lesson_mismatch';
  END IF;

  v_completed_at := now();

  SELECT
    count(*) FILTER (
      WHERE t.selected_option IS NOT NULL
        AND t.selected_option = q.correct_option::text
    )::integer,
    count(*) FILTER (
      WHERE t.selected_option IS NOT NULL
        AND t.selected_option IS DISTINCT FROM q.correct_option::text
    )::integer,
    count(*) FILTER (WHERE t.selected_option IS NULL)::integer
  INTO v_correct, v_wrong, v_unanswered
  FROM tmp_multi_topic_submit_answers t
  INNER JOIN public.questions q ON q.id = t.question_id;

  BEGIN
    INSERT INTO public.multi_topic_quiz_attempts (
      user_id,
      client_submission_id,
      session_id,
      license_category,
      lesson_numbers,
      sheet_index,
      total_sheets,
      total_questions,
      correct_count,
      wrong_count,
      unanswered_count,
      started_at,
      completed_at,
      duration_seconds,
      payload_fingerprint
    )
    VALUES (
      v_uid,
      p_client_submission_id,
      p_session_id,
      v_category,
      v_lessons,
      p_sheet_index,
      p_total_sheets,
      v_expected_questions,
      v_correct,
      v_wrong,
      v_unanswered,
      p_started_at,
      v_completed_at,
      p_duration_seconds,
      v_fingerprint
    )
    RETURNING id INTO v_attempt_id;

    INSERT INTO public.multi_topic_quiz_attempt_answers (
      attempt_id,
      position,
      question_id,
      prompt_snapshot,
      option_a_snapshot,
      option_b_snapshot,
      option_c_snapshot,
      image_path_snapshot,
      explanation_snapshot,
      lesson_number_snapshot,
      selected_option,
      correct_option,
      is_correct
    )
    SELECT
      v_attempt_id,
      t.position,
      t.question_id,
      q.prompt,
      q.option_a,
      q.option_b,
      q.option_c,
      q.image_path,
      q.explanation,
      q.lesson_number,
      t.selected_option,
      q.correct_option::text,
      (
        t.selected_option IS NOT NULL
        AND t.selected_option = q.correct_option::text
      )
    FROM tmp_multi_topic_submit_answers t
    INNER JOIN public.questions q ON q.id = t.question_id
    ORDER BY t.position;
  EXCEPTION
    WHEN unique_violation THEN
      GET STACKED DIAGNOSTICS
        v_constraint_name = CONSTRAINT_NAME;

      IF v_constraint_name = 'multi_topic_quiz_attempts_user_submission_uq' THEN
        SELECT *
        INTO v_existing
        FROM public.multi_topic_quiz_attempts a
        WHERE a.user_id = v_uid
          AND a.client_submission_id = p_client_submission_id;

        IF NOT FOUND THEN
          RAISE EXCEPTION 'multi_topic_submit_conflict';
        END IF;

        IF v_existing.payload_fingerprint IS DISTINCT FROM v_fingerprint THEN
          RAISE EXCEPTION 'idempotency_conflict';
        END IF;

        RETURN jsonb_build_object(
          'attempt_id', v_existing.id,
          'session_id', v_existing.session_id,
          'sheet_index', v_existing.sheet_index,
          'total_sheets', v_existing.total_sheets,
          'license_category', v_existing.license_category,
          'lesson_numbers', to_jsonb(v_existing.lesson_numbers),
          'completed_at', v_existing.completed_at,
          'duration_seconds', v_existing.duration_seconds,
          'total_questions', v_existing.total_questions,
          'correct_count', v_existing.correct_count,
          'wrong_count', v_existing.wrong_count,
          'unanswered_count', v_existing.unanswered_count,
          'idempotent', true
        );
      END IF;

      IF v_constraint_name = 'multi_topic_quiz_attempts_user_session_sheet_uq' THEN
        SELECT *
        INTO v_existing
        FROM public.multi_topic_quiz_attempts a
        WHERE a.user_id = v_uid
          AND a.session_id = p_session_id
          AND a.sheet_index = p_sheet_index;

        IF NOT FOUND THEN
          RAISE EXCEPTION 'multi_topic_submit_conflict';
        END IF;

        IF v_existing.payload_fingerprint IS DISTINCT FROM v_fingerprint THEN
          RAISE EXCEPTION 'session_sheet_conflict';
        END IF;

        RETURN jsonb_build_object(
          'attempt_id', v_existing.id,
          'session_id', v_existing.session_id,
          'sheet_index', v_existing.sheet_index,
          'total_sheets', v_existing.total_sheets,
          'license_category', v_existing.license_category,
          'lesson_numbers', to_jsonb(v_existing.lesson_numbers),
          'completed_at', v_existing.completed_at,
          'duration_seconds', v_existing.duration_seconds,
          'total_questions', v_existing.total_questions,
          'correct_count', v_existing.correct_count,
          'wrong_count', v_existing.wrong_count,
          'unanswered_count', v_existing.unanswered_count,
          'idempotent', true
        );
      END IF;

      RAISE;
  END;

  RETURN jsonb_build_object(
    'attempt_id', v_attempt_id,
    'session_id', p_session_id,
    'sheet_index', p_sheet_index,
    'total_sheets', p_total_sheets,
    'license_category', v_category,
    'lesson_numbers', to_jsonb(v_lessons),
    'completed_at', v_completed_at,
    'duration_seconds', p_duration_seconds,
    'total_questions', v_expected_questions,
    'correct_count', v_correct,
    'wrong_count', v_wrong,
    'unanswered_count', v_unanswered,
    'idempotent', false
  );
END;
$$;

COMMENT ON FUNCTION public.submit_multi_topic_quiz_attempt(
  uuid, uuid, text, integer[], integer, integer, timestamptz, integer, jsonb
) IS
  'Studente: submit atomico scheda Multischeda. Idempotenza su client_submission_id e su (session_id, sheet_index) via payload_fingerprint.';

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
ALTER TABLE public.multi_topic_quiz_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.multi_topic_quiz_attempt_answers ENABLE ROW LEVEL SECURITY;

CREATE POLICY multi_topic_quiz_attempts_student_select
  ON public.multi_topic_quiz_attempts
  FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY multi_topic_quiz_attempts_staff_select
  ON public.multi_topic_quiz_attempts
  FOR SELECT
  USING (public.is_school_staff());

CREATE POLICY multi_topic_quiz_attempt_answers_student_select
  ON public.multi_topic_quiz_attempt_answers
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM public.multi_topic_quiz_attempts a
      WHERE a.id = attempt_id
        AND a.user_id = auth.uid()
    )
  );

CREATE POLICY multi_topic_quiz_attempt_answers_staff_select
  ON public.multi_topic_quiz_attempt_answers
  FOR SELECT
  USING (public.is_school_staff());

REVOKE ALL ON TABLE public.multi_topic_quiz_attempts FROM PUBLIC;
REVOKE ALL ON TABLE public.multi_topic_quiz_attempt_answers FROM PUBLIC;

GRANT SELECT ON TABLE public.multi_topic_quiz_attempts TO authenticated;
GRANT SELECT ON TABLE public.multi_topic_quiz_attempt_answers TO authenticated;

REVOKE INSERT, UPDATE, DELETE
  ON TABLE public.multi_topic_quiz_attempts FROM authenticated;
REVOKE INSERT, UPDATE, DELETE
  ON TABLE public.multi_topic_quiz_attempt_answers FROM authenticated;

REVOKE ALL ON FUNCTION public.submit_multi_topic_quiz_attempt(
  uuid, uuid, text, integer[], integer, integer, timestamptz, integer, jsonb
) FROM PUBLIC;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    REVOKE ALL ON TABLE public.multi_topic_quiz_attempts FROM anon;
    REVOKE ALL ON TABLE public.multi_topic_quiz_attempt_answers FROM anon;
    REVOKE ALL ON FUNCTION public.submit_multi_topic_quiz_attempt(
      uuid, uuid, text, integer[], integer, integer, timestamptz, integer, jsonb
    ) FROM anon;
    REVOKE ALL ON FUNCTION public.multi_topic_lesson_numbers_valid(integer[])
      FROM anon;
  END IF;

  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    GRANT EXECUTE ON FUNCTION public.submit_multi_topic_quiz_attempt(
      uuid, uuid, text, integer[], integer, integer, timestamptz, integer, jsonb
    ) TO authenticated;
  END IF;
END
$$;
