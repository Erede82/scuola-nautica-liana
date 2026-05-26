-- =============================================================================
-- register_student_app — script completo per Supabase SQL Editor
-- Stato RPC/RLS aggiornato: 20260329100000_profiles_rls_students_user_id_register_student.sql
-- =============================================================================
-- Obiettivo: risolvere
--   "Could not find the function public.register_student_app(...) in the schema cache"
--
-- Prerequisiti: esistano `public.students` (con PK `id uuid`) e `auth.users`.
-- Dopo l’esecuzione: Dashboard → Settings → API → "Reload schema" (se necessario).
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ---------------------------------------------------------------------------
-- school_user_roles (se mancante)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.school_user_roles (
  user_id uuid PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
  role text NOT NULL
    CHECK (role IN ('student', 'school_admin', 'staff', 'instructor')),
  student_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'school_user_roles_student_fk'
  ) THEN
    ALTER TABLE public.school_user_roles
      ADD CONSTRAINT school_user_roles_student_fk
      FOREIGN KEY (student_id) REFERENCES public.students (id) ON DELETE SET NULL;
  END IF;
END
$$;

-- ---------------------------------------------------------------------------
-- Colonne su public.students richieste dall’INSERT della RPC (idempotente)
-- ---------------------------------------------------------------------------
ALTER TABLE public.students ADD COLUMN IF NOT EXISTS auth_user_id uuid;
ALTER TABLE public.students ADD COLUMN IF NOT EXISTS first_name text;
ALTER TABLE public.students ADD COLUMN IF NOT EXISTS last_name text;
ALTER TABLE public.students ADD COLUMN IF NOT EXISTS phone text;
ALTER TABLE public.students ADD COLUMN IF NOT EXISTS email text;
ALTER TABLE public.students ADD COLUMN IF NOT EXISTS enrolled_course_path text;
ALTER TABLE public.students ADD COLUMN IF NOT EXISTS enrolled_license_category text;
ALTER TABLE public.students ADD COLUMN IF NOT EXISTS registration_status text;
ALTER TABLE public.students ADD COLUMN IF NOT EXISTS onboarding_status text;
ALTER TABLE public.students ADD COLUMN IF NOT EXISTS first_contacted_at timestamptz;
ALTER TABLE public.students ADD COLUMN IF NOT EXISTS onboarding_notes text;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'students_auth_user_id_fkey'
  ) THEN
    ALTER TABLE public.students
      ADD CONSTRAINT students_auth_user_id_fkey
      FOREIGN KEY (auth_user_id) REFERENCES auth.users (id) ON DELETE SET NULL;
  END IF;
END
$$;

UPDATE public.students
SET onboarding_status = CASE registration_status
  WHEN 'active' THEN 'active_course'
  WHEN 'completed' THEN 'completed'
  WHEN 'suspended' THEN 'suspended'
  WHEN 'withdrawn' THEN 'completed'
  WHEN 'pending' THEN 'pending_review'
  ELSE COALESCE(onboarding_status, 'pending_review')
END
WHERE onboarding_status IS NULL;

ALTER TABLE public.students
  ALTER COLUMN onboarding_status SET DEFAULT 'pending_review';

-- ---------------------------------------------------------------------------
-- RPC: registrazione da app (dopo Supabase Auth signUp con sessione JWT)
-- Parametri (nomi esatti per client Flutter / PostgREST):
--   p_first_name, p_last_name, p_phone, p_email,
--   p_enrolled_course_path, p_enrolled_license_category
-- ---------------------------------------------------------------------------
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

  IF EXISTS (
    SELECT 1 FROM public.students WHERE auth_user_id = v_uid
  ) THEN
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

COMMENT ON FUNCTION public.register_student_app(
  text, text, text, text, text, text
) IS
  'Chiamata dall’app dopo signUp: crea riga students + school_user_roles (SECURITY DEFINER).';

REVOKE ALL ON FUNCTION public.register_student_app(
  text, text, text, text, text, text
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.register_student_app(
  text, text, text, text, text, text
) TO authenticated;

-- =============================================================================
-- Fine script
-- =============================================================================
