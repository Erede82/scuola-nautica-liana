-- =============================================================================
-- P9E.3 — Quiz Esame: schema persistente e submit atomico
-- =============================================================================
-- Modulo dedicato alle simulazioni esame concluse. Separato da:
--   quiz_results / quiz_attempt_answers / quiz_sets / assigned_quiz_*.
--
-- Il tentativo esame NON esiste in DB finché non viene inviato (manuale o timer).
-- Ogni riga nasce già completata, immutabile e consultabile in seguito.
-- Conteggi, esito e snapshot domanda sono calcolati server-side dalla RPC.
--
-- NON tocca: Contabilità, Stripe, payments, Statistiche lezione, Ripasso,
-- assigned_quizzes, quiz_sets, quiz_results, quiz_attempt_answers.
--
-- Applicare solo dopo approvazione esplicita (supabase db push).
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Costanti esame (regola superamento: max 4 errori = sbagliate + non risposte)
-- ---------------------------------------------------------------------------
-- 20 domande fisse; passed := (wrong_count + unanswered_count) <= 4

-- ---------------------------------------------------------------------------
-- Tabelle
-- ---------------------------------------------------------------------------
CREATE TABLE public.exam_quiz_attempts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE RESTRICT,
  client_attempt_token text NOT NULL
    CHECK (btrim(client_attempt_token) <> ''),
  license_category text NOT NULL
    CHECK (license_category IN ('A12', 'D1')),
  completed_at timestamptz NOT NULL DEFAULT now(),
  duration_seconds integer NOT NULL
    CHECK (duration_seconds >= 0),
  time_expired boolean NOT NULL DEFAULT false,
  total_questions integer NOT NULL
    CHECK (total_questions = 20),
  correct_count integer NOT NULL
    CHECK (correct_count >= 0),
  wrong_count integer NOT NULL
    CHECK (wrong_count >= 0),
  unanswered_count integer NOT NULL
    CHECK (unanswered_count >= 0),
  passed boolean NOT NULL,
  payload_fingerprint text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT exam_quiz_attempts_counts_chk CHECK (
    correct_count + wrong_count + unanswered_count = total_questions
  ),
  CONSTRAINT exam_quiz_attempts_passed_counts_chk CHECK (
    passed = ((wrong_count + unanswered_count) <= 4)
  ),
  CONSTRAINT exam_quiz_attempts_user_token_uq
    UNIQUE (user_id, client_attempt_token)
);

COMMENT ON TABLE public.exam_quiz_attempts IS
  'Tentativi simulazione esame già conclusi. Nessuno stato in_progress: la riga nasce solo al submit.';

COMMENT ON COLUMN public.exam_quiz_attempts.client_attempt_token IS
  'Token idempotente generato dal player. Chiave logica (user_id, token): stesso payload → stesso tentativo; payload diverso → idempotency_conflict.';

COMMENT ON COLUMN public.exam_quiz_attempts.payload_fingerprint IS
  'Impronta SHA-256 canonica del payload client (categoria, durata, time_expired, risposte ordinate).';

COMMENT ON COLUMN public.exam_quiz_attempts.passed IS
  'Esito server-side: (wrong_count + unanswered_count) <= 4 su 20 domande.';

COMMENT ON COLUMN public.exam_quiz_attempts.completed_at IS
  'Timestamp server-side di registrazione; non accettato dal client.';

CREATE TABLE public.exam_quiz_attempt_answers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  attempt_id uuid NOT NULL REFERENCES public.exam_quiz_attempts (id) ON DELETE CASCADE,
  position integer NOT NULL
    CHECK (position BETWEEN 1 AND 20),
  question_id uuid NOT NULL REFERENCES public.questions (id) ON DELETE RESTRICT,
  prompt_snapshot text NOT NULL,
  option_a_snapshot text NOT NULL,
  option_b_snapshot text NOT NULL,
  option_c_snapshot text NOT NULL,
  image_path_snapshot text,
  selected_option text
    CHECK (
      selected_option IS NULL
      OR selected_option IN ('A', 'B', 'C')
    ),
  correct_option text NOT NULL
    CHECK (correct_option IN ('A', 'B', 'C')),
  is_correct boolean NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT exam_quiz_attempt_answers_is_correct_chk CHECK (
    is_correct = (
      selected_option IS NOT NULL
      AND selected_option = correct_option
    )
  ),
  CONSTRAINT exam_quiz_attempt_answers_attempt_position_uq
    UNIQUE (attempt_id, position),
  CONSTRAINT exam_quiz_attempt_answers_attempt_question_uq
    UNIQUE (attempt_id, question_id)
);

