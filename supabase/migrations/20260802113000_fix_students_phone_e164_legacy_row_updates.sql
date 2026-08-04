-- =============================================================================
-- Fix: students_phone_e164_chk NOT VALID blocked non-phone UPDATEs on legacy rows
-- =============================================================================
-- PHONE-INTL.2 added CHECK (... ) NOT VALID intending to enforce only new phone
-- writes while leaving ambiguous legacy phones untouched until cleaned.
--
-- In PostgreSQL, NOT VALID skips the initial table scan, but the CHECK still
-- runs on every subsequent INSERT/UPDATE of the row — including updates that
-- only touch onboarding_status, notes, first_contacted_at, user_id, etc.
--
-- Concrete break: student with pre-migration landline / ambiguous phone
-- (e.g. '0811234567', left unchanged as ambiguous) → staff marks first contact
-- or changes onboarding → UPDATE fails with students_phone_e164_chk.
--
-- Fix: drop the table CHECK and enforce E.164 only on phone writes via a
-- BEFORE INSERT OR UPDATE OF phone trigger. Legacy non-E.164 values can remain
-- until cleaned; new/edited phones stay constrained.
-- =============================================================================

ALTER TABLE public.students
  DROP CONSTRAINT IF EXISTS students_phone_e164_chk;

CREATE OR REPLACE FUNCTION public.enforce_students_phone_e164()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.phone IS NOT NULL AND NEW.phone !~ '^\+[1-9][0-9]{7,14}$' THEN
    RAISE EXCEPTION 'invalid_phone_e164'
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.enforce_students_phone_e164() IS
  'Enforces students.phone E.164 only when phone is inserted/updated; allows legacy non-E.164 rows to receive non-phone updates.';

DROP TRIGGER IF EXISTS trg_students_phone_e164 ON public.students;

CREATE TRIGGER trg_students_phone_e164
  BEFORE INSERT OR UPDATE OF phone ON public.students
  FOR EACH ROW
  EXECUTE PROCEDURE public.enforce_students_phone_e164();
