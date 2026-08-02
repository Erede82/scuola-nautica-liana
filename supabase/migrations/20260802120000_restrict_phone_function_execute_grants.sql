-- PHONE-INTL.4-C
-- Restringe EXECUTE sulle RPC telefoniche e sull'helper di normalizzazione.
-- Non modifica corpi, firme, RLS, policy, colonne, dati o constraint.

-- ---------------------------------------------------------------------------
-- register_student_app (legacy)
-- ---------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.register_student_app(
  text, text, text, text, text, text
) FROM PUBLIC;

REVOKE ALL ON FUNCTION public.register_student_app(
  text, text, text, text, text, text
) FROM anon;

GRANT EXECUTE ON FUNCTION public.register_student_app(
  text, text, text, text, text, text
) TO authenticated;

GRANT EXECUTE ON FUNCTION public.register_student_app(
  text, text, text, text, text, text
) TO service_role;

-- ---------------------------------------------------------------------------
-- register_student_app_e164
-- ---------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.register_student_app_e164(
  text, text, text, text, text, text, text
) FROM PUBLIC;

REVOKE ALL ON FUNCTION public.register_student_app_e164(
  text, text, text, text, text, text, text
) FROM anon;

GRANT EXECUTE ON FUNCTION public.register_student_app_e164(
  text, text, text, text, text, text, text
) TO authenticated;

GRANT EXECUTE ON FUNCTION public.register_student_app_e164(
  text, text, text, text, text, text, text
) TO service_role;

-- ---------------------------------------------------------------------------
-- normalize_student_phone_input (helper interno)
-- Le RPC SECURITY DEFINER (owner postgres) continuano a poterlo richiamare.
-- service_role mantiene EXECUTE se già presente (diagnostica/admin).
-- ---------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.normalize_student_phone_input(text)
  FROM PUBLIC;

REVOKE ALL ON FUNCTION public.normalize_student_phone_input(text)
  FROM anon;

REVOKE ALL ON FUNCTION public.normalize_student_phone_input(text)
  FROM authenticated;
