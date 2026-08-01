-- =============================================================================
-- PHONE-INTL.2-DB — Contratto students.phone E.164 + phone_country_iso2
-- =============================================================================
-- Contratto:
--   students.phone              → numero canonico E.164 (+ seguito da 8–15 cifre)
--   students.phone_country_iso2 → ISO 3166-1 alpha-2 maiuscolo (nullable)
--
-- Conversione automatica SOLO cellulari italiani inequivocabili (10 cifre, inizio 3).
-- Valori ambigui NON convertiti. Constraint E.164 aggiunto come NOT VALID.
-- VALIDATE CONSTRAINT rinviata finché restano righe non conformi.
--
-- Non tocca: online_orders.buyer_phone, UNIQUE su phone, Flutter, Contabilità, Stripe.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1) Colonna paese
-- ---------------------------------------------------------------------------
ALTER TABLE public.students
  ADD COLUMN IF NOT EXISTS phone_country_iso2 text;

COMMENT ON COLUMN public.students.phone IS
  'Telefono allievo in formato E.164 canonico (es. +393331234567). NULL se assente.';

COMMENT ON COLUMN public.students.phone_country_iso2 IS
  'Codice ISO 3166-1 alpha-2 maiuscolo del paese del telefono (es. IT). Nullable; non inventato per E.164 stranieri.';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'students_phone_country_iso2_chk'
      AND conrelid = 'public.students'::regclass
  ) THEN
    ALTER TABLE public.students
      ADD CONSTRAINT students_phone_country_iso2_chk
      CHECK (
        phone_country_iso2 IS NULL
        OR phone_country_iso2 ~ '^[A-Z]{2}$'
      );
  END IF;
END
$$;

-- ---------------------------------------------------------------------------
-- 2) Helper: classifica / normalizza telefono (uso interno migration + RPC)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.normalize_student_phone_input(p_raw text)
RETURNS TABLE (
  phone_e164 text,
  phone_country_iso2 text,
  status text
)
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_raw text;
  v_compact text;
  v_digits text;
BEGIN
  v_raw := nullif(btrim(coalesce(p_raw, '')), '');
  IF v_raw IS NULL THEN
    phone_e164 := NULL;
    phone_country_iso2 := NULL;
    status := 'null_or_blank';
    RETURN NEXT;
    RETURN;
  END IF;

  -- Rimuove separatori ammessi; conserva eventuale + iniziale.
  v_compact := regexp_replace(v_raw, '[\s().-]', '', 'g');
  v_digits := regexp_replace(v_compact, '\D', '', 'g');

  -- Cellulare IT nazionale: 10 cifre, inizia con 3.
  IF v_compact ~ '^3[0-9]{9}$' THEN
    phone_e164 := '+39' || v_compact;
    phone_country_iso2 := 'IT';
    status := 'converted_it_national';
    RETURN NEXT;
    RETURN;
  END IF;

  -- 39 + 10 cifre cellulare (senza +).
  IF v_compact ~ '^393[0-9]{9}$' THEN
    phone_e164 := '+' || v_compact;
    phone_country_iso2 := 'IT';
    status := 'converted_it_39_prefix';
    RETURN NEXT;
    RETURN;
  END IF;

  -- 0039 + 10 cifre cellulare.
  IF v_compact ~ '^00393[0-9]{9}$' THEN
    phone_e164 := '+39' || substring(v_compact from 5);
    phone_country_iso2 := 'IT';
    status := 'converted_it_0039';
    RETURN NEXT;
    RETURN;
  END IF;

  -- +39 + 10 cifre cellulare (già E.164 IT mobile).
  IF v_compact ~ '^\+393[0-9]{9}$' THEN
    phone_e164 := v_compact;
    phone_country_iso2 := 'IT';
    status := 'italian_e164';
    RETURN NEXT;
    RETURN;
  END IF;

  -- E.164 generico già valido (straniero o altro IT non-mobile riconosciuto).
  IF v_compact ~ '^\+[1-9][0-9]{7,14}$' THEN
    phone_e164 := v_compact;
    phone_country_iso2 := NULL; -- non inventare ISO2 senza mappa affidabile
    status := 'foreign_or_other_e164';
    RETURN NEXT;
    RETURN;
  END IF;

  phone_e164 := NULL;
  phone_country_iso2 := NULL;
  status := 'ambiguous';
  RETURN NEXT;
