-- =============================================================================
-- PATCH 5H1 — Registro pratiche nautiche (foundation su public.practice_dossiers)
--
-- Colonne registro + vincolo tipo pratica + indice univoco (anno, numero).
-- RPC assign_practice_registry_number: numerazione progressiva per anno (staff).
--
-- Idempotente e production-safe: solo ADD IF NOT EXISTS, CREATE INDEX IF NOT EXISTS,
-- CREATE OR REPLACE function. Nessun DROP/TRUNCATE su dati.
-- Non tocca payments, Extra, link_student_app_access, Edge Functions.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Colonne (solo se mancanti)
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'practice_dossiers'
      AND column_name = 'practice_type'
  ) THEN
    ALTER TABLE public.practice_dossiers
      ADD COLUMN practice_type text NOT NULL DEFAULT 'new_license';
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'practice_dossiers'
      AND column_name = 'registration_date'
  ) THEN
    ALTER TABLE public.practice_dossiers ADD COLUMN registration_date date;
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'practice_dossiers'
      AND column_name = 'registry_year'
  ) THEN
    ALTER TABLE public.practice_dossiers ADD COLUMN registry_year integer;
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'practice_dossiers'
      AND column_name = 'registry_number'
  ) THEN
    ALTER TABLE public.practice_dossiers ADD COLUMN registry_number integer;
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'practice_dossiers'
      AND column_name = 'registry_code'
  ) THEN
    ALTER TABLE public.practice_dossiers ADD COLUMN registry_code text;
  END IF;
END
$$;

-- ---------------------------------------------------------------------------
-- CHECK practice_type (idempotente)
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'practice_dossiers_practice_type_check'
      AND conrelid = 'public.practice_dossiers'::regclass
  ) THEN
    ALTER TABLE public.practice_dossiers
      ADD CONSTRAINT practice_dossiers_practice_type_check
      CHECK (practice_type IN ('new_license', 'renewal', 'duplicate'));
  END IF;
END
$$;

-- ---------------------------------------------------------------------------
-- Univoco (anno, numero) quando entrambi valorizzati
-- ---------------------------------------------------------------------------
CREATE UNIQUE INDEX IF NOT EXISTS practice_dossiers_registry_year_number_uq
  ON public.practice_dossiers (registry_year, registry_number)
  WHERE registry_year IS NOT NULL
    AND registry_number IS NOT NULL;

-- ---------------------------------------------------------------------------
-- RPC: assegna progressivo registro per anno (con lock anti-duplicati)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.assign_practice_registry_number(
  p_practice_dossier_id uuid,
  p_registration_date date DEFAULT CURRENT_DATE
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_reg_date date;
  v_registry_year integer;
  v_next integer;
  v_code text;
  v_has_updated_at boolean;
  r public.practice_dossiers%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  IF NOT public.is_school_staff() THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  IF p_practice_dossier_id IS NULL THEN
    RAISE EXCEPTION 'practice_dossier_id_required';
  END IF;

  v_reg_date := COALESCE(p_registration_date, CURRENT_DATE);
  v_registry_year := EXTRACT(YEAR FROM v_reg_date)::integer;

  SELECT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'practice_dossiers'
      AND column_name = 'updated_at'
  )
  INTO v_has_updated_at;

  SELECT d.*
  INTO r
  FROM public.practice_dossiers d
  WHERE d.id = p_practice_dossier_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'practice_dossier_not_found';
  END IF;

  IF r.registry_year IS NOT NULL AND r.registry_number IS NOT NULL THEN
    RETURN jsonb_build_object(
      'practice_dossier_id', r.id,
      'registration_date', r.registration_date,
      'registry_year', r.registry_year,
      'registry_number', r.registry_number,
      'registry_code', r.registry_code
    );
  END IF;

  PERFORM pg_advisory_xact_lock(4215877, v_registry_year);

  SELECT COALESCE(MAX(pd.registry_number), 0) + 1
  INTO v_next
  FROM public.practice_dossiers pd
  WHERE pd.registry_year = v_registry_year
    AND pd.registry_number IS NOT NULL;

  v_code :=
    v_registry_year::text
    || '/'
    || lpad(v_next::text, 5, '0');

  IF v_has_updated_at THEN
    UPDATE public.practice_dossiers d
    SET
      registration_date = v_reg_date,
      registry_year = v_registry_year,
      registry_number = v_next,
      registry_code = v_code,
      updated_at = now()
    WHERE d.id = p_practice_dossier_id;
  ELSE
    UPDATE public.practice_dossiers d
    SET
      registration_date = v_reg_date,
      registry_year = v_registry_year,
      registry_number = v_next,
      registry_code = v_code
    WHERE d.id = p_practice_dossier_id;
  END IF;

  RETURN jsonb_build_object(
    'practice_dossier_id', p_practice_dossier_id,
    'registration_date', v_reg_date,
    'registry_year', v_registry_year,
    'registry_number', v_next,
    'registry_code', v_code
  );
END;
$$;

COMMENT ON FUNCTION public.assign_practice_registry_number(uuid, date) IS
  'Staff: assegna registration_date, registry_year/number/code al dossier (progressivo per anno). '
  'Idempotente se numero già presente. Advisory lock per anno.';

REVOKE ALL ON FUNCTION public.assign_practice_registry_number(uuid, date) FROM PUBLIC;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    REVOKE ALL ON FUNCTION public.assign_practice_registry_number(uuid, date) FROM anon;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    GRANT EXECUTE ON FUNCTION public.assign_practice_registry_number(uuid, date) TO authenticated;
  END IF;
END
$$;
