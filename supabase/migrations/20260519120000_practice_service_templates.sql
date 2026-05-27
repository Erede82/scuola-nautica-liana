-- =============================================================================
-- Practice service templates — catalogo prestazioni preimpostate (Impostazioni)
--
-- Idempotente. Staff-only RLS. Nessun impatto su students / practice_dossiers /
-- student_financial_summaries / record_payment.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.practice_service_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  title text NOT NULL,
  description text,
  practice_type text NOT NULL DEFAULT 'other'
    CHECK (practice_type IN ('new_license', 'renewal', 'duplicate', 'other')),
  enrolled_course_path text
    CHECK (
      enrolled_course_path IS NULL
      OR enrolled_course_path IN ('entro_12_miglia', 'entro_12_miglia_vela', 'd1')
    ),
  enrolled_license_category text
    CHECK (
      enrolled_license_category IS NULL
      OR enrolled_license_category IN ('motore', 'vela', 'd1')
    ),
  default_registration_fee_cents integer NOT NULL DEFAULT 0
    CHECK (default_registration_fee_cents >= 0),
  suggested_deposit_cents integer NOT NULL DEFAULT 0
    CHECK (suggested_deposit_cents >= 0),
  internal_notes text,
  active boolean NOT NULL DEFAULT true,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_practice_service_templates_active_sort
  ON public.practice_service_templates (active, sort_order, title);

CREATE INDEX IF NOT EXISTS idx_practice_service_templates_slug
  ON public.practice_service_templates (slug);

DROP TRIGGER IF EXISTS trg_practice_service_templates_updated
  ON public.practice_service_templates;
CREATE TRIGGER trg_practice_service_templates_updated
  BEFORE UPDATE ON public.practice_service_templates
  FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();

ALTER TABLE public.practice_service_templates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS practice_service_templates_staff_all
  ON public.practice_service_templates;
CREATE POLICY practice_service_templates_staff_all
  ON public.practice_service_templates
  FOR ALL
  USING (public.is_school_staff())
  WITH CHECK (public.is_school_staff());

COMMENT ON TABLE public.practice_service_templates IS
  'Catalogo prestazioni/pratiche preimpostate per segreteria (Impostazioni). '
  'Snapshot applicato in fase di nuova pratica — non collegato live agli allievi.';

-- ---------------------------------------------------------------------------
-- Seed iniziale (idempotente)
-- ---------------------------------------------------------------------------
INSERT INTO public.practice_service_templates (
  slug,
  title,
  description,
  practice_type,
  enrolled_course_path,
  enrolled_license_category,
  default_registration_fee_cents,
  suggested_deposit_cents,
  internal_notes,
  active,
  sort_order
)
VALUES
  (
    'patente-entro-12-motore',
    'Patente nautica entro 12 miglia motore',
    'Percorso standard patente entro 12 miglia — modulo motore.',
    'new_license',
    'entro_12_miglia',
    'motore',
    0,
    0,
    'Da configurare: importo totale e acconto consigliato.',
    true,
    10
  ),
  (
    'patente-oltre-12-motore',
    'Patente nautica oltre 12 miglia motore',
    'Percorso oltre 12 miglia con focus operativo motore (catalogo vela/motore).',
    'new_license',
    'entro_12_miglia_vela',
    'motore',
    0,
    0,
    'Da configurare: verificare percorso iscrizione e importi.',
    true,
    20
  ),
  (
    'patente-d1',
    'Patente nautica D1',
    'Percorso patente D1.',
    'new_license',
    'd1',
    'd1',
    0,
    0,
    'Da configurare: importo totale e acconto consigliato.',
    true,
    30
  ),
  (
    'rinnovo-patente-nautica',
    'Rinnovo patente nautica',
    'Pratica di rinnovo patente nautica.',
    'renewal',
    NULL,
    NULL,
    0,
    0,
    'Da configurare: importo e note operative rinnovo.',
    true,
    40
  ),
  (
    'duplicato-patente-nautica',
    'Duplicato patente nautica',
    'Richiesta duplicato documento di patente nautica.',
    'duplicate',
    NULL,
    NULL,
    0,
    0,
    'Da configurare: importo e documenti richiesti.',
    true,
    50
  ),
  (
    'integrazione-estensione-patente',
    'Integrazione / estensione patente nautica',
    'Pratica di integrazione o estensione titolo nautico.',
    'other',
    NULL,
    NULL,
    0,
    0,
    'Da configurare: tipologia e importo.',
    true,
    60
  ),
  (
    'pratica-nautica-generica',
    'Pratica nautica generica',
    'Prestazione generica non classificata nel catalogo standard.',
    'other',
    NULL,
    NULL,
    0,
    0,
    'Da configurare.',
    true,
    70
  ),
  (
    'altro-servizio-nautico',
    'Altro servizio nautico',
    'Altre prestazioni o servizi nautici della scuola.',
    'other',
    NULL,
    NULL,
    0,
    0,
    'Da configurare.',
    true,
    80
  )
ON CONFLICT (slug) DO UPDATE
SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  practice_type = EXCLUDED.practice_type,
  enrolled_course_path = EXCLUDED.enrolled_course_path,
  enrolled_license_category = EXCLUDED.enrolled_license_category,
  internal_notes = EXCLUDED.internal_notes,
  sort_order = EXCLUDED.sort_order,
  active = EXCLUDED.active,
  updated_at = now();
