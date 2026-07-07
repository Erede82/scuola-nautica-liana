-- =============================================================================
-- P9C.3-B — Fondazione salvataggio tentativi schede lezione (schema only)
-- =============================================================================
-- Prepara quiz_sets / quiz_results / quiz_attempt_answers per:
--   - identificazione stabile scheda (license_category + lesson + sheet)
--   - metadati tentativo (started/completed/duration/unanswered)
--   - risposte non date (selected_option NULL)
--
-- NON eseguire automaticamente: applicare solo dopo approvazione esplicita.
-- Idempotente: ADD COLUMN IF NOT EXISTS, indici/constraints con IF NOT EXISTS.
-- Non tocca Contabilità, Stripe, payments, record_payment,
-- student_financial_summaries.

-- ---------------------------------------------------------------------------
-- quiz_sets — chiavi scheda lezione
-- ---------------------------------------------------------------------------
ALTER TABLE public.quiz_sets
  ADD COLUMN IF NOT EXISTS license_category text,
  ADD COLUMN IF NOT EXISTS sheet_number integer;

COMMENT ON COLUMN public.quiz_sets.license_category IS
  'Categoria patente DB (es. A12, D1). Allineata a questions.license_category.';

COMMENT ON COLUMN public.quiz_sets.sheet_number IS
  'Numero scheda 1..N nella lezione (catalogo LicenseCatalog).';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'quiz_sets_sheet_number_positive_chk'
      AND conrelid = 'public.quiz_sets'::regclass
  ) THEN
    ALTER TABLE public.quiz_sets
      ADD CONSTRAINT quiz_sets_sheet_number_positive_chk
      CHECK (sheet_number IS NULL OR sheet_number >= 1);
  END IF;
END $$;

-- Unicità scheda lezione: stesso kind + categoria + lezione + numero scheda.
CREATE UNIQUE INDEX IF NOT EXISTS quiz_sets_lesson_sheet_uq
  ON public.quiz_sets (kind, license_category, lesson_number, sheet_number)
  WHERE kind = 'lesson'
    AND license_category IS NOT NULL
    AND lesson_number IS NOT NULL
    AND sheet_number IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_quiz_sets_lesson_sheet_lookup
  ON public.quiz_sets (license_category, lesson_number, sheet_number)
  WHERE kind = 'lesson';

-- ---------------------------------------------------------------------------
-- quiz_set_items — unicità (quiz_set_id, question_id) per seed ON CONFLICT
-- ---------------------------------------------------------------------------
-- P9C.3-A: il remoto ha già PK (quiz_set_id, question_id). Evitiamo un secondo
-- indice unique ridondante; lo creiamo solo se manca PK/UNIQUE equivalente.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint c
    WHERE c.conrelid = 'public.quiz_set_items'::regclass
      AND c.contype IN ('p', 'u')
      AND (
        SELECT array_agg(a.attname ORDER BY u.n)
        FROM unnest(c.conkey) WITH ORDINALITY AS u(attnum, n)
        JOIN pg_attribute a
          ON a.attrelid = c.conrelid AND a.attnum = u.attnum
      ) = ARRAY['quiz_set_id', 'question_id']::name[]
  ) THEN
    CREATE UNIQUE INDEX IF NOT EXISTS quiz_set_items_set_question_uq
      ON public.quiz_set_items (quiz_set_id, question_id);
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- quiz_results — metadati tentativo
-- ---------------------------------------------------------------------------
ALTER TABLE public.quiz_results
  ADD COLUMN IF NOT EXISTS started_at timestamptz,
  ADD COLUMN IF NOT EXISTS completed_at timestamptz,
  ADD COLUMN IF NOT EXISTS duration_seconds integer,
  ADD COLUMN IF NOT EXISTS unanswered_count integer NOT NULL DEFAULT 0;

COMMENT ON COLUMN public.quiz_results.started_at IS
  'Inizio tentativo lato client (opzionale).';

COMMENT ON COLUMN public.quiz_results.completed_at IS
  'Fine tentativo; se NULL si può usare created_at come fallback.';

COMMENT ON COLUMN public.quiz_results.duration_seconds IS
  'Durata totale tentativo in secondi (opzionale).';

COMMENT ON COLUMN public.quiz_results.unanswered_count IS
  'Domande lasciate senza risposta nel tentativo.';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'quiz_results_unanswered_count_non_negative_chk'
      AND conrelid = 'public.quiz_results'::regclass
  ) THEN
    ALTER TABLE public.quiz_results
      ADD CONSTRAINT quiz_results_unanswered_count_non_negative_chk
      CHECK (unanswered_count >= 0);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'quiz_results_duration_seconds_non_negative_chk'
      AND conrelid = 'public.quiz_results'::regclass
  ) THEN
    ALTER TABLE public.quiz_results
      ADD CONSTRAINT quiz_results_duration_seconds_non_negative_chk
      CHECK (duration_seconds IS NULL OR duration_seconds >= 0);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_quiz_results_quiz_set_id
  ON public.quiz_results (quiz_set_id);

CREATE INDEX IF NOT EXISTS idx_quiz_results_user_quiz_set
  ON public.quiz_results (user_id, quiz_set_id, created_at DESC);

-- ---------------------------------------------------------------------------
-- quiz_attempt_answers — risposte non date + snapshot corretta
-- ---------------------------------------------------------------------------
ALTER TABLE public.quiz_attempt_answers
  ALTER COLUMN selected_option DROP NOT NULL;

ALTER TABLE public.quiz_attempt_answers
  ADD COLUMN IF NOT EXISTS correct_option character(1);

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'quiz_attempt_answers_selected_option_check'
      AND conrelid = 'public.quiz_attempt_answers'::regclass
  ) THEN
    ALTER TABLE public.quiz_attempt_answers
      DROP CONSTRAINT quiz_attempt_answers_selected_option_check;
  END IF;
END $$;

ALTER TABLE public.quiz_attempt_answers
  ADD CONSTRAINT quiz_attempt_answers_selected_option_check
  CHECK (
    selected_option IS NULL
    OR selected_option = ANY (ARRAY['A'::bpchar, 'B'::bpchar, 'C'::bpchar])
  );

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'quiz_attempt_answers_correct_option_check'
      AND conrelid = 'public.quiz_attempt_answers'::regclass
  ) THEN
    ALTER TABLE public.quiz_attempt_answers
      ADD CONSTRAINT quiz_attempt_answers_correct_option_check
      CHECK (
        correct_option IS NULL
        OR correct_option = ANY (ARRAY['A'::bpchar, 'B'::bpchar, 'C'::bpchar])
      );
  END IF;
END $$;

COMMENT ON COLUMN public.quiz_attempt_answers.selected_option IS
  'Risposta scelta; NULL = domanda non risposta.';

COMMENT ON COLUMN public.quiz_attempt_answers.correct_option IS
  'Snapshot opzione corretta al momento del tentativo (storico).';

CREATE UNIQUE INDEX IF NOT EXISTS quiz_attempt_answers_result_question_uq
  ON public.quiz_attempt_answers (quiz_result_id, question_id);

CREATE INDEX IF NOT EXISTS idx_quiz_attempt_answers_quiz_result_id
  ON public.quiz_attempt_answers (quiz_result_id);