COMMENT ON TABLE public.exam_quiz_attempt_answers IS
  'Snapshot storico delle 20 risposte esame. sufficiente per review senza rileggere questions.';

COMMENT ON COLUMN public.exam_quiz_attempt_answers.selected_option IS
  'Scelta studente; NULL = domanda non risposta (conta come errore ai fini del superamento).';

COMMENT ON COLUMN public.exam_quiz_attempt_answers.correct_option IS
  'Risposta corretta congelata al submit; calcolata server-side, mai accettata dal client.';

-- ---------------------------------------------------------------------------
-- Indici
-- ---------------------------------------------------------------------------
CREATE INDEX idx_exam_quiz_attempts_user_completed
  ON public.exam_quiz_attempts (user_id, completed_at DESC);

CREATE INDEX idx_exam_quiz_attempt_answers_attempt
  ON public.exam_quiz_attempt_answers (attempt_id, position);

-- ---------------------------------------------------------------------------
-- RPC: submit_exam_quiz_attempt
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.submit_exam_quiz_attempt(
  p_client_attempt_token text,
  p_license_category text,
  p_duration_seconds integer,
  p_time_expired boolean,
  p_answers jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid;
  v_token text;
  v_category text;
  v_student_id uuid;
  v_access_category text;
  v_existing public.exam_quiz_attempts%ROWTYPE;
  v_attempt_id uuid;
  v_fingerprint text;
  v_completed_at timestamptz;
  v_correct integer := 0;
  v_wrong integer := 0;
  v_unanswered integer := 0;
  v_passed boolean;
  v_answer_count integer;
  v_distinct_positions integer;
  v_distinct_questions integer;
  v_invalid_option_count integer;
  v_invalid_position_count integer;
  v_missing_question_count integer;
  v_invalid_exam_question_count integer;
  v_category_mismatch_count integer;
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

  v_token := NULLIF(btrim(p_client_attempt_token), '');
  IF v_token IS NULL THEN
    RAISE EXCEPTION 'client_attempt_token_required';
  END IF;

  v_category := NULLIF(btrim(p_license_category), '');
  IF v_category IS NULL OR v_category NOT IN ('A12', 'D1') THEN
    RAISE EXCEPTION 'invalid_license_category';
  END IF;

  IF p_duration_seconds IS NULL OR p_duration_seconds < 0 THEN
    RAISE EXCEPTION 'invalid_duration_seconds';
  END IF;

  IF p_time_expired IS NULL THEN
    RAISE EXCEPTION 'time_expired_required';
  END IF;

  IF p_answers IS NULL OR jsonb_typeof(p_answers) <> 'array' THEN
    RAISE EXCEPTION 'invalid_answers_payload';
  END IF;

  IF jsonb_array_length(p_answers) <> 20 THEN
    RAISE EXCEPTION 'invalid_answer_count';
  END IF;

  -- Validazione esplicita prima di ogni cast: evita 22P02 su payload malformato.
  -- DROP esplicito: ON COMMIT DROP non basta per due invocazioni nella stessa transazione.
  DROP TABLE IF EXISTS pg_temp.tmp_exam_submit_answers;

  CREATE TEMP TABLE tmp_exam_submit_answers (
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

    IF NOT (v_elem ? 'position') OR (v_elem -> 'position') IS NULL
       OR jsonb_typeof(v_elem -> 'position') = 'null' THEN
      RAISE EXCEPTION 'invalid_answer_positions';
    END IF;

    v_pos_text := v_elem ->> 'position';
    IF v_pos_text IS NULL OR v_pos_text !~ '^[0-9]+$' THEN
      RAISE EXCEPTION 'invalid_answer_positions';
    END IF;

    v_position := v_pos_text::integer;
    IF v_position < 1 OR v_position > 20 THEN
      RAISE EXCEPTION 'invalid_answer_positions';
    END IF;

    IF NOT (v_elem ? 'question_id') OR (v_elem -> 'question_id') IS NULL
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

    INSERT INTO tmp_exam_submit_answers (position, question_id, selected_option)
    VALUES (v_position, v_question_id, v_selected_option);
  END LOOP;

  SELECT count(*)::integer,
         count(DISTINCT position)::integer,
         count(DISTINCT question_id)::integer,
         count(*) FILTER (
           WHERE position < 1
             OR position > 20
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
  FROM tmp_exam_submit_answers;

  IF v_answer_count <> 20
     OR v_distinct_positions <> 20
     OR v_distinct_questions <> 20
     OR v_invalid_position_count > 0
     OR v_invalid_option_count > 0 THEN
    RAISE EXCEPTION 'invalid_answers_shape';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM generate_series(1, 20) AS expected(position)
    LEFT JOIN tmp_exam_submit_answers t ON t.position = expected.position
    WHERE t.position IS NULL
  ) THEN
    RAISE EXCEPTION 'invalid_answer_positions';
  END IF;

  -- Impronta canonica per idempotenza (categoria, durata, timer, risposte ordinate).
  SELECT encode(
    digest(
      jsonb_build_object(
        'license_category', v_category,
        'duration_seconds', p_duration_seconds,
        'time_expired', p_time_expired,
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
            FROM tmp_exam_submit_answers t
          ),
          '[]'::jsonb
        )
      )::text,
      'sha256'
    ),
    'hex'
  )
  INTO v_fingerprint;

  -- Protezione concorrenza: doppio tap / timer+submit simultanei sullo stesso token.
  PERFORM pg_advisory_xact_lock(
    hashtextextended('exam_quiz_submit:' || v_uid::text || ':' || v_token, 0)
  );

  SELECT *
  INTO v_existing
  FROM public.exam_quiz_attempts a
  WHERE a.user_id = v_uid
    AND a.client_attempt_token = v_token;

  IF FOUND THEN
    IF v_existing.payload_fingerprint IS DISTINCT FROM v_fingerprint THEN
      RAISE EXCEPTION 'idempotency_conflict';
    END IF;

    RETURN jsonb_build_object(
      'attempt_id', v_existing.id,
      'license_category', v_existing.license_category,
      'completed_at', v_existing.completed_at,
      'duration_seconds', v_existing.duration_seconds,
      'time_expired', v_existing.time_expired,
      'total_questions', v_existing.total_questions,
      'correct_count', v_existing.correct_count,
      'wrong_count', v_existing.wrong_count,
      'unanswered_count', v_existing.unanswered_count,
      'passed', v_existing.passed,
      'idempotent', true
    );
  END IF;

  -- Accesso esame: exam_quiz_access usa categorie app (motore/d1), non A12/D1.
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

  IF NOT EXISTS (
    SELECT 1
    FROM public.exam_quiz_access eqa
    WHERE eqa.student_id = v_student_id
      AND eqa.license_category = v_access_category
      AND eqa.exam_unlocked = true
  ) THEN
    RAISE EXCEPTION 'exam_access_denied';
  END IF;

  -- Verifica domande autorevoli: esistenza, categoria, idoneità esame (exam_topic_code).
  SELECT count(*) FILTER (WHERE q.id IS NULL)::integer,
         count(*) FILTER (
           WHERE q.license_category IS DISTINCT FROM v_category
         )::integer,
         count(*) FILTER (
           WHERE q.exam_topic_code IS NULL OR btrim(q.exam_topic_code) = ''
         )::integer
  INTO v_missing_question_count,
       v_category_mismatch_count,
       v_invalid_exam_question_count
  FROM tmp_exam_submit_answers t
  LEFT JOIN public.questions q ON q.id = t.question_id;

  IF v_missing_question_count > 0 THEN
    RAISE EXCEPTION 'question_not_found';
  END IF;

  IF v_category_mismatch_count > 0 THEN
    RAISE EXCEPTION 'question_category_mismatch';
  END IF;

  IF v_invalid_exam_question_count > 0 THEN
    RAISE EXCEPTION 'question_not_valid_for_exam';
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
  FROM tmp_exam_submit_answers t
  INNER JOIN public.questions q ON q.id = t.question_id;

  -- Regola superamento: massimo 4 errori (risposte sbagliate + non risposte).
  v_passed := (v_wrong + v_unanswered) <= 4;

  BEGIN
    INSERT INTO public.exam_quiz_attempts (
      user_id,
      client_attempt_token,
      license_category,
      completed_at,
      duration_seconds,
      time_expired,
      total_questions,
      correct_count,
      wrong_count,
      unanswered_count,
      passed,
      payload_fingerprint
    )
    VALUES (
      v_uid,
      v_token,
      v_category,
      v_completed_at,
      p_duration_seconds,
      p_time_expired,
      20,
      v_correct,
      v_wrong,
      v_unanswered,
      v_passed,
      v_fingerprint
    )
    RETURNING id INTO v_attempt_id;

    INSERT INTO public.exam_quiz_attempt_answers (
      attempt_id,
      position,
      question_id,
      prompt_snapshot,
      option_a_snapshot,
      option_b_snapshot,
      option_c_snapshot,
      image_path_snapshot,
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
      t.selected_option,
      q.correct_option::text,
      (
        t.selected_option IS NOT NULL
        AND t.selected_option = q.correct_option::text
      )
    FROM tmp_exam_submit_answers t
    INNER JOIN public.questions q ON q.id = t.question_id
    ORDER BY t.position;
  EXCEPTION
    WHEN unique_violation THEN
      GET STACKED DIAGNOSTICS
        v_constraint_name = CONSTRAINT_NAME;

      -- Solo la chiave idempotente (user_id, client_attempt_token) può
      -- convergere su un tentativo esistente. Altri UNIQUE restano errori.
      IF v_constraint_name IS DISTINCT FROM 'exam_quiz_attempts_user_token_uq' THEN
        RAISE;
      END IF;

      SELECT *
      INTO v_existing
      FROM public.exam_quiz_attempts a
      WHERE a.user_id = v_uid
        AND a.client_attempt_token = v_token;

      IF NOT FOUND THEN
        RAISE EXCEPTION 'exam_submit_conflict';
      END IF;

      IF v_existing.payload_fingerprint IS DISTINCT FROM v_fingerprint THEN
        RAISE EXCEPTION 'idempotency_conflict';
      END IF;

      RETURN jsonb_build_object(
        'attempt_id', v_existing.id,
        'license_category', v_existing.license_category,
        'completed_at', v_existing.completed_at,
        'duration_seconds', v_existing.duration_seconds,
        'time_expired', v_existing.time_expired,
        'total_questions', v_existing.total_questions,
        'correct_count', v_existing.correct_count,
        'wrong_count', v_existing.wrong_count,
        'unanswered_count', v_existing.unanswered_count,
        'passed', v_existing.passed,
        'idempotent', true
      );
  END;

  RETURN jsonb_build_object(
    'attempt_id', v_attempt_id,
    'license_category', v_category,
    'completed_at', v_completed_at,
    'duration_seconds', p_duration_seconds,
    'time_expired', p_time_expired,
    'total_questions', 20,
    'correct_count', v_correct,
    'wrong_count', v_wrong,
    'unanswered_count', v_unanswered,
    'passed', v_passed,
    'idempotent', false
  );
END;
$$;

COMMENT ON FUNCTION public.submit_exam_quiz_attempt(text, text, integer, boolean, jsonb) IS
  'Studente: submit atomico simulazione esame (20 domande). user_id da auth.uid(); conteggi/esito/snapshot server-side; idempotente su (user_id, client_attempt_token).';

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------
ALTER TABLE public.exam_quiz_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exam_quiz_attempt_answers ENABLE ROW LEVEL SECURITY;

CREATE POLICY exam_quiz_attempts_student_select
  ON public.exam_quiz_attempts
  FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY exam_quiz_attempts_staff_select
  ON public.exam_quiz_attempts
  FOR SELECT
  USING (public.is_school_staff());

CREATE POLICY exam_quiz_attempt_answers_student_select
  ON public.exam_quiz_attempt_answers
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM public.exam_quiz_attempts a
      WHERE a.id = attempt_id
        AND a.user_id = auth.uid()
    )
  );

