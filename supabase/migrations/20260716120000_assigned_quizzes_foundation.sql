-- =============================================================================
-- P9D.1-B/D — Quiz assegnati dalla scuola (foundation + hardening pre-applicazione)
-- =============================================================================
-- Modulo separato da schede lezione / quiz_results / quiz_attempt_answers.
-- Staff genera quiz personalizzati dagli errori storici lezione (A12/D1).
-- Studente svolge tentativi via RPC; correct_option non esposta prima del submit.
--
-- NON tocca: Contabilità, Stripe, payments, record_payment,
-- student_financial_summaries, quiz_sets, quiz_results, quiz_attempt_answers.
-- NON modifica is_own_student() né policy di altri moduli.
--
-- Applicare solo dopo approvazione esplicita (supabase db push).
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Contatore codice pubblico AQZ-YYYY-NNNNN
-- ---------------------------------------------------------------------------
CREATE TABLE public.assigned_quiz_code_counters (
  year integer PRIMARY KEY
    CHECK (year >= 2020 AND year <= 9999),
  last_value integer NOT NULL DEFAULT 0
    CHECK (last_value >= 0)
);

COMMENT ON TABLE public.assigned_quiz_code_counters IS
  'Contatore annuale per generate_assigned_quiz_public_code(). Uso interno RPC staff.';

ALTER TABLE public.assigned_quiz_code_counters ENABLE ROW LEVEL SECURITY;

-- Nessuna policy client: accesso solo via funzioni SECURITY DEFINER.

-- ---------------------------------------------------------------------------
-- Helper: codice pubblico AQZ-YYYY-NNNNN
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.generate_assigned_quiz_public_code()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_year integer;
  v_seq integer;
BEGIN
  v_year := extract(year FROM timezone('utc', now()))::integer;

  INSERT INTO public.assigned_quiz_code_counters AS counters (year, last_value)
  VALUES (v_year, 1)
  ON CONFLICT (year) DO UPDATE
    SET last_value = counters.last_value + 1
  RETURNING last_value INTO v_seq;

  IF v_seq > 99999 THEN
    RAISE EXCEPTION 'assigned_quiz_public_code_exhausted';
  END IF;

  RETURN 'AQZ-' || v_year::text || '-' || lpad(v_seq::text, 5, '0');
END;
$$;

COMMENT ON FUNCTION public.generate_assigned_quiz_public_code() IS
  'Genera codice assegnazione AQZ-YYYY-NNNNN (UTC). Contatore transazionale: rollback annulla il progressivo.';

REVOKE ALL ON FUNCTION public.generate_assigned_quiz_public_code() FROM PUBLIC;

-- ---------------------------------------------------------------------------
-- Helper: percorso iscrizione → categoria quiz DB (A12/D1)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.resolve_student_quiz_license_category(p_student_id uuid)
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_path text;
BEGIN
  IF p_student_id IS NULL THEN
    RAISE EXCEPTION 'student_id_required';
  END IF;

  SELECT s.enrolled_course_path
  INTO v_path
  FROM public.students s
  WHERE s.id = p_student_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'student_not_found';
  END IF;

  CASE v_path
    WHEN 'entro_12_miglia' THEN
      RETURN 'A12';
    WHEN 'd1' THEN
      RETURN 'D1';
    WHEN 'entro_12_miglia_vela' THEN
      RAISE EXCEPTION 'unsupported_license_path';
    ELSE
      RAISE EXCEPTION 'unsupported_license_path';
  END CASE;
END;
$$;

COMMENT ON FUNCTION public.resolve_student_quiz_license_category(uuid) IS
  'Deriva A12/D1 da students.enrolled_course_path. Rifiuta vela e percorsi sconosciuti.';

REVOKE ALL ON FUNCTION public.resolve_student_quiz_license_category(uuid) FROM PUBLIC;

-- ---------------------------------------------------------------------------
-- Tabelle
-- ---------------------------------------------------------------------------
CREATE TABLE public.assigned_quizzes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  public_code text NOT NULL UNIQUE,
  student_id uuid NOT NULL REFERENCES public.students (id) ON DELETE RESTRICT,
  student_user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE RESTRICT,
  license_category text NOT NULL
    CHECK (license_category IN ('A12', 'D1')),
  title text NOT NULL,
  staff_note text,
  status text NOT NULL
    CHECK (status IN ('draft', 'assigned', 'archived')),
  source_kind text NOT NULL DEFAULT 'lesson_errors',
  question_count integer NOT NULL
    CHECK (question_count > 0 AND question_count <= 50),
  repeat_policy text NOT NULL
    CHECK (repeat_policy IN ('unlimited', 'limited')),
  max_attempts integer,
  lesson_filter_mode text NOT NULL
    CHECK (lesson_filter_mode IN ('all_lessons', 'selected_lessons')),
  lesson_numbers integer[],
  sort_mode text NOT NULL DEFAULT 'most_wrong'
    CHECK (sort_mode IN ('most_wrong', 'most_recent')),
  allow_partial boolean NOT NULL DEFAULT false,
  created_by uuid NOT NULL REFERENCES auth.users (id) ON DELETE RESTRICT,
  updated_by uuid REFERENCES auth.users (id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  assigned_at timestamptz,
  expires_at timestamptz,
  archived_at timestamptz,
  idempotency_key text,
  generation_params jsonb,
  CONSTRAINT assigned_quizzes_repeat_policy_chk CHECK (
    (repeat_policy = 'unlimited' AND max_attempts IS NULL)
    OR (repeat_policy = 'limited' AND max_attempts IS NOT NULL AND max_attempts >= 1)
  ),
  CONSTRAINT assigned_quizzes_assigned_at_chk CHECK (
    (status = 'assigned' AND assigned_at IS NOT NULL)
    OR (status <> 'assigned')
  ),
  CONSTRAINT assigned_quizzes_draft_assigned_at_chk CHECK (
    (status = 'draft' AND assigned_at IS NULL)
    OR (status <> 'draft')
  ),
  CONSTRAINT assigned_quizzes_archived_at_chk CHECK (
    (status = 'archived' AND archived_at IS NOT NULL)
    OR (status <> 'archived')
  ),
  CONSTRAINT assigned_quizzes_selected_lessons_chk CHECK (
    lesson_filter_mode <> 'selected_lessons'
    OR (
      lesson_numbers IS NOT NULL
      AND cardinality(lesson_numbers) > 0
      AND lesson_numbers <@ ARRAY[1,2,3,4,5,6,7,8,9,10,11,12,13,14]::integer[]
    )
  ),
  CONSTRAINT assigned_quizzes_expires_after_origin_chk CHECK (
    expires_at IS NULL
    OR expires_at > created_at
  )
);

COMMENT ON TABLE public.assigned_quizzes IS
  'Quiz personalizzati assegnati dallo staff a un singolo allievo (separati da schede lezione).';

COMMENT ON COLUMN public.assigned_quizzes.public_code IS
  'Codice leggibile staff AQZ-YYYY-NNNNN.';

COMMENT ON COLUMN public.assigned_quizzes.idempotency_key IS
  'Chiave idempotenza generazione (scoped a created_by). Previene doppio click.';