END;
$$;

COMMENT ON FUNCTION public.normalize_student_phone_input(text) IS
  'Normalizza telefono allievo: null/blank, cellulare IT→E.164+IT, E.164 generico preservato, altrimenti ambiguous.';

REVOKE ALL ON FUNCTION public.normalize_student_phone_input(text) FROM PUBLIC;

-- ---------------------------------------------------------------------------
-- 3) Normalizzazione dati esistenti (conservativa)
-- ---------------------------------------------------------------------------
-- 3a) Vuoti → null
UPDATE public.students
SET phone = NULL,
    phone_country_iso2 = NULL
WHERE phone IS NOT NULL
  AND btrim(phone) = '';

-- 3b) Convertibili / già IT E.164 mobile → E.164 + IT
UPDATE public.students s
SET
  phone = x.phone_e164,
  phone_country_iso2 = x.phone_country_iso2
FROM (
  SELECT
    s2.id,
    n.phone_e164,
    n.phone_country_iso2,
    n.status
  FROM public.students s2
  CROSS JOIN LATERAL public.normalize_student_phone_input(s2.phone) AS n
  WHERE s2.phone IS NOT NULL
    AND n.status IN (
      'converted_it_national',
      'converted_it_39_prefix',
      'converted_it_0039',
      'italian_e164'
    )
) AS x
WHERE s.id = x.id;

-- 3c) E.164 stranieri/altri: preserva phone, ISO2 resta null
-- (normalizza solo la forma +digits se c'erano separatori)
UPDATE public.students s
SET phone = x.phone_e164
FROM (
  SELECT
    s2.id,
    n.phone_e164,
    n.status
  FROM public.students s2
  CROSS JOIN LATERAL public.normalize_student_phone_input(s2.phone) AS n
  WHERE s2.phone IS NOT NULL
    AND n.status = 'foreign_or_other_e164'
    AND s2.phone IS DISTINCT FROM n.phone_e164
) AS x
WHERE s.id = x.id;

-- Ambiguous: lasciati invariati di proposito.

-- ---------------------------------------------------------------------------
-- 4) Constraint E.164 NOT VALID (nuove scritture enforced; legacy validate rinviata)
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'students_phone_e164_chk'
      AND conrelid = 'public.students'::regclass
  ) THEN
    ALTER TABLE public.students
      ADD CONSTRAINT students_phone_e164_chk
      CHECK (
        phone IS NULL
        OR phone ~ '^\+[1-9][0-9]{7,14}$'
      ) NOT VALID;
  END IF;
END
$$;

-- VALIDATE CONSTRAINT students_phone_e164_chk;  -- NON eseguire finché restano ambigui

