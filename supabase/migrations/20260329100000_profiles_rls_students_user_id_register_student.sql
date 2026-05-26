-- =============================================================================
-- Allineamento a produzione: students.user_id, RLS senza ricorsione su profiles,
-- register_student_app su user_id.
--
-- public.profiles: lo schema NON è versionato in questo repo. Template tipico
-- Supabase = PK `id uuid REFERENCES auth.users(id)` → legame = `id`.
-- Alcuni progetti usano `user_id uuid` verso auth.users. La sezione §3 costruisce
-- dinamicamente l’espressione “riga propria” con `id` e/o `user_id` se esistono.
--
-- Policy esistenti: §3 e §4 eliminano TUTTE le policy su profiles/students tramite
-- pg_policies (nomi produzione irrilevanti).
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1) students.user_id: colonna, backfill, vincoli
-- ---------------------------------------------------------------------------
ALTER TABLE public.students ADD COLUMN IF NOT EXISTS user_id uuid;

UPDATE public.students
SET user_id = auth_user_id
WHERE user_id IS NULL AND auth_user_id IS NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'students_user_id_key'
  ) THEN
    ALTER TABLE public.students
      ADD CONSTRAINT students_user_id_key UNIQUE (user_id);
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'students_user_id_fkey'
  ) THEN
    ALTER TABLE public.students
      ADD CONSTRAINT students_user_id_fkey
      FOREIGN KEY (user_id) REFERENCES auth.users (id) ON DELETE SET NULL;
  END IF;
END
$$;

CREATE INDEX IF NOT EXISTS idx_students_user_id ON public.students (user_id);

-- Allinea legacy: se esiste ancora auth_user_id, copia da user_id
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'students'
      AND column_name = 'auth_user_id'
  ) THEN
    UPDATE public.students
    SET auth_user_id = user_id
    WHERE auth_user_id IS NULL AND user_id IS NOT NULL;
  END IF;
END
$$;

-- ---------------------------------------------------------------------------
-- 2) is_own_student: solo school_user_roles + students.user_id (no profiles)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_own_student(target_student_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.school_user_roles sur
    WHERE sur.user_id = auth.uid()
      AND sur.role = 'student'
      AND sur.student_id = target_student_id
  )
  OR EXISTS (
    SELECT 1
    FROM public.students s
    WHERE s.id = target_student_id
      AND s.user_id = auth.uid()
  );
$$;

COMMENT ON FUNCTION public.is_own_student(uuid) IS
  'Allievo: school_user_roles.student_id o students.user_id = auth.uid(). Nessun join a profiles.';

-- ---------------------------------------------------------------------------
-- 3) public.profiles — drop di tutte le policy, ricrea senza ricorsione
--     “Riga propria”: (id = auth.uid()) e/o (user_id = auth.uid()) secondo colonne presenti.
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  pol record;
  has_id boolean;
  has_user_id boolean;
  own_expr text;
BEGIN
  IF to_regclass('public.profiles') IS NULL THEN
    RETURN;
  END IF;

  SELECT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'profiles'
      AND column_name = 'id'
  ) INTO has_id;

  SELECT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'profiles'
      AND column_name = 'user_id'
  ) INTO has_user_id;

  IF has_id AND has_user_id THEN
    own_expr := '(id = auth.uid() OR user_id = auth.uid())';
  ELSIF has_id THEN
    own_expr := '(id = auth.uid())';
  ELSIF has_user_id THEN
    own_expr := '(user_id = auth.uid())';
  ELSE
    RAISE EXCEPTION
      'public.profiles: servono colonne id e/o user_id (FK verso auth.users) per RLS';
  END IF;

  FOR pol IN
    SELECT policyname
    FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'profiles'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.profiles', pol.policyname);
  END LOOP;

  ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

  EXECUTE format(
    $f$
    CREATE POLICY profiles_select_school_roles ON public.profiles
    FOR SELECT
    USING (%s OR public.is_school_staff());
    $f$,
    own_expr
  );

  EXECUTE format(
    $f$
    CREATE POLICY profiles_insert_school_roles ON public.profiles
    FOR INSERT
    WITH CHECK (%s OR public.is_school_staff());
    $f$,
    own_expr
  );

  EXECUTE format(
    $f$
    CREATE POLICY profiles_update_school_roles ON public.profiles
    FOR UPDATE
    USING (%s OR public.is_school_staff())
    WITH CHECK (%s OR public.is_school_staff());
    $f$,
    own_expr,
    own_expr
  );

  EXECUTE $p$
    CREATE POLICY profiles_delete_staff_only ON public.profiles
    FOR DELETE
    USING (public.is_school_staff());
  $p$;
END
$$;

-- ---------------------------------------------------------------------------
-- 4) public.students — drop di tutte le policy (nomi prod variabili), poi ricrea
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  pol record;
BEGIN
  FOR pol IN
    SELECT policyname
    FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'students'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.students', pol.policyname);
  END LOOP;
END
$$;

CREATE POLICY students_select_policy ON public.students
  FOR SELECT USING (public.is_own_student(id) OR public.is_school_staff());

CREATE POLICY students_modify_staff ON public.students
  FOR ALL USING (public.is_school_staff()) WITH CHECK (public.is_school_staff());

-- ---------------------------------------------------------------------------
-- 5) register_student_app — user_id canonico; mirror auth_user_id se colonna presente
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
  v_has_auth_user_id boolean;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  SELECT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'students'
      AND column_name = 'auth_user_id'
  ) INTO v_has_auth_user_id;

  IF EXISTS (SELECT 1 FROM public.students WHERE user_id = v_uid) THEN
    RAISE EXCEPTION 'student_already_registered';
  END IF;

  IF v_has_auth_user_id AND EXISTS (
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

  IF v_has_auth_user_id THEN
    INSERT INTO public.students (
      user_id,
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
  ELSE
    INSERT INTO public.students (
      user_id,
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
  END IF;

  INSERT INTO public.school_user_roles (user_id, role, student_id)
  VALUES (v_uid, 'student', v_id);

  RETURN v_id;
END;
$$;

COMMENT ON FUNCTION public.register_student_app(
  text, text, text, text, text, text
) IS
  'Registrazione app: students.user_id + school_user_roles; auth_user_id solo se colonna esiste.';

REVOKE ALL ON FUNCTION public.register_student_app(
  text, text, text, text, text, text
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.register_student_app(
  text, text, text, text, text, text
) TO authenticated;