COMMENT ON COLUMN public.assigned_quizzes.repeat_policy IS
  'unlimited: max_attempts NULL. limited: max_attempts >= 1.';

COMMENT ON COLUMN public.assigned_quizzes.status IS
  'draft (solo staff) | assigned (visibile allievo) | archived (storico, no nuovi tentativi).';

CREATE TABLE public.assigned_quiz_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  assignment_id uuid NOT NULL REFERENCES public.assigned_quizzes (id) ON DELETE CASCADE,
  position integer NOT NULL CHECK (position > 0),
  source_question_id uuid NOT NULL REFERENCES public.questions (id) ON DELETE RESTRICT,
  prompt text NOT NULL,
  option_a text NOT NULL,
  option_b text NOT NULL,
  option_c text NOT NULL,
  correct_option text NOT NULL
    CHECK (correct_option IN ('A', 'B', 'C')),
  explanation text,
  image_path text,
  snapshot_lesson_number integer NOT NULL
    CHECK (snapshot_lesson_number BETWEEN 1 AND 14),
  snapshot_license_category text NOT NULL
    CHECK (snapshot_license_category IN ('A12', 'D1')),
  snapshot_exam_topic_code text,
  snapshot_source_topic_text text,
  historical_error_count integer NOT NULL CHECK (historical_error_count >= 1),
  historical_last_wrong_at timestamptz,
  latest_wrong_selected_option text
    CHECK (
      latest_wrong_selected_option IS NULL
      OR latest_wrong_selected_option IN ('A', 'B', 'C')
    ),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT assigned_quiz_items_assignment_question_uq
    UNIQUE (assignment_id, source_question_id),
  CONSTRAINT assigned_quiz_items_assignment_position_uq
    UNIQUE (assignment_id, position)
);

COMMENT ON TABLE public.assigned_quiz_items IS
  'Domande congelate al momento dell''assegnazione. Modificabili solo in draft.';

COMMENT ON COLUMN public.assigned_quiz_items.correct_option IS
  'Risposta corretta snapshot. Non esporre allo studente prima del submit.';

CREATE TABLE public.assigned_quiz_attempts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  assignment_id uuid NOT NULL REFERENCES public.assigned_quizzes (id) ON DELETE RESTRICT,
  student_id uuid NOT NULL REFERENCES public.students (id) ON DELETE RESTRICT,
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE RESTRICT,
  attempt_number integer NOT NULL CHECK (attempt_number > 0),
  status text NOT NULL
    CHECK (status IN ('in_progress', 'submitted', 'abandoned')),
  started_at timestamptz NOT NULL DEFAULT now(),
  submitted_at timestamptz,
  abandoned_at timestamptz,
  correct_count integer NOT NULL DEFAULT 0 CHECK (correct_count >= 0),
  wrong_count integer NOT NULL DEFAULT 0 CHECK (wrong_count >= 0),
  unanswered_count integer NOT NULL DEFAULT 0 CHECK (unanswered_count >= 0),
  score_percentage numeric(5, 2) CHECK (
    score_percentage IS NULL
    OR (score_percentage >= 0 AND score_percentage <= 100)
  ),
  duration_seconds integer CHECK (duration_seconds IS NULL OR duration_seconds >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT assigned_quiz_attempts_assignment_attempt_uq
    UNIQUE (assignment_id, attempt_number),
  CONSTRAINT assigned_quiz_attempts_submitted_at_chk CHECK (
    (status = 'submitted' AND submitted_at IS NOT NULL)
    OR (status <> 'submitted')
  ),
  CONSTRAINT assigned_quiz_attempts_abandoned_at_chk CHECK (
    (status = 'abandoned' AND abandoned_at IS NOT NULL)
    OR (status <> 'abandoned')
  )
);

COMMENT ON TABLE public.assigned_quiz_attempts IS
  'Tentativi quiz assegnato. Un solo in_progress per (assignment_id, user_id).';

CREATE TABLE public.assigned_quiz_attempt_answers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  attempt_id uuid NOT NULL REFERENCES public.assigned_quiz_attempts (id) ON DELETE CASCADE,
  assignment_item_id uuid NOT NULL REFERENCES public.assigned_quiz_items (id) ON DELETE RESTRICT,
  position integer NOT NULL CHECK (position > 0),
  selected_option text
    CHECK (
      selected_option IS NULL
      OR selected_option IN ('A', 'B', 'C')
    ),
  correct_option text NOT NULL
    CHECK (correct_option IN ('A', 'B', 'C')),
  is_correct boolean,
  answered_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT assigned_quiz_attempt_answers_attempt_item_uq
    UNIQUE (attempt_id, assignment_item_id)
);

COMMENT ON TABLE public.assigned_quiz_attempt_answers IS
  'Risposte tentativo. is_correct valorizzato solo al submit. Accesso studente via RPC.';

COMMENT ON COLUMN public.assigned_quiz_attempt_answers.correct_option IS
  'Copia server-side da item. Non leggibile direttamente dallo studente prima del submit.';

-- ---------------------------------------------------------------------------
-- Indici
-- ---------------------------------------------------------------------------
CREATE INDEX idx_assigned_quizzes_student_status
  ON public.assigned_quizzes (student_id, status);

CREATE INDEX idx_assigned_quizzes_student_user_status
  ON public.assigned_quizzes (student_user_id, status);

CREATE INDEX idx_assigned_quizzes_expires_assigned
  ON public.assigned_quizzes (expires_at)
  WHERE status = 'assigned';

CREATE UNIQUE INDEX assigned_quizzes_idempotency_uq
  ON public.assigned_quizzes (created_by, idempotency_key)
  WHERE idempotency_key IS NOT NULL;

CREATE INDEX idx_assigned_quiz_items_assignment_position
  ON public.assigned_quiz_items (assignment_id, position);

CREATE INDEX idx_assigned_quiz_attempts_assignment_user_submitted
  ON public.assigned_quiz_attempts (assignment_id, user_id, submitted_at DESC);

CREATE UNIQUE INDEX assigned_quiz_attempts_one_in_progress_uq
  ON public.assigned_quiz_attempts (assignment_id, user_id)
  WHERE status = 'in_progress';

CREATE INDEX idx_assigned_quiz_attempt_answers_attempt
  ON public.assigned_quiz_attempt_answers (attempt_id);

-- ---------------------------------------------------------------------------
-- Trigger updated_at
-- ---------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_assigned_quizzes_updated ON public.assigned_quizzes;
CREATE TRIGGER trg_assigned_quizzes_updated
  BEFORE UPDATE ON public.assigned_quizzes
  FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();

DROP TRIGGER IF EXISTS trg_assigned_quiz_attempts_updated ON public.assigned_quiz_attempts;
CREATE TRIGGER trg_assigned_quiz_attempts_updated
  BEFORE UPDATE ON public.assigned_quiz_attempts
  FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();

