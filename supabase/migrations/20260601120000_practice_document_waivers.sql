-- =============================================================================
-- Practice document waivers — documenti checklist segnati "non necessari"
--
-- Idempotente. Staff-only RLS. Nessun impatto su upload documenti/foto.
-- Non applicare con db push finché non confermato in produzione.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.practice_document_waivers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  practice_dossier_id uuid NOT NULL
    REFERENCES public.practice_dossiers (id) ON DELETE CASCADE,
  requirement_id text NOT NULL
    CHECK (requirement_id IN (
      'identityDocument',
      'fiscalCode',
      'medicalCertificate',
      'licensePhoto',
      'practiceForm',
      'currentNauticalLicense',
      'lossReport'
    )),
  note text,
  waived_by_staff_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (practice_dossier_id, requirement_id)
);

CREATE INDEX IF NOT EXISTS idx_practice_document_waivers_dossier
  ON public.practice_document_waivers (practice_dossier_id);

DROP TRIGGER IF EXISTS trg_practice_document_waivers_updated
  ON public.practice_document_waivers;
CREATE TRIGGER trg_practice_document_waivers_updated
  BEFORE UPDATE ON public.practice_document_waivers
  FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();

ALTER TABLE public.practice_document_waivers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS practice_document_waivers_staff_all
  ON public.practice_document_waivers;
CREATE POLICY practice_document_waivers_staff_all
  ON public.practice_document_waivers
  FOR ALL
  USING (public.is_school_staff())
  WITH CHECK (public.is_school_staff());

COMMENT ON TABLE public.practice_document_waivers IS
  'Segnalazioni staff: requisito documentale pratica non necessario per il fascicolo. '
  'Usato dalla checklist Scheda 360 e dal conteggio directory Pratiche.';