CREATE POLICY exam_quiz_attempt_answers_staff_select
  ON public.exam_quiz_attempt_answers
  FOR SELECT
  USING (public.is_school_staff());

-- ---------------------------------------------------------------------------
-- Privilegi tabella: scritture solo via RPC SECURITY DEFINER
-- ---------------------------------------------------------------------------
REVOKE ALL ON TABLE public.exam_quiz_attempts FROM PUBLIC;
REVOKE ALL ON TABLE public.exam_quiz_attempt_answers FROM PUBLIC;

GRANT SELECT ON TABLE public.exam_quiz_attempts TO authenticated;
GRANT SELECT ON TABLE public.exam_quiz_attempt_answers TO authenticated;

REVOKE INSERT, UPDATE, DELETE ON TABLE public.exam_quiz_attempts FROM authenticated;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.exam_quiz_attempt_answers FROM authenticated;

-- ---------------------------------------------------------------------------
-- Grant / revoke RPC + revoche anon (se ruolo presente)
-- ---------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.submit_exam_quiz_attempt(text, text, integer, boolean, jsonb) FROM PUBLIC;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    REVOKE ALL ON TABLE public.exam_quiz_attempts FROM anon;
    REVOKE ALL ON TABLE public.exam_quiz_attempt_answers FROM anon;
    REVOKE ALL ON FUNCTION public.submit_exam_quiz_attempt(text, text, integer, boolean, jsonb) FROM anon;
  END IF;

  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    GRANT EXECUTE ON FUNCTION public.submit_exam_quiz_attempt(text, text, integer, boolean, jsonb) TO authenticated;
  END IF;
END
$$;
