-- =============================================================================
-- PATCH 5F-ter — public.link_student_app_access (allineato a production)
--
-- Firma: link_student_app_access(p_student_id uuid, p_user_id uuid, p_email text DEFAULT NULL)
-- p_email opzionale: se valorizzato (trim + lower) aggiorna students.email.
--
-- Chiamata da Edge Function create-student-app-access (client service_role).
-- Il client Flutter admin NON deve invocare questa RPC.
--
-- Aggiorna students SOLO: user_id, auth_user_id (solo se la colonna esiste), email.
-- NON aggiorna mai students.updated_at.
--
-- school_user_roles: un solo INSERT quando non esiste ancora alcuna riga per p_user_id;
-- se esiste già ruolo student coerente con p_student_id → no-op; altrimenti eccezione.
--
-- Non tocca payments, Extra, storage documenti.
-- =============================================================================

DROP FUNCTION IF EXISTS public.link_student_app_access(uuid, uuid);

CREATE OR REPLACE FUNCTION public.link_student_app_access(
  p_student_id uuid,
  p_user_id uuid,
  p_email text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_has_auth_user_id boolean;
  v_current_user_id uuid;
  v_email_norm text;
BEGIN
  IF p_student_id IS NULL OR p_user_id IS NULL THEN
    RAISE EXCEPTION
      'link_student_app_access: invalid_arguments (student_id e user_id obbligatori)';
  END IF;

  v_email_norm := nullif(lower(btrim(coalesce(p_email, ''))), '');

  SELECT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'students'
      AND column_name = 'auth_user_id'
  )
  INTO v_has_auth_user_id;

  SELECT s.user_id
  INTO v_current_user_id
  FROM public.students s
  WHERE s.id = p_student_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'link_student_app_access: student_not_found';
  END IF;

  IF v_current_user_id IS NOT NULL AND v_current_user_id IS DISTINCT FROM p_user_id THEN
    RAISE EXCEPTION
      'link_student_app_access: student_already_linked (anagrafica già collegata ad altro account)';
  END IF;

  IF v_has_auth_user_id THEN
    UPDATE public.students
    SET
      user_id = p_user_id,
      auth_user_id = p_user_id,
      email = CASE
        WHEN v_email_norm IS NOT NULL THEN v_email_norm
        ELSE email
      END
    WHERE id = p_student_id;
  ELSE
    UPDATE public.students
    SET
      user_id = p_user_id,
      email = CASE
        WHEN v_email_norm IS NOT NULL THEN v_email_norm
        ELSE email
      END
    WHERE id = p_student_id;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.school_user_roles sur
    WHERE sur.user_id = p_user_id
  ) THEN
    IF EXISTS (
      SELECT 1
      FROM public.school_user_roles sur
      WHERE sur.user_id = p_user_id
        AND sur.role = 'student'
        AND sur.student_id IS NOT DISTINCT FROM p_student_id
    ) THEN
      NULL;
    ELSE
      RAISE EXCEPTION
        'link_student_app_access: auth_user_role_conflict (utente Auth ha già altro ruolo/studente)';
    END IF;
  ELSE
    INSERT INTO public.school_user_roles (user_id, role, student_id, updated_at)
    VALUES (p_user_id, 'student', p_student_id, now());
  END IF;

  RETURN p_student_id;
END;
$$;

COMMENT ON FUNCTION public.link_student_app_access(uuid, uuid, text) IS
  'Collega students.user_id, email, auth_user_id se colonna esiste; mai students.updated_at. '
  'Inserisce school_user_roles solo se assente per user_id. Solo service_role (Edge Function).';

REVOKE ALL ON FUNCTION public.link_student_app_access(uuid, uuid, text) FROM PUBLIC;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    REVOKE ALL ON FUNCTION public.link_student_app_access(uuid, uuid, text) FROM anon;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    REVOKE ALL ON FUNCTION public.link_student_app_access(uuid, uuid, text) FROM authenticated;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
    GRANT EXECUTE ON FUNCTION public.link_student_app_access(uuid, uuid, text) TO service_role;
  END IF;
END
$$;
