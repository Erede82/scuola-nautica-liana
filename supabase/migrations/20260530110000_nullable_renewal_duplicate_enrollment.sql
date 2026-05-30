-- Renewal and duplicate practices are administrative records and do not carry
-- an app study enrollment path. Keep app self-registration validation in RPCs;
-- this only lets backoffice-created renewal/duplicate rows store NULL.

ALTER TABLE public.students
  ALTER COLUMN enrolled_course_path DROP DEFAULT,
  ALTER COLUMN enrolled_course_path DROP NOT NULL,
  ALTER COLUMN enrolled_license_category DROP DEFAULT,
  ALTER COLUMN enrolled_license_category DROP NOT NULL;

ALTER TABLE public.students
  DROP CONSTRAINT IF EXISTS students_enrolled_course_path_check;

ALTER TABLE public.students
  ADD CONSTRAINT students_enrolled_course_path_check
  CHECK (
    enrolled_course_path IS NULL
    OR enrolled_course_path IN ('entro_12_miglia', 'd1', 'entro_12_miglia_vela')
  );

ALTER TABLE public.students
  DROP CONSTRAINT IF EXISTS students_enrolled_license_category_check;

ALTER TABLE public.students
  ADD CONSTRAINT students_enrolled_license_category_check
  CHECK (
    enrolled_license_category IS NULL
    OR enrolled_license_category IN ('motore', 'vela', 'd1')
  );

UPDATE public.students s
SET
  enrolled_course_path = NULL,
  enrolled_license_category = NULL
FROM public.practice_dossiers d
WHERE d.student_id = s.id
  AND d.practice_type IN ('renewal', 'duplicate');
