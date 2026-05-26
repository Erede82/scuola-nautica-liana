-- =============================================================================
-- Percorso iscrizione vs categoria catalogo legacy (students)
-- =============================================================================
-- Aggiunge students.enrolled_course_path (snake_case, allineato a
-- EnrollmentCoursePathStorage nel client Flutter).
-- Mantiene enrolled_license_category per compatibilità con unlock / quiz che
-- usano ancora license_category (motore, vela, d1).
-- =============================================================================

ALTER TABLE public.students
  ADD COLUMN IF NOT EXISTS enrolled_course_path text;

ALTER TABLE public.students
  DROP CONSTRAINT IF EXISTS students_enrolled_course_path_check;

ALTER TABLE public.students
  ADD CONSTRAINT students_enrolled_course_path_check
  CHECK (
    enrolled_course_path IS NULL
    OR enrolled_course_path IN ('entro_12_miglia', 'd1', 'entro_12_miglia_vela')
  );

COMMENT ON COLUMN public.students.enrolled_course_path IS
  'Percorso scelto in iscrizione: entro_12_miglia | d1 | entro_12_miglia_vela. I moduli app si derivano lato client.';

-- Backfill da colonna legacy (singola categoria catalogo).
UPDATE public.students
SET enrolled_course_path = CASE enrolled_license_category
  WHEN 'motore' THEN 'entro_12_miglia'
  WHEN 'd1' THEN 'd1'
  WHEN 'vela' THEN 'entro_12_miglia_vela'
  ELSE 'entro_12_miglia'
END
WHERE enrolled_course_path IS NULL;

ALTER TABLE public.students
  ALTER COLUMN enrolled_course_path SET NOT NULL;

ALTER TABLE public.students
  ALTER COLUMN enrolled_course_path SET DEFAULT 'entro_12_miglia';

-- Vincolo finale: solo valori percorso (niente NULL dopo backfill).
ALTER TABLE public.students
  DROP CONSTRAINT IF EXISTS students_enrolled_course_path_check;

ALTER TABLE public.students
  ADD CONSTRAINT students_enrolled_course_path_check
  CHECK (
    enrolled_course_path IN ('entro_12_miglia', 'd1', 'entro_12_miglia_vela')
  );
