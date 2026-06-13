-- Ripristino idempotente tabelle Accessi studio (G1A).
--
-- Contesto: le migration 20260320000000 / 20260325120000 risultano già applicate
-- su remoto, ma le tabelle lesson_quiz_sheet_unlocks, exam_quiz_access e
-- error_review_topic_assignments risultano assenti (to_regclass = NULL).
-- Questa migration ricrea solo quelle tre tabelle, indici, RLS, policy e trigger
-- coerenti con backoffice_foundation, senza toccare altre entità.

-- ---------------------------------------------------------------------------
-- lesson_quiz_sheet_unlocks
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.lesson_quiz_sheet_unlocks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id uuid NOT NULL REFERENCES public.students (id) ON DELETE CASCADE,
  license_category text NOT NULL
    CHECK (license_category IN ('motore', 'vela', 'd1')),
  lesson_number integer NOT NULL,
  sheet_number integer NOT NULL,
  unlocked boolean NOT NULL DEFAULT false,
  unlocked_at timestamptz,
  unlocked_by_staff_id uuid,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT lesson_sheet_unlock_uq UNIQUE (student_id, license_category, lesson_number, sheet_number)
);

CREATE INDEX IF NOT EXISTS idx_sheet_unlocks_student
  ON public.lesson_quiz_sheet_unlocks (student_id);

-- ---------------------------------------------------------------------------
-- exam_quiz_access
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.exam_quiz_access (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id uuid NOT NULL REFERENCES public.students (id) ON DELETE CASCADE,
  license_category text NOT NULL
    CHECK (license_category IN ('motore', 'vela', 'd1')),
  exam_unlocked boolean NOT NULL DEFAULT false,
  updated_at timestamptz,
  updated_by_staff_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT exam_quiz_access_uq UNIQUE (student_id, license_category)
);

CREATE INDEX IF NOT EXISTS idx_exam_quiz_access_student
  ON public.exam_quiz_access (student_id);

-- ---------------------------------------------------------------------------
-- error_review_topic_assignments
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.error_review_topic_assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id uuid NOT NULL REFERENCES public.students (id) ON DELETE CASCADE,
  license_category text NOT NULL
    CHECK (license_category IN ('motore', 'vela', 'd1')),
  lesson_number integer NOT NULL,
  topic_unlocked boolean NOT NULL DEFAULT false,
  didactic_note text,
  updated_at timestamptz,
  updated_by_staff_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT error_review_uq UNIQUE (student_id, license_category, lesson_number)
);

CREATE INDEX IF NOT EXISTS idx_error_review_student
  ON public.error_review_topic_assignments (student_id);

-- ---------------------------------------------------------------------------
-- Trigger updated_at (solo lesson_quiz_sheet_unlocks, come foundation)
-- ---------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_lesson_quiz_sheet_unlocks_updated ON public.lesson_quiz_sheet_unlocks;
CREATE TRIGGER trg_lesson_quiz_sheet_unlocks_updated
  BEFORE UPDATE ON public.lesson_quiz_sheet_unlocks
  FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
ALTER TABLE public.lesson_quiz_sheet_unlocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exam_quiz_access ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.error_review_topic_assignments ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'lesson_quiz_sheet_unlocks'
      AND policyname = 'study_unlocks_select'
  ) THEN
    CREATE POLICY study_unlocks_select ON public.lesson_quiz_sheet_unlocks
      FOR SELECT USING (public.is_own_student(student_id) OR public.is_school_staff());
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'lesson_quiz_sheet_unlocks'
      AND policyname = 'study_unlocks_staff_all'
  ) THEN
    CREATE POLICY study_unlocks_staff_all ON public.lesson_quiz_sheet_unlocks
      FOR ALL USING (public.is_school_staff()) WITH CHECK (public.is_school_staff());
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'exam_quiz_access'
      AND policyname = 'exam_access_select'
  ) THEN
    CREATE POLICY exam_access_select ON public.exam_quiz_access
      FOR SELECT USING (public.is_own_student(student_id) OR public.is_school_staff());
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'exam_quiz_access'
      AND policyname = 'exam_access_staff_all'
  ) THEN
    CREATE POLICY exam_access_staff_all ON public.exam_quiz_access
      FOR ALL USING (public.is_school_staff()) WITH CHECK (public.is_school_staff());
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'error_review_topic_assignments'
      AND policyname = 'error_review_select'
  ) THEN
    CREATE POLICY error_review_select ON public.error_review_topic_assignments
      FOR SELECT USING (public.is_own_student(student_id) OR public.is_school_staff());
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'error_review_topic_assignments'
      AND policyname = 'error_review_staff_all'
  ) THEN
    CREATE POLICY error_review_staff_all ON public.error_review_topic_assignments
      FOR ALL USING (public.is_school_staff()) WITH CHECK (public.is_school_staff());
  END IF;
END $$;
