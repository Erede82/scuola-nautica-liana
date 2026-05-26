-- =============================================================================
-- Onboarding operativo segreteria (stato accettazione / contatti / documenti)
-- =============================================================================

ALTER TABLE public.students
  ADD COLUMN IF NOT EXISTS onboarding_status text;

ALTER TABLE public.students
  ADD COLUMN IF NOT EXISTS first_contacted_at timestamptz;

ALTER TABLE public.students
  ADD COLUMN IF NOT EXISTS onboarding_notes text;

COMMENT ON COLUMN public.students.onboarding_status IS
  'Flusso operativo segreteria (indipendente da registration_status legale).';

-- Backfill prima del NOT NULL
UPDATE public.students
SET onboarding_status = CASE registration_status
  WHEN 'active' THEN 'active_course'
  WHEN 'completed' THEN 'completed'
  WHEN 'suspended' THEN 'suspended'
  WHEN 'withdrawn' THEN 'completed'
  WHEN 'pending' THEN 'pending_review'
  ELSE 'approved'
END
WHERE onboarding_status IS NULL;

ALTER TABLE public.students
  DROP CONSTRAINT IF EXISTS students_onboarding_status_check;

ALTER TABLE public.students
  ADD CONSTRAINT students_onboarding_status_check
  CHECK (onboarding_status IN (
    'pending_review',
    'awaiting_contact',
    'awaiting_documents',
    'approved',
    'active_course',
    'suspended',
    'completed'
  ));

ALTER TABLE public.students
  ALTER COLUMN onboarding_status SET NOT NULL;

ALTER TABLE public.students
  ALTER COLUMN onboarding_status SET DEFAULT 'pending_review';

-- Eventi audit: onboarding
ALTER TABLE public.backoffice_activity_events
  DROP CONSTRAINT IF EXISTS backoffice_activity_events_event_type_check;

ALTER TABLE public.backoffice_activity_events
  ADD CONSTRAINT backoffice_activity_events_event_type_check
  CHECK (event_type IN (
    'paymentAdded',
    'guidanceAppointmentAdded',
    'examResultRecorded',
    'internalNoteAdded',
    'practiceDossierUpdated',
    'studyAccessChanged',
    'profileInternalNoteUpdated',
    'onboardingStatusChanged',
    'studentRegisteredFromApp'
  ));

-- Registrazione app: imposta onboarding "da revisionare"
CREATE OR REPLACE FUNCTION public.register_student_app(
  p_first_name text,
  p_last_name text,
  p_phone text,
  p_email text,
  p_enrolled_course_path text,
  p_enrolled_license_category text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid;
  v_id uuid;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  IF EXISTS (SELECT 1 FROM public.students WHERE auth_user_id = v_uid) THEN
    RAISE EXCEPTION 'student_already_registered';
  END IF;

  IF p_enrolled_course_path IS NULL OR p_enrolled_course_path NOT IN (
    'entro_12_miglia', 'd1', 'entro_12_miglia_vela'
  ) THEN
    RAISE EXCEPTION 'invalid_enrolled_course_path';
  END IF;

  IF p_enrolled_license_category IS NULL OR p_enrolled_license_category NOT IN (
    'motore', 'vela', 'd1'
  ) THEN
    RAISE EXCEPTION 'invalid_enrolled_license_category';
  END IF;

  INSERT INTO public.students (
    auth_user_id,
    first_name,
    last_name,
    phone,
    email,
    enrolled_course_path,
    enrolled_license_category,
    registration_status,
    onboarding_status
  )
  VALUES (
    v_uid,
    trim(p_first_name),
    trim(p_last_name),
    nullif(trim(p_phone), ''),
    lower(trim(p_email)),
    p_enrolled_course_path,
    p_enrolled_license_category,
    'pending',
    'pending_review'
  )
  RETURNING id INTO v_id;

  INSERT INTO public.school_user_roles (user_id, role, student_id)
  VALUES (v_uid, 'student', v_id);

  RETURN v_id;
END;
$$;