-- ---------------------------------------------------------------------------
-- 5) RPC legacy: stessa firma, normalizza cellulari IT / rifiuta non E.164
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
  v_phone text;
  v_iso2 text;
  v_status text;
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

  SELECT n.phone_e164, n.phone_country_iso2, n.status
  INTO v_phone, v_iso2, v_status
  FROM public.normalize_student_phone_input(p_phone) AS n;

  IF v_status = 'ambiguous' THEN
    RAISE EXCEPTION 'invalid_phone';
  END IF;

  IF v_has_auth_user_id THEN
    INSERT INTO public.students (
      user_id,
      auth_user_id,
      first_name,
      last_name,
      phone,
      phone_country_iso2,
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
      v_phone,
      v_iso2,
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
      phone_country_iso2,
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
      v_phone,
      v_iso2,
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
  'Registrazione app (legacy). Normalizza cellulare IT nazionale→E.164; rifiuta phone ambiguous. Preferire register_student_app_e164.';

REVOKE ALL ON FUNCTION public.register_student_app(
  text, text, text, text, text, text
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.register_student_app(
  text, text, text, text, text, text
) TO authenticated;

-- ---------------------------------------------------------------------------
-- 6) Nuova RPC esplicita E.164 + ISO2 (firma dedicata, senza overload ambiguo)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.register_student_app_e164(
  p_first_name text,
  p_last_name text,
  p_phone_e164 text,
  p_phone_country_iso2 text,
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
  v_phone text;
  v_iso2 text;
  v_status text;
  v_normalized_iso2 text;
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

  SELECT n.phone_e164, n.phone_country_iso2, n.status
  INTO v_phone, v_iso2, v_status
  FROM public.normalize_student_phone_input(p_phone_e164) AS n;

  IF v_status = 'ambiguous' THEN
    RAISE EXCEPTION 'invalid_phone';
  END IF;

  -- Richiede già E.164 (o null): rifiuta nazionali grezzi su questa firma.
  IF v_phone IS NOT NULL AND v_status LIKE 'converted_it_%' THEN
    RAISE EXCEPTION 'invalid_phone_e164_required';
  END IF;

  IF v_phone IS NOT NULL AND v_phone !~ '^\+[1-9][0-9]{7,14}$' THEN
    RAISE EXCEPTION 'invalid_phone';
  END IF;

  v_normalized_iso2 := nullif(btrim(coalesce(p_phone_country_iso2, '')), '');
  IF v_normalized_iso2 IS NOT NULL THEN
    v_normalized_iso2 := upper(v_normalized_iso2);
    IF v_normalized_iso2 !~ '^[A-Z]{2}$' THEN
      RAISE EXCEPTION 'invalid_phone_country_iso2';
    END IF;
  END IF;

  -- Se client non passa ISO2 ma il numero è IT mobile E.164, usa IT.
  IF v_normalized_iso2 IS NULL AND v_iso2 IS NOT NULL THEN
    v_normalized_iso2 := v_iso2;
  END IF;

  IF v_has_auth_user_id THEN
    INSERT INTO public.students (
      user_id,
      auth_user_id,
      first_name,
      last_name,
      phone,
      phone_country_iso2,
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
      v_phone,
      v_normalized_iso2,
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
      phone_country_iso2,
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
      v_phone,
      v_normalized_iso2,
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

COMMENT ON FUNCTION public.register_student_app_e164(
  text, text, text, text, text, text, text
) IS
  'Registrazione app con telefono già E.164 + ISO2 (uppercase). Firma futura; legacy register_student_app resta per compatibilità.';

REVOKE ALL ON FUNCTION public.register_student_app_e164(
  text, text, text, text, text, text, text
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.register_student_app_e164(
  text, text, text, text, text, text, text
) TO authenticated;

-- ---------------------------------------------------------------------------
-- 7) Query operative dry-run (commentate; mascherate — non loggare numeri completi)
-- ---------------------------------------------------------------------------
-- Classificazione post-migration (solo conteggi / id prefix / ultime 3 cifre):
--
-- WITH classified AS (
--   SELECT
--     left(s.id::text, 8) AS id_prefix,
--     n.status,
--     right(regexp_replace(coalesce(s.phone, ''), '\D', '', 'g'), 3) AS last3,
--     (s.phone IS NULL) AS phone_null,
--     (s.phone ~ '^\+[1-9][0-9]{7,14}$') AS e164_ok,
--     s.phone_country_iso2
--   FROM public.students s
--   LEFT JOIN LATERAL public.normalize_student_phone_input(s.phone) n ON true
-- )
-- SELECT status, count(*) FROM classified GROUP BY 1;
--
-- SELECT count(*) AS non_e164_remaining
-- FROM public.students
-- WHERE phone IS NOT NULL AND phone !~ '^\+[1-9][0-9]{7,14}$';
--
-- Quando non_e164_remaining = 0:
--   ALTER TABLE public.students VALIDATE CONSTRAINT students_phone_e164_chk;
--
-- Futuro online_orders:
--   buyer_phone → E.164; valutare buyer_phone_country_iso2 (fuori scope PHONE-INTL.2).
