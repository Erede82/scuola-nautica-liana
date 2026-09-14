-- =============================================================================
-- ALLIEVI.P1B — Dedup codice fiscale authoritative (normalizzato)
--
-- Contesto remoto:
--   • public.students.fiscal_code = colonna CF ufficiale
--   • tax_code assente sul remoto attuale (non ricreare)
--   • students_fiscal_code_uq = UNIQUE(fiscal_code) match esatto (insufficiente)
--
-- Allinea la UNIQUE DB a CodiceFiscale.normalizza (Flutter):
--   trim di TUTTO il whitespace + uppercase
--   → upper(regexp_replace(fiscal_code, '\s+', '', 'g'))
--
-- NULL consentito; blank / solo whitespace esclusi dal vincolo.
-- Nessun trigger, nessun CHECK formale CF, nessun UNIQUE su email.
-- Nessuna modifica RLS / Auth / RPC.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Rimuove UNIQUE esatto legacy (index-only o constraint omonimo)
-- ---------------------------------------------------------------------------
ALTER TABLE public.students
  DROP CONSTRAINT IF EXISTS students_fiscal_code_uq;

DROP INDEX IF EXISTS public.students_fiscal_code_uq;

-- ---------------------------------------------------------------------------
-- 2. UNIQUE normalizzato (expression + predicate)
-- ---------------------------------------------------------------------------
-- Nome stabile esposto in SQLSTATE 23505 / PostgREST detail:
--   students_fiscal_code_normalized_uq
CREATE UNIQUE INDEX IF NOT EXISTS students_fiscal_code_normalized_uq
  ON public.students (
    upper(regexp_replace(fiscal_code, '\s+', '', 'g'))
  )
  WHERE fiscal_code IS NOT NULL
    AND regexp_replace(fiscal_code, '\s+', '', 'g') <> '';

COMMENT ON INDEX public.students_fiscal_code_normalized_uq IS
  'ALLIEVI.P1B: unicità CF normalizzata (upper + strip whitespace), '
  'allineata a CodiceFiscale.normalizza. NULL/blank esclusi.';