DROP TRIGGER IF EXISTS trg_assigned_quiz_attempt_answers_updated ON public.assigned_quiz_attempt_answers;
CREATE TRIGGER trg_assigned_quiz_attempt_answers_updated
  BEFORE UPDATE ON public.assigned_quiz_attempt_answers
  FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Integrità header: ownership, categoria, stato, campi immutabili
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.enforce_assigned_quiz_header_integrity()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_student_user_id uuid;
  v_expected_category text;
  v_item_count integer;
  v_min_position integer;
  v_max_position integer;
  v_distinct_positions integer;
  v_mismatch_items integer;
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.status <> 'draft' THEN
      RAISE EXCEPTION 'assigned_quiz_insert_must_be_draft';
    END IF;

    IF NEW.assigned_at IS NOT NULL OR NEW.archived_at IS NOT NULL THEN
      RAISE EXCEPTION 'assigned_quiz_draft_timestamps_must_be_null';
    END IF;

    SELECT s.user_id
    INTO v_student_user_id
    FROM public.students s
    WHERE s.id = NEW.student_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'student_not_found';
    END IF;

    IF v_student_user_id IS NULL THEN
      RAISE EXCEPTION 'student_user_id_missing';
    END IF;

    IF NEW.student_user_id IS DISTINCT FROM v_student_user_id THEN
      RAISE EXCEPTION 'assigned_quiz_student_user_mismatch';
    END IF;

    v_expected_category := public.resolve_student_quiz_license_category(NEW.student_id);
    IF NEW.license_category IS DISTINCT FROM v_expected_category THEN
      RAISE EXCEPTION 'assigned_quiz_license_category_mismatch';
    END IF;

    IF auth.uid() IS NOT NULL AND NEW.created_by IS DISTINCT FROM auth.uid() THEN
      RAISE EXCEPTION 'assigned_quiz_created_by_mismatch';
    END IF;

    IF auth.uid() IS NOT NULL THEN
      NEW.updated_by := auth.uid();
    END IF;

    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    IF NEW.id IS DISTINCT FROM OLD.id
       OR NEW.public_code IS DISTINCT FROM OLD.public_code
       OR NEW.student_id IS DISTINCT FROM OLD.student_id
       OR NEW.student_user_id IS DISTINCT FROM OLD.student_user_id
       OR NEW.license_category IS DISTINCT FROM OLD.license_category
       OR NEW.created_by IS DISTINCT FROM OLD.created_by
       OR NEW.source_kind IS DISTINCT FROM OLD.source_kind
       OR NEW.idempotency_key IS DISTINCT FROM OLD.idempotency_key
       OR NEW.generation_params IS DISTINCT FROM OLD.generation_params
       OR NEW.question_count IS DISTINCT FROM OLD.question_count
       OR NEW.lesson_filter_mode IS DISTINCT FROM OLD.lesson_filter_mode
       OR NEW.lesson_numbers IS DISTINCT FROM OLD.lesson_numbers
       OR NEW.sort_mode IS DISTINCT FROM OLD.sort_mode
       OR NEW.allow_partial IS DISTINCT FROM OLD.allow_partial THEN
      RAISE EXCEPTION 'assigned_quiz_header_immutable_field';
    END IF;

    IF OLD.status IN ('assigned', 'archived') THEN
      IF NEW.repeat_policy IS DISTINCT FROM OLD.repeat_policy
         OR NEW.max_attempts IS DISTINCT FROM OLD.max_attempts THEN
        RAISE EXCEPTION 'assigned_quiz_header_immutable_field';
      END IF;
    END IF;

    IF NEW.status IS DISTINCT FROM OLD.status THEN
      IF NOT (
        (OLD.status = 'draft' AND NEW.status IN ('draft', 'assigned', 'archived'))
        OR (OLD.status = 'assigned' AND NEW.status IN ('assigned', 'archived'))
        OR (OLD.status = 'archived' AND NEW.status = 'archived')
      ) THEN
        RAISE EXCEPTION 'invalid_assigned_quiz_status_transition';
      END IF;
    END IF;

    IF OLD.assigned_at IS NOT NULL AND NEW.assigned_at IS DISTINCT FROM OLD.assigned_at THEN
      RAISE EXCEPTION 'assigned_quiz_assigned_at_immutable';
    END IF;

    IF OLD.archived_at IS NOT NULL AND NEW.archived_at IS DISTINCT FROM OLD.archived_at THEN
      RAISE EXCEPTION 'assigned_quiz_archived_at_immutable';
    END IF;

    IF NEW.status = 'assigned' AND OLD.status = 'draft' THEN
      NEW.assigned_at := now();

      SELECT count(*)::integer,
             min(i.position),
             max(i.position),
             count(DISTINCT i.position)::integer,
             count(*) FILTER (
               WHERE i.snapshot_license_category IS DISTINCT FROM NEW.license_category
             )::integer
      INTO v_item_count, v_min_position, v_max_position, v_distinct_positions, v_mismatch_items
      FROM public.assigned_quiz_items i
      WHERE i.assignment_id = NEW.id;

      IF v_item_count = 0
         OR v_item_count <> NEW.question_count
         OR v_min_position <> 1
         OR v_max_position <> NEW.question_count
         OR v_distinct_positions <> NEW.question_count
         OR v_mismatch_items > 0 THEN
        RAISE EXCEPTION 'assigned_quiz_items_incomplete';
      END IF;
    END IF;

    IF NEW.status = 'archived' AND OLD.status IS DISTINCT FROM 'archived' THEN
      NEW.archived_at := now();
    END IF;

    IF NEW.status = 'draft' THEN
      NEW.assigned_at := NULL;
    END IF;

    IF NEW.expires_at IS NOT NULL
       AND NEW.expires_at <= COALESCE(NEW.assigned_at, NEW.created_at) THEN
      RAISE EXCEPTION 'expires_at_must_be_future';
    END IF;

    IF auth.uid() IS NOT NULL THEN
      NEW.updated_by := auth.uid();
    END IF;

    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_assigned_quizzes_header_immutable ON public.assigned_quizzes;
DROP TRIGGER IF EXISTS trg_assigned_quizzes_header_integrity ON public.assigned_quizzes;
CREATE TRIGGER trg_assigned_quizzes_header_integrity
  BEFORE INSERT OR UPDATE ON public.assigned_quizzes
  FOR EACH ROW EXECUTE PROCEDURE public.enforce_assigned_quiz_header_integrity();

-- ---------------------------------------------------------------------------
-- Integrità: item modificabili solo in draft + validazione snapshot
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.enforce_assigned_quiz_items_integrity()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_status text;
  v_license_category text;
  v_question_lesson integer;
  v_question_category text;
  v_question_correct text;
