-- GO-LIVE.FIX1C — Restore canonical student-centric exam_attempts.
-- Replaces remote enrollment-centric drift (0 rows) with foundation/Flutter contract.
-- Does NOT touch public.enrollments or payments.enrollment_id.

DROP TABLE IF EXISTS public.exam_attempts;

CREATE TABLE public.exam_attempts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id uuid NOT NULL REFERENCES public.students (id) ON DELETE CASCADE,
  exam_type text NOT NULL CHECK (exam_type IN ('theory', 'practical')),
  attempt_number integer NOT NULL,
  result text NOT NULL
    CHECK (result IN (
      'pending', 'scheduled', 'passed', 'failed', 'exempt', 'noShow'
    )),
  exam_date date,
  score_or_label text,
  external_session_id text,
  notes text,
  recorded_by_staff_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT exam_attempt_uq UNIQUE (student_id, exam_type, attempt_number)
);

CREATE INDEX idx_exam_attempts_student ON public.exam_attempts (student_id);

ALTER TABLE public.exam_attempts ENABLE ROW LEVEL SECURITY;

CREATE POLICY exam_attempts_select ON public.exam_attempts
  FOR SELECT USING (
    public.is_own_student(student_id) OR public.is_school_staff()
  );

CREATE POLICY exam_attempts_staff_all ON public.exam_attempts
  FOR ALL USING (public.is_school_staff())
  WITH CHECK (public.is_school_staff());

-- PostgREST table privileges (security enforced by RLS), same pattern as practice_dossiers.
GRANT SELECT, INSERT, UPDATE, DELETE, REFERENCES, TRIGGER, TRUNCATE
  ON TABLE public.exam_attempts TO anon, authenticated, service_role;
