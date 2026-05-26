-- =============================================================================
-- Registrazione studente da app (Supabase Auth + profilo students + school_user_roles)
-- =============================================================================
-- Inserimento atomico via SECURITY DEFINER per evitare stati parziali quando
-- le policy RLS non consentono INSERT diretti all’app.
-- Il client chiama questa funzione dopo auth.signUp / con sessione JWT valida.
-- =============================================================================

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
    registration_status
  )
  VALUES (
    v_uid,
    trim(p_first_name),
    trim(p_last_name),
    nullif(trim(p_phone), ''),
    lower(trim(p_email)),
    p_enrolled_course_path,
    p_enrolled_license_category,
    'pending'
  )
  RETURNING id INTO v_id;

  INSERT INTO public.school_user_roles (user_id, role, student_id)
  VALUES (v_uid, 'student', v_id);

  RETURN v_id;
END;
$$;

COMMENT ON FUNCTION public.register_student_app IS
  'Chiamata dall’app dopo signUp: crea riga students + school_user_roles in una transazione.';

REVOKE ALL ON FUNCTION public.register_student_app FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.register_student_app TO authenticated;