BEGIN
  IF TG_OP = 'DELETE' THEN
    SELECT aq.status
    INTO v_status
    FROM public.assigned_quizzes aq
    WHERE aq.id = OLD.assignment_id;

    -- CASCADE da DELETE parent già autorizzato: la riga parent non è più reperibile.
    IF NOT FOUND THEN
      RETURN OLD;
    END IF;

    IF v_status IS DISTINCT FROM 'draft' THEN
      RAISE EXCEPTION 'assigned_quiz_items_frozen';
    END IF;

    RETURN OLD;
  END IF;

  SELECT aq.status, aq.license_category
  INTO v_status, v_license_category
  FROM public.assigned_quizzes aq
  WHERE aq.id = NEW.assignment_id;

  IF v_status IS DISTINCT FROM 'draft' THEN
    RAISE EXCEPTION 'assigned_quiz_items_frozen';
  END IF;

  IF NEW.snapshot_license_category IS DISTINCT FROM v_license_category THEN
    RAISE EXCEPTION 'assigned_quiz_item_snapshot_category_mismatch';
  END IF;

  IF NEW.snapshot_lesson_number < 1 OR NEW.snapshot_lesson_number > 14 THEN
    RAISE EXCEPTION 'assigned_quiz_item_invalid_lesson_number';
  END IF;

  SELECT q.lesson_number, q.license_category, q.correct_option::text
  INTO v_question_lesson, v_question_category, v_question_correct
  FROM public.questions q
  WHERE q.id = NEW.source_question_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'assigned_quiz_item_source_question_not_found';
  END IF;

  IF v_question_lesson IS NULL THEN
    RAISE EXCEPTION 'assigned_quiz_item_source_lesson_null';
  END IF;

  IF v_question_category IS DISTINCT FROM v_license_category THEN
    RAISE EXCEPTION 'assigned_quiz_item_source_category_mismatch';
  END IF;

  IF NEW.snapshot_lesson_number IS DISTINCT FROM v_question_lesson THEN
    RAISE EXCEPTION 'assigned_quiz_item_snapshot_lesson_mismatch';
  END IF;

  IF NEW.correct_option IS DISTINCT FROM v_question_correct THEN
    RAISE EXCEPTION 'assigned_quiz_item_snapshot_correct_option_mismatch';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_assigned_quiz_items_freeze ON public.assigned_quiz_items;
DROP TRIGGER IF EXISTS trg_assigned_quiz_items_integrity ON public.assigned_quiz_items;
CREATE TRIGGER trg_assigned_quiz_items_integrity
  BEFORE INSERT OR UPDATE OR DELETE ON public.assigned_quiz_items
  FOR EACH ROW EXECUTE PROCEDURE public.enforce_assigned_quiz_items_integrity();

-- ---------------------------------------------------------------------------
-- Integrità: cancellazione fisica solo draft senza tentativi
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.enforce_assigned_quiz_delete_allowed()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  IF OLD.status <> 'draft' THEN
    RAISE EXCEPTION 'assigned_quiz_delete_not_allowed';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.assigned_quiz_attempts a
    WHERE a.assignment_id = OLD.id
  ) THEN
    RAISE EXCEPTION 'assigned_quiz_delete_not_allowed';
  END IF;

  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trg_assigned_quizzes_delete_allowed ON public.assigned_quizzes;
CREATE TRIGGER trg_assigned_quizzes_delete_allowed
  BEFORE DELETE ON public.assigned_quizzes
  FOR EACH ROW EXECUTE PROCEDURE public.enforce_assigned_quiz_delete_allowed();

-- ---------------------------------------------------------------------------
-- Integrità: tentativo coerente con assegnazione
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.enforce_assigned_quiz_attempt_integrity()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_assignment public.assigned_quizzes%ROWTYPE;
BEGIN
  SELECT *
  INTO v_assignment
  FROM public.assigned_quizzes aq
  WHERE aq.id = NEW.assignment_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'assignment_not_found';
  END IF;

  IF NEW.student_id IS DISTINCT FROM v_assignment.student_id
     OR NEW.user_id IS DISTINCT FROM v_assignment.student_user_id THEN
    RAISE EXCEPTION 'assigned_quiz_attempt_ownership_mismatch';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_assigned_quiz_attempt_integrity ON public.assigned_quiz_attempts;
CREATE TRIGGER trg_assigned_quiz_attempt_integrity
  BEFORE INSERT OR UPDATE ON public.assigned_quiz_attempts
  FOR EACH ROW EXECUTE PROCEDURE public.enforce_assigned_quiz_attempt_integrity();

-- ---------------------------------------------------------------------------
-- Integrità: answer item deve appartenere allo stesso assignment del tentativo
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.enforce_assigned_quiz_answer_item_assignment()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_attempt_assignment_id uuid;
  v_item_assignment_id uuid;
BEGIN
  SELECT a.assignment_id
  INTO v_attempt_assignment_id
  FROM public.assigned_quiz_attempts a
  WHERE a.id = NEW.attempt_id;

  SELECT i.assignment_id
  INTO v_item_assignment_id
  FROM public.assigned_quiz_items i
  WHERE i.id = NEW.assignment_item_id;

  IF v_attempt_assignment_id IS DISTINCT FROM v_item_assignment_id THEN
    RAISE EXCEPTION 'assignment_item_mismatch';
  END IF;

  IF TG_OP IN ('INSERT', 'UPDATE') THEN
    IF EXISTS (
      SELECT 1
      FROM public.assigned_quiz_items i
      WHERE i.id = NEW.assignment_item_id
        AND (
          NEW.position IS DISTINCT FROM i.position
          OR NEW.correct_option IS DISTINCT FROM i.correct_option
        )
    ) THEN
      RAISE EXCEPTION 'assigned_quiz_answer_shell_mismatch';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_assigned_quiz_answer_item_assignment ON public.assigned_quiz_attempt_answers;
CREATE TRIGGER trg_assigned_quiz_answer_item_assignment
  BEFORE INSERT OR UPDATE ON public.assigned_quiz_attempt_answers
  FOR EACH ROW EXECUTE PROCEDURE public.enforce_assigned_quiz_answer_item_assignment();

-- ---------------------------------------------------------------------------
-- RPC: generate_assigned_quiz_from_errors
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.generate_assigned_quiz_from_errors(
  p_student_id uuid,
  p_title text,
  p_staff_note text DEFAULT NULL,
  p_question_count integer DEFAULT 20,
  p_lesson_filter_mode text DEFAULT 'all_lessons',
  p_lesson_numbers integer[] DEFAULT NULL,
  p_sort_mode text DEFAULT 'most_wrong',
  p_repeat_policy text DEFAULT 'unlimited',
  p_max_attempts integer DEFAULT NULL,
  p_expires_at timestamptz DEFAULT NULL,
  p_allow_partial boolean DEFAULT false,
  p_assign_immediately boolean DEFAULT true,
  p_idempotency_key text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid;
  v_student_user_id uuid;
  v_license_category text;
  v_existing public.assigned_quizzes%ROWTYPE;
  v_assignment_id uuid;
  v_public_code text;
  v_final_status text;
  v_target_count integer;
  v_available_count integer;
  v_item_count integer;
  v_normalized_key text;
  v_normalized_lessons integer[];
  v_generation_params jsonb;
  r record;
  v_position integer := 0;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  IF NOT public.is_school_staff() THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  IF p_student_id IS NULL THEN
    RAISE EXCEPTION 'student_id_required';
  END IF;

  IF p_title IS NULL OR btrim(p_title) = '' THEN
    RAISE EXCEPTION 'title_required';
  END IF;

  IF p_question_count IS NULL OR p_question_count < 1 OR p_question_count > 50 THEN
    RAISE EXCEPTION 'invalid_question_count';
  END IF;

  IF p_lesson_filter_mode NOT IN ('all_lessons', 'selected_lessons') THEN
    RAISE EXCEPTION 'invalid_lesson_filter_mode';
  END IF;

  IF p_sort_mode NOT IN ('most_wrong', 'most_recent') THEN
    RAISE EXCEPTION 'invalid_sort_mode';
  END IF;

  IF p_repeat_policy NOT IN ('unlimited', 'limited') THEN
    RAISE EXCEPTION 'invalid_repeat_policy';
  END IF;

  IF p_repeat_policy = 'limited' AND (p_max_attempts IS NULL OR p_max_attempts < 1) THEN
    RAISE EXCEPTION 'invalid_max_attempts';
  END IF;

  IF p_repeat_policy = 'unlimited' AND p_max_attempts IS NOT NULL THEN
    RAISE EXCEPTION 'max_attempts_must_be_null_for_unlimited';
  END IF;

  IF p_expires_at IS NOT NULL AND p_expires_at <= now() THEN
    RAISE EXCEPTION 'expires_at_must_be_future';
  END IF;

  v_normalized_key := NULLIF(btrim(p_idempotency_key), '');

  IF p_lesson_filter_mode = 'selected_lessons' AND p_lesson_numbers IS NOT NULL THEN
    SELECT coalesce(array_agg(ln ORDER BY ln), ARRAY[]::integer[])
    INTO v_normalized_lessons
    FROM (
      SELECT DISTINCT ln
      FROM unnest(p_lesson_numbers) AS u(ln)
      WHERE ln BETWEEN 1 AND 14
    ) s;
  END IF;

  v_generation_params := jsonb_build_object(
    'student_id', p_student_id,
    'title', btrim(p_title),
    'staff_note', NULLIF(btrim(p_staff_note), ''),
    'requested_question_count', p_question_count,
    'lesson_filter_mode', p_lesson_filter_mode,
    'lesson_numbers', to_jsonb(v_normalized_lessons),
    'sort_mode', p_sort_mode,
    'repeat_policy', p_repeat_policy,
    'max_attempts', p_max_attempts,
    'expires_at', CASE
      WHEN p_expires_at IS NULL THEN NULL
      ELSE to_jsonb(p_expires_at)
    END,
    'allow_partial', p_allow_partial,
    'assign_immediately', p_assign_immediately
  );

  IF v_normalized_key IS NOT NULL THEN
    SELECT *
    INTO v_existing
    FROM public.assigned_quizzes aq
    WHERE aq.created_by = v_uid
      AND aq.idempotency_key = v_normalized_key
    LIMIT 1;

    IF FOUND THEN
      IF v_existing.generation_params IS DISTINCT FROM v_generation_params THEN
        RAISE EXCEPTION 'idempotency_conflict';
      END IF;

      SELECT count(*)::integer
      INTO v_item_count
      FROM public.assigned_quiz_items i
      WHERE i.assignment_id = v_existing.id;

      RETURN jsonb_build_object(
        'assignment_id', v_existing.id,
        'public_code', v_existing.public_code,
        'item_count', v_item_count,
        'status', v_existing.status,
        'license_category', v_existing.license_category,
        'idempotent', true
      );
    END IF;
  END IF;

  PERFORM pg_advisory_xact_lock(
    hashtextextended('assigned_quiz_gen:' || p_student_id::text, 0)
  );

  SELECT s.user_id
  INTO v_student_user_id
  FROM public.students s
  WHERE s.id = p_student_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'student_not_found';
  END IF;

  IF v_student_user_id IS NULL THEN
    RAISE EXCEPTION 'student_user_id_missing';
  END IF;

  v_license_category := public.resolve_student_quiz_license_category(p_student_id);

  IF p_lesson_filter_mode = 'selected_lessons' THEN
    IF p_lesson_numbers IS NULL
       OR cardinality(p_lesson_numbers) = 0
       OR EXISTS (
         SELECT 1
         FROM unnest(p_lesson_numbers) AS ln(n)
         WHERE ln.n < 1 OR ln.n > 14
       ) THEN
      RAISE EXCEPTION 'invalid_lesson_numbers';
    END IF;
  END IF;

  WITH errors AS (
    SELECT
      qaa.question_id,
      count(*)::integer AS error_count,
      max(qaa.answered_at) AS last_wrong_at,
      (array_agg(qaa.selected_option ORDER BY qaa.answered_at DESC))[1] AS latest_wrong_selected_option
    FROM public.quiz_attempt_answers qaa
    INNER JOIN public.quiz_results qr ON qr.id = qaa.quiz_result_id
    INNER JOIN public.quiz_sets qs ON qs.id = qr.quiz_set_id
    INNER JOIN public.questions q ON q.id = qaa.question_id
    WHERE qaa.user_id = v_student_user_id
      AND qr.user_id = v_student_user_id
      AND qr.completed_at IS NOT NULL
      AND qaa.is_correct = false
      AND qaa.selected_option IS NOT NULL
      AND qs.kind = 'lesson'
      AND q.license_category = v_license_category
      AND q.lesson_number IS NOT NULL
      AND (
        p_lesson_filter_mode = 'all_lessons'
        OR q.lesson_number = ANY (coalesce(v_normalized_lessons, p_lesson_numbers))
      )
    GROUP BY qaa.question_id
  )
  SELECT count(*)::integer
  INTO v_available_count
  FROM errors;

  IF v_available_count = 0 THEN
    RAISE EXCEPTION 'no_error_questions';
  END IF;

  v_target_count := p_question_count;
  IF v_available_count < p_question_count THEN
    IF NOT p_allow_partial THEN
      RAISE EXCEPTION 'insufficient_error_questions';
    END IF;
    v_target_count := v_available_count;
  END IF;

  v_public_code := public.generate_assigned_quiz_public_code();

  INSERT INTO public.assigned_quizzes (
    public_code,
    student_id,
    student_user_id,
    license_category,
    title,
    staff_note,
    status,
    source_kind,
    question_count,
    repeat_policy,
    max_attempts,
    lesson_filter_mode,
    lesson_numbers,
    sort_mode,
    allow_partial,
    created_by,
    updated_by,
    assigned_at,
    expires_at,
    idempotency_key,
    generation_params
  )
  VALUES (
    v_public_code,
    p_student_id,
    v_student_user_id,
    v_license_category,
    btrim(p_title),
    NULLIF(btrim(p_staff_note), ''),
    'draft',
    'lesson_errors',
    v_target_count,
    p_repeat_policy,
    p_max_attempts,
    p_lesson_filter_mode,
    coalesce(v_normalized_lessons, p_lesson_numbers),
    p_sort_mode,
    p_allow_partial,
    v_uid,
    v_uid,
    NULL,
    p_expires_at,
    v_normalized_key,
    v_generation_params
  )
  RETURNING id INTO v_assignment_id;

  FOR r IN
    WITH errors AS (
      SELECT
        qaa.question_id,
        count(*)::integer AS error_count,
        max(qaa.answered_at) AS last_wrong_at,
        (array_agg(qaa.selected_option ORDER BY qaa.answered_at DESC))[1] AS latest_wrong_selected_option
      FROM public.quiz_attempt_answers qaa
      INNER JOIN public.quiz_results qr ON qr.id = qaa.quiz_result_id
      INNER JOIN public.quiz_sets qs ON qs.id = qr.quiz_set_id
      INNER JOIN public.questions q ON q.id = qaa.question_id
      WHERE qaa.user_id = v_student_user_id
        AND qr.user_id = v_student_user_id
        AND qr.completed_at IS NOT NULL
        AND qaa.is_correct = false
        AND qaa.selected_option IS NOT NULL
        AND qs.kind = 'lesson'
        AND q.license_category = v_license_category
        AND q.lesson_number IS NOT NULL
        AND (
          p_lesson_filter_mode = 'all_lessons'
          OR q.lesson_number = ANY (coalesce(v_normalized_lessons, p_lesson_numbers))
        )
      GROUP BY qaa.question_id
    ),
    ranked AS (
      SELECT
        e.question_id,
        e.error_count,
        e.last_wrong_at,
        e.latest_wrong_selected_option,
        q.prompt,
        q.option_a,
        q.option_b,
        q.option_c,
        q.correct_option::text AS correct_option,
        q.explanation,
        q.image_path,
        q.lesson_number,
        q.license_category,
        q.exam_topic_code,
        q.source_topic_text
      FROM errors e
      INNER JOIN public.questions q ON q.id = e.question_id
      ORDER BY
        CASE p_sort_mode
          WHEN 'most_wrong' THEN e.error_count
          ELSE extract(epoch FROM e.last_wrong_at)::bigint
        END DESC,
        CASE p_sort_mode
          WHEN 'most_wrong' THEN extract(epoch FROM e.last_wrong_at)::bigint
          ELSE e.error_count
        END DESC,
        q.lesson_number ASC NULLS LAST,
        e.question_id ASC
      LIMIT v_target_count
    )
    SELECT * FROM ranked
  LOOP
    v_position := v_position + 1;
    INSERT INTO public.assigned_quiz_items (
      assignment_id,
      position,
      source_question_id,
      prompt,
      option_a,
      option_b,
      option_c,
      correct_option,
      explanation,
      image_path,
      snapshot_lesson_number,
      snapshot_license_category,
      snapshot_exam_topic_code,
      snapshot_source_topic_text,
      historical_error_count,
      historical_last_wrong_at,
      latest_wrong_selected_option
    )
    VALUES (
      v_assignment_id,
      v_position,
      r.question_id,
      r.prompt,
      r.option_a,
      r.option_b,
      r.option_c,
      r.correct_option,
      r.explanation,
      r.image_path,
      r.lesson_number,
      r.license_category,
      r.exam_topic_code,
      r.source_topic_text,
      r.error_count,
      r.last_wrong_at,
      r.latest_wrong_selected_option::text
    );
  END LOOP;

  IF v_position <> v_target_count THEN
    RAISE EXCEPTION 'assigned_quiz_items_incomplete';
  END IF;

  v_final_status := 'draft';
  IF p_assign_immediately THEN
    UPDATE public.assigned_quizzes aq
    SET status = 'assigned'
    WHERE aq.id = v_assignment_id;
    v_final_status := 'assigned';
  END IF;

  RETURN jsonb_build_object(
    'assignment_id', v_assignment_id,
    'public_code', v_public_code,
    'item_count', v_position,
    'status', v_final_status,
    'license_category', v_license_category,
    'idempotent', false
  );
END;
$$;

COMMENT ON FUNCTION public.generate_assigned_quiz_from_errors(
  uuid, text, text, integer, text, integer[], text, text, integer, timestamptz, boolean, boolean, text
) IS
  'Staff: genera quiz assegnato dagli errori lezione storici. Snapshot atomico. Solo A12/D1.';

-- ---------------------------------------------------------------------------
-- RPC: start_assigned_quiz_attempt
-- ---------------------------------------------------------------------------
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
  'Studente: avvia o riprende tentativo in_progress. Conta limite su in_progress+submitted+abandoned.';

-- ---------------------------------------------------------------------------
-- RPC: get_assigned_quiz_attempt_questions
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_assigned_quiz_attempt_questions(p_attempt_id uuid)
RETURNS SETOF jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid;
  v_attempt public.assigned_quiz_attempts%ROWTYPE;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  SELECT *
  INTO v_attempt
  FROM public.assigned_quiz_attempts a
  WHERE a.id = p_attempt_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'attempt_not_found';
  END IF;

  IF v_attempt.user_id IS DISTINCT FROM v_uid THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  IF v_attempt.status <> 'in_progress' THEN
    RAISE EXCEPTION 'attempt_not_in_progress';
  END IF;

  RETURN QUERY
  SELECT jsonb_build_object(
    'assignment_item_id', i.id,
    'position', i.position,
    'prompt', i.prompt,
    'option_a', i.option_a,
    'option_b', i.option_b,
    'option_c', i.option_c,
    'image_path', i.image_path,
    'lesson_number', i.snapshot_lesson_number,
    'selected_option', ans.selected_option,
    'answered_at', ans.answered_at
  )
  FROM public.assigned_quiz_items i
  INNER JOIN public.assigned_quiz_attempt_answers ans
    ON ans.assignment_item_id = i.id
   AND ans.attempt_id = p_attempt_id
  WHERE i.assignment_id = v_attempt.assignment_id
  ORDER BY i.position;
END;
$$;

COMMENT ON FUNCTION public.get_assigned_quiz_attempt_questions(uuid) IS
  'Studente: domande sicure per player (no correct_option/explanation/is_correct).';

-- ---------------------------------------------------------------------------
-- RPC: save_assigned_quiz_attempt_answer
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.save_assigned_quiz_attempt_answer(
  p_attempt_id uuid,
  p_assignment_item_id uuid,
  p_selected_option text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid;
  v_attempt public.assigned_quiz_attempts%ROWTYPE;
  v_answer public.assigned_quiz_attempt_answers%ROWTYPE;
  v_normalized_option text;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  IF p_attempt_id IS NULL OR p_assignment_item_id IS NULL THEN
    RAISE EXCEPTION 'invalid_parameters';
  END IF;

  v_normalized_option := NULLIF(upper(btrim(p_selected_option)), '');

  IF v_normalized_option IS NOT NULL
     AND v_normalized_option NOT IN ('A', 'B', 'C') THEN
    RAISE EXCEPTION 'invalid_selected_option';
  END IF;

  SELECT *
  INTO v_attempt
  FROM public.assigned_quiz_attempts a
  WHERE a.id = p_attempt_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'attempt_not_found';
  END IF;

  IF v_attempt.user_id IS DISTINCT FROM v_uid THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  IF v_attempt.status <> 'in_progress' THEN
    RAISE EXCEPTION 'attempt_not_in_progress';
  END IF;

  UPDATE public.assigned_quiz_attempt_answers ans
  SET
    selected_option = v_normalized_option,
    answered_at = CASE
      WHEN v_normalized_option IS NULL THEN NULL
      ELSE now()
    END
  WHERE ans.attempt_id = p_attempt_id
    AND ans.assignment_item_id = p_assignment_item_id
  RETURNING * INTO v_answer;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'answer_not_found';
  END IF;

  RETURN jsonb_build_object(
    'assignment_item_id', v_answer.assignment_item_id,
    'selected_option', v_answer.selected_option,
    'answered_at', v_answer.answered_at
  );
END;
$$;

COMMENT ON FUNCTION public.save_assigned_quiz_attempt_answer(uuid, uuid, text) IS
  'Studente: salva/azzera risposta su tentativo in_progress. Non espone correct_option.';

-- ---------------------------------------------------------------------------
-- RPC: submit_assigned_quiz_attempt
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.submit_assigned_quiz_attempt(p_attempt_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid;
  v_attempt public.assigned_quiz_attempts%ROWTYPE;
  v_assignment_question_count integer;
  v_shell_count integer;
  v_distinct_items integer;
  v_correct integer;
  v_wrong integer;
  v_unanswered integer;
  v_total integer;
  v_score numeric(5, 2);
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  SELECT *
  INTO v_attempt
  FROM public.assigned_quiz_attempts a
  WHERE a.id = p_attempt_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'attempt_not_found';
  END IF;

  IF v_attempt.user_id IS DISTINCT FROM v_uid THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  IF v_attempt.status = 'submitted' THEN
    RETURN jsonb_build_object(
      'attempt_id', v_attempt.id,
      'attempt_number', v_attempt.attempt_number,
      'correct_count', v_attempt.correct_count,
      'wrong_count', v_attempt.wrong_count,
      'unanswered_count', v_attempt.unanswered_count,
      'score_percentage', v_attempt.score_percentage,
      'submitted_at', v_attempt.submitted_at,
      'already_submitted', true
    );
  END IF;

  IF v_attempt.status <> 'in_progress' THEN
    RAISE EXCEPTION 'attempt_not_in_progress';
  END IF;

  SELECT aq.question_count
  INTO v_assignment_question_count
  FROM public.assigned_quizzes aq
  WHERE aq.id = v_attempt.assignment_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'assignment_not_found';
  END IF;

  SELECT count(*)::integer
  INTO v_shell_count
  FROM public.assigned_quiz_attempt_answers ans
  WHERE ans.attempt_id = p_attempt_id;

  SELECT count(*)::integer
  INTO v_distinct_items
  FROM (
    SELECT DISTINCT ans.assignment_item_id
    FROM public.assigned_quiz_attempt_answers ans
    WHERE ans.attempt_id = p_attempt_id
  ) distinct_items;

  IF EXISTS (
    SELECT 1
    FROM public.assigned_quiz_attempt_answers ans
    LEFT JOIN public.assigned_quiz_items i
      ON i.id = ans.assignment_item_id
     AND i.assignment_id = v_attempt.assignment_id
    WHERE ans.attempt_id = p_attempt_id
      AND i.id IS NULL
  )
  OR v_shell_count <> v_assignment_question_count
  OR v_distinct_items <> v_assignment_question_count THEN
    RAISE EXCEPTION 'assigned_quiz_attempt_answers_incomplete';
  END IF;

  UPDATE public.assigned_quiz_attempt_answers ans
  SET is_correct = (
    ans.selected_option IS NOT NULL
    AND ans.selected_option = ans.correct_option
  )
  WHERE ans.attempt_id = p_attempt_id;

  SELECT
    count(*) FILTER (WHERE ans.is_correct IS TRUE)::integer,
    count(*) FILTER (
      WHERE ans.is_correct IS FALSE
        AND ans.selected_option IS NOT NULL
    )::integer,
    count(*) FILTER (WHERE ans.selected_option IS NULL)::integer,
    count(*)::integer
  INTO v_correct, v_wrong, v_unanswered, v_total
  FROM public.assigned_quiz_attempt_answers ans
  WHERE ans.attempt_id = p_attempt_id;

  IF v_total = 0 THEN
    RAISE EXCEPTION 'attempt_has_no_answers';
  END IF;

  IF v_correct + v_wrong + v_unanswered <> v_assignment_question_count THEN
    RAISE EXCEPTION 'assigned_quiz_attempt_answers_incomplete';
  END IF;

  v_score := round((v_correct::numeric / v_total::numeric) * 100, 2);

  UPDATE public.assigned_quiz_attempts a
  SET
    status = 'submitted',
    submitted_at = now(),
    correct_count = v_correct,
    wrong_count = v_wrong,
    unanswered_count = v_unanswered,
    score_percentage = v_score,
    duration_seconds = GREATEST(
      0,
      extract(epoch FROM (now() - v_attempt.started_at))::integer
    )
  WHERE a.id = p_attempt_id
  RETURNING * INTO v_attempt;

  RETURN jsonb_build_object(
    'attempt_id', v_attempt.id,
    'attempt_number', v_attempt.attempt_number,
    'correct_count', v_attempt.correct_count,
    'wrong_count', v_attempt.wrong_count,
    'unanswered_count', v_attempt.unanswered_count,
    'score_percentage', v_attempt.score_percentage,
    'submitted_at', v_attempt.submitted_at,
    'already_submitted', false
  );
END;
$$;

COMMENT ON FUNCTION public.submit_assigned_quiz_attempt(uuid) IS
  'Studente: invia tentativo. Calcolo is_correct e punteggio solo server-side.';

-- ---------------------------------------------------------------------------
-- RPC: abandon_assigned_quiz_attempt
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.abandon_assigned_quiz_attempt(p_attempt_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid;
  v_attempt public.assigned_quiz_attempts%ROWTYPE;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  SELECT *
  INTO v_attempt
  FROM public.assigned_quiz_attempts a
  WHERE a.id = p_attempt_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'attempt_not_found';
  END IF;

  IF v_attempt.user_id IS DISTINCT FROM v_uid THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  IF v_attempt.status <> 'in_progress' THEN
    RAISE EXCEPTION 'attempt_not_in_progress';
  END IF;

  UPDATE public.assigned_quiz_attempts a
  SET
    status = 'abandoned',
    abandoned_at = now()
  WHERE a.id = p_attempt_id
  RETURNING * INTO v_attempt;

  RETURN jsonb_build_object(
    'attempt_id', v_attempt.id,
    'status', v_attempt.status,
    'abandoned_at', v_attempt.abandoned_at
  );
END;
$$;

COMMENT ON FUNCTION public.abandon_assigned_quiz_attempt(uuid) IS
  'Studente: abbandona tentativo in_progress. Resta conteggiato nel limite.';

-- ---------------------------------------------------------------------------
-- RPC: get_assigned_quiz_attempt_review
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_assigned_quiz_attempt_review(p_attempt_id uuid)
RETURNS SETOF jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid;
  v_attempt public.assigned_quiz_attempts%ROWTYPE;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  SELECT *
  INTO v_attempt
  FROM public.assigned_quiz_attempts a
  WHERE a.id = p_attempt_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'attempt_not_found';
  END IF;

  -- Studente: solo submitted espone correct_option. abandoned/in_progress negati.
  -- Staff: può leggere review di qualsiasi tentativo.
  IF public.is_school_staff() THEN
    NULL;
  ELSIF v_attempt.user_id = v_uid AND v_attempt.status = 'submitted' THEN
    NULL;
  ELSE
    RAISE EXCEPTION 'not_authorized';
  END IF;

  RETURN QUERY
  SELECT jsonb_build_object(
    'position', i.position,
    'prompt', i.prompt,
    'option_a', i.option_a,
    'option_b', i.option_b,
    'option_c', i.option_c,
    'image_path', i.image_path,
    'selected_option', ans.selected_option,
    'correct_option', ans.correct_option,
    'is_correct', ans.is_correct,
    'explanation', i.explanation,
    'lesson_number', i.snapshot_lesson_number
  )
  FROM public.assigned_quiz_attempt_answers ans
  INNER JOIN public.assigned_quiz_items i ON i.id = ans.assignment_item_id
  WHERE ans.attempt_id = p_attempt_id
  ORDER BY i.position;
END;
$$;

COMMENT ON FUNCTION public.get_assigned_quiz_attempt_review(uuid) IS
  'Review: studente solo su submitted (correct_option visibile). abandoned/in_progress negati. Staff legge tutti i tentativi.';

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------
ALTER TABLE public.assigned_quizzes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assigned_quiz_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assigned_quiz_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assigned_quiz_attempt_answers ENABLE ROW LEVEL SECURITY;

-- Staff: RPC-only per creazione; SELECT/UPDATE/DELETE controllati
CREATE POLICY assigned_quizzes_staff_select
  ON public.assigned_quizzes
  FOR SELECT
  USING (public.is_school_staff());

CREATE POLICY assigned_quizzes_staff_update
  ON public.assigned_quizzes
  FOR UPDATE
  USING (public.is_school_staff())
  WITH CHECK (public.is_school_staff());

CREATE POLICY assigned_quizzes_staff_delete
  ON public.assigned_quizzes
  FOR DELETE
  USING (
    public.is_school_staff()
    AND status = 'draft'
    AND NOT EXISTS (
      SELECT 1
      FROM public.assigned_quiz_attempts a
      WHERE a.assignment_id = assigned_quizzes.id
    )
  );

CREATE POLICY assigned_quiz_items_staff_select
  ON public.assigned_quiz_items
  FOR SELECT
  USING (public.is_school_staff());

CREATE POLICY assigned_quiz_attempts_staff_select
  ON public.assigned_quiz_attempts
  FOR SELECT
  USING (public.is_school_staff());

CREATE POLICY assigned_quiz_attempt_answers_staff_select
  ON public.assigned_quiz_attempt_answers
  FOR SELECT
  USING (public.is_school_staff());

-- Studente: solo header e tentativi propri (no items/answers diretti)
CREATE POLICY assigned_quizzes_student_select
  ON public.assigned_quizzes
  FOR SELECT
  USING (
    student_user_id = auth.uid()
    AND status IN ('assigned', 'archived')
  );

CREATE POLICY assigned_quiz_attempts_student_select
  ON public.assigned_quiz_attempts
  FOR SELECT
  USING (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Privilegi tabella: forza RPC per scritture sensibili
-- ---------------------------------------------------------------------------
REVOKE ALL ON TABLE public.assigned_quiz_code_counters FROM PUBLIC;
REVOKE ALL ON TABLE public.assigned_quiz_code_counters FROM authenticated;
REVOKE ALL ON TABLE public.assigned_quizzes FROM PUBLIC;
REVOKE ALL ON TABLE public.assigned_quiz_items FROM PUBLIC;
REVOKE ALL ON TABLE public.assigned_quiz_attempts FROM PUBLIC;
REVOKE ALL ON TABLE public.assigned_quiz_attempt_answers FROM PUBLIC;

GRANT SELECT, UPDATE, DELETE ON TABLE public.assigned_quizzes TO authenticated;
GRANT SELECT ON TABLE public.assigned_quiz_items TO authenticated;
GRANT SELECT ON TABLE public.assigned_quiz_attempts TO authenticated;
GRANT SELECT ON TABLE public.assigned_quiz_attempt_answers TO authenticated;

REVOKE INSERT ON TABLE public.assigned_quizzes FROM authenticated;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.assigned_quiz_items FROM authenticated;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.assigned_quiz_attempts FROM authenticated;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.assigned_quiz_attempt_answers FROM authenticated;

-- ---------------------------------------------------------------------------
-- Grant / revoke RPC
-- ---------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.generate_assigned_quiz_from_errors(
  uuid, text, text, integer, text, integer[], text, text, integer, timestamptz, boolean, boolean, text
) FROM PUBLIC;

REVOKE ALL ON FUNCTION public.start_assigned_quiz_attempt(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_assigned_quiz_attempt_questions(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.save_assigned_quiz_attempt_answer(uuid, uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.submit_assigned_quiz_attempt(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.abandon_assigned_quiz_attempt(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_assigned_quiz_attempt_review(uuid) FROM PUBLIC;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    REVOKE ALL ON TABLE public.assigned_quiz_code_counters FROM anon;
    REVOKE ALL ON FUNCTION public.generate_assigned_quiz_from_errors(
      uuid, text, text, integer, text, integer[], text, text, integer, timestamptz, boolean, boolean, text
    ) FROM anon;
    REVOKE ALL ON FUNCTION public.start_assigned_quiz_attempt(uuid) FROM anon;
    REVOKE ALL ON FUNCTION public.get_assigned_quiz_attempt_questions(uuid) FROM anon;
    REVOKE ALL ON FUNCTION public.save_assigned_quiz_attempt_answer(uuid, uuid, text) FROM anon;
    REVOKE ALL ON FUNCTION public.submit_assigned_quiz_attempt(uuid) FROM anon;
    REVOKE ALL ON FUNCTION public.abandon_assigned_quiz_attempt(uuid) FROM anon;
    REVOKE ALL ON FUNCTION public.get_assigned_quiz_attempt_review(uuid) FROM anon;
  END IF;

  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    GRANT EXECUTE ON FUNCTION public.generate_assigned_quiz_from_errors(
      uuid, text, text, integer, text, integer[], text, text, integer, timestamptz, boolean, boolean, text
    ) TO authenticated;
    GRANT EXECUTE ON FUNCTION public.start_assigned_quiz_attempt(uuid) TO authenticated;
    GRANT EXECUTE ON FUNCTION public.get_assigned_quiz_attempt_questions(uuid) TO authenticated;
    GRANT EXECUTE ON FUNCTION public.save_assigned_quiz_attempt_answer(uuid, uuid, text) TO authenticated;
    GRANT EXECUTE ON FUNCTION public.submit_assigned_quiz_attempt(uuid) TO authenticated;
    GRANT EXECUTE ON FUNCTION public.abandon_assigned_quiz_attempt(uuid) TO authenticated;
    GRANT EXECUTE ON FUNCTION public.get_assigned_quiz_attempt_review(uuid) TO authenticated;
  END IF;
END
$$;
