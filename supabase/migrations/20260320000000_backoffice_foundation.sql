-- =============================================================================
-- Scuola Nautica Liana — backoffice / gestione scuola (foundation)
-- =============================================================================
-- Allinea il modello dati a lib/domain/backoffice/* (Flutter).
-- Valute: importi in centesimi (INTEGER) come nel dominio Dart.
-- Tassonomia patente: testo allineato a LicenseCategoryId.name (motore, vela, d1).
-- =============================================================================

-- Extensions (Supabase tipicamente già abilita pgcrypto)
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ---------------------------------------------------------------------------
-- Ruoli applicativi (JWT / session Supabase Auth)
-- ---------------------------------------------------------------------------
-- Collega auth.users a un ruolo e, per gli studenti, alla riga public.students.
CREATE TABLE IF NOT EXISTS public.school_user_roles (
  user_id uuid PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
  role text NOT NULL
    CHECK (role IN ('student', 'school_admin', 'staff', 'instructor')),
  -- Se role = 'student', punta al record students.id dello stesso utente.
  student_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.school_user_roles IS
  'Ruoli interni: student vs staff. student_id valorizzato solo per ruolo student.';

-- FK student_id verso students aggiunto dopo creazione tabella students.

-- ---------------------------------------------------------------------------
-- Anagrafica studenti
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.students (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_user_id uuid UNIQUE REFERENCES auth.users (id) ON DELETE SET NULL,
  first_name text NOT NULL,
  last_name text NOT NULL,
  phone text,
  email text,
  birth_date date,
  tax_code text,
  -- Allinea a PostalAddress Dart; evoluzione futura: colonne normalizzate.
  address jsonb,
  enrolled_license_category text NOT NULL
    CHECK (enrolled_license_category IN ('motore', 'vela', 'd1')),
  registration_status text NOT NULL
    CHECK (registration_status IN (
      'pending', 'active', 'suspended', 'completed', 'withdrawn'
    )),
  internal_notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_students_auth_user ON public.students (auth_user_id);
CREATE INDEX IF NOT EXISTS idx_students_name ON public.students (last_name, first_name);
CREATE INDEX IF NOT EXISTS idx_students_status ON public.students (registration_status);

COMMENT ON COLUMN public.students.internal_notes IS
  'Campo legacy sintesi staff; note strutturate in staff_internal_notes.';

ALTER TABLE public.school_user_roles
  ADD CONSTRAINT school_user_roles_student_fk
  FOREIGN KEY (student_id) REFERENCES public.students (id) ON DELETE SET NULL;

-- ---------------------------------------------------------------------------
-- Riepilogo economico (denormalizzato; allineato a StudentFinancialSummary)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.student_financial_summaries (
  student_id uuid PRIMARY KEY REFERENCES public.students (id) ON DELETE CASCADE,
  registration_fee_cents integer NOT NULL DEFAULT 0,
  currency_code text NOT NULL DEFAULT 'EUR',
  total_paid_cents integer NOT NULL DEFAULT 0,
  remaining_balance_cents integer NOT NULL DEFAULT 0,
  accounting_notes text,
  last_updated_at timestamptz
);

-- ---------------------------------------------------------------------------
-- Accessi studio (allineati a student_study_progress.dart)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.lesson_quiz_sheet_unlocks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id uuid NOT NULL REFERENCES public.students (id) ON DELETE CASCADE,
  license_category text NOT NULL
    CHECK (license_category IN ('motore', 'vela', 'd1')),
  lesson_number integer NOT NULL,
  sheet_number integer NOT NULL,
  unlocked boolean NOT NULL DEFAULT false,
  unlocked_at timestamptz,
  unlocked_by_staff_id uuid,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT lesson_sheet_unlock_uq UNIQUE (student_id, license_category, lesson_number, sheet_number)
);

CREATE INDEX IF NOT EXISTS idx_sheet_unlocks_student ON public.lesson_quiz_sheet_unlocks (student_id);

CREATE TABLE IF NOT EXISTS public.exam_quiz_access (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id uuid NOT NULL REFERENCES public.students (id) ON DELETE CASCADE,
  license_category text NOT NULL
    CHECK (license_category IN ('motore', 'vela', 'd1')),
  exam_unlocked boolean NOT NULL DEFAULT false,
  updated_at timestamptz,
  updated_by_staff_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT exam_quiz_access_uq UNIQUE (student_id, license_category)
);

CREATE INDEX IF NOT EXISTS idx_exam_quiz_access_student ON public.exam_quiz_access (student_id);

CREATE TABLE IF NOT EXISTS public.error_review_topic_assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id uuid NOT NULL REFERENCES public.students (id) ON DELETE CASCADE,
  license_category text NOT NULL
    CHECK (license_category IN ('motore', 'vela', 'd1')),
  lesson_number integer NOT NULL,
  topic_unlocked boolean NOT NULL DEFAULT false,
  didactic_note text,
  updated_at timestamptz,
  updated_by_staff_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT error_review_uq UNIQUE (student_id, license_category, lesson_number)
);

CREATE INDEX IF NOT EXISTS idx_error_review_student ON public.error_review_topic_assignments (student_id);

-- ---------------------------------------------------------------------------
-- Guide / appuntamenti
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.guidance_appointments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id uuid NOT NULL REFERENCES public.students (id) ON DELETE CASCADE,
  lesson_date date NOT NULL,
  start_time timestamptz,
  end_time timestamptz,
  instructor_name text,
  instructor_staff_id uuid,
  lesson_type text NOT NULL
    CHECK (lesson_type IN (
      'theory', 'practiceSea', 'practiceSimulator',
      'officeMeeting', 'examPrep', 'other'
    )),
  reminder_status text NOT NULL DEFAULT 'none'
    CHECK (reminder_status IN ('none', 'scheduled', 'sent', 'acknowledged')),
  completion_outcome text NOT NULL DEFAULT 'pending'
    CHECK (completion_outcome IN (
      'pending', 'attended', 'absent', 'rescheduled'
    )),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_guidance_student_date ON public.guidance_appointments (student_id, lesson_date);

-- ---------------------------------------------------------------------------
-- Esami
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.exam_attempts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id uuid NOT NULL REFERENCES public.students (id) ON DELETE CASCADE,
  exam_type text NOT NULL CHECK (exam_type IN ('theory', 'practical')),
  attempt_number integer NOT NULL,
  result text NOT NULL
    CHECK (result IN (
      'pending', 'scheduled', 'passed', 'failed', 'exempt', 'noShow'
    )),
  exam_date date,
  score_or_label text,
  external_session_id text,
  notes text,
  recorded_by_staff_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT exam_attempt_uq UNIQUE (student_id, exam_type, attempt_number)
);

CREATE INDEX IF NOT EXISTS idx_exam_attempts_student ON public.exam_attempts (student_id);

-- ---------------------------------------------------------------------------
-- Incassi
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id uuid NOT NULL REFERENCES public.students (id) ON DELETE CASCADE,
  amount_cents integer NOT NULL CHECK (amount_cents > 0),
  currency_code text NOT NULL DEFAULT 'EUR',
  received_at timestamptz NOT NULL,
  method text NOT NULL
    CHECK (method IN ('card', 'sepaBankTransfer', 'cash', 'check', 'other')),
  receipt_reference text,
  fiscal_receipt_number text,
  notes text,
  recorded_by_staff_id uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_payments_student_received ON public.payments (student_id, received_at DESC);

-- ---------------------------------------------------------------------------
-- Pratica / documenti
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.practice_dossiers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id uuid NOT NULL UNIQUE REFERENCES public.students (id) ON DELETE CASCADE,
  practice_number text,
  license_number text,
  issue_date date,
  expiration_date date,
  document_status text NOT NULL DEFAULT 'notStarted'
    CHECK (document_status IN (
      'notStarted', 'collected', 'submittedToAuthority',
      'issued', 'revoked', 'expired'
    )),
  practice_status text NOT NULL DEFAULT 'notOpen'
    CHECK (practice_status IN (
      'notOpen', 'inProgress', 'waitingDocuments',
      'submitted', 'closed'
    )),
  authority_notes text,
  last_checked_at timestamptz,
  updated_by_staff_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Note interne strutturate (staff)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.staff_internal_notes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id uuid NOT NULL REFERENCES public.students (id) ON DELETE CASCADE,
  body text NOT NULL,
  category text NOT NULL DEFAULT 'general'
    CHECK (category IN ('general', 'accounting', 'study', 'exam')),
  author_staff_id uuid,
  author_display_name text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_staff_notes_student_created ON public.staff_internal_notes (student_id, created_at DESC);

-- ---------------------------------------------------------------------------
-- Log attività backoffice (audit leggero)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.backoffice_activity_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id uuid NOT NULL REFERENCES public.students (id) ON DELETE CASCADE,
  event_type text NOT NULL
    CHECK (event_type IN (
      'paymentAdded', 'guidanceAppointmentAdded', 'examResultRecorded',
      'internalNoteAdded', 'practiceDossierUpdated', 'studyAccessChanged',
      'profileInternalNoteUpdated'
    )),
  title text NOT NULL,
  description text,
  actor_staff_id uuid,
  actor_display_name text,
  occurred_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_activity_student_time ON public.backoffice_activity_events (student_id, occurred_at DESC);

-- ---------------------------------------------------------------------------
-- updated_at trigger (pattern Supabase)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_students_updated ON public.students;
CREATE TRIGGER trg_students_updated
  BEFORE UPDATE ON public.students
  FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();

DROP TRIGGER IF EXISTS trg_school_user_roles_updated ON public.school_user_roles;
CREATE TRIGGER trg_school_user_roles_updated
  BEFORE UPDATE ON public.school_user_roles
  FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();

DROP TRIGGER IF EXISTS trg_lesson_quiz_sheet_unlocks_updated ON public.lesson_quiz_sheet_unlocks;
CREATE TRIGGER trg_lesson_quiz_sheet_unlocks_updated
  BEFORE UPDATE ON public.lesson_quiz_sheet_unlocks
  FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();

DROP TRIGGER IF EXISTS trg_guidance_appointments_updated ON public.guidance_appointments;
CREATE TRIGGER trg_guidance_appointments_updated
  BEFORE UPDATE ON public.guidance_appointments
  FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();

DROP TRIGGER IF EXISTS trg_practice_dossiers_updated ON public.practice_dossiers;
CREATE TRIGGER trg_practice_dossiers_updated
  BEFORE UPDATE ON public.practice_dossiers
  FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();

-- ---------------------------------------------------------------------------
-- RLS — abilitazione + helper
-- ---------------------------------------------------------------------------
-- Piano: gli studenti leggono solo i propri dati; staff/admin gestiscono tutto.
-- In sviluppo si può usare service_role per bypass RLS finché le policy non sono complete.

CREATE OR REPLACE FUNCTION public.is_school_staff()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT coalesce(
    (
      SELECT sur.role IN ('school_admin', 'staff', 'instructor')
      FROM public.school_user_roles sur
      WHERE sur.user_id = auth.uid()
    ),
    false
  );
$$;

COMMENT ON FUNCTION public.is_school_staff IS
  'TRUE se auth.uid() ha ruolo operativo scuola. SECURITY DEFINER per uso in RLS.';

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
      AND s.auth_user_id = auth.uid()
  );
$$;

-- Abilita RLS
ALTER TABLE public.school_user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_financial_summaries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lesson_quiz_sheet_unlocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exam_quiz_access ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.error_review_topic_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guidance_appointments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exam_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.practice_dossiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_internal_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.backoffice_activity_events ENABLE ROW LEVEL SECURITY;

-- Policy minime (first pass): staff full CRUD sugli studenti; studente legge se stesso.
-- TODO: affinare INSERT/UPDATE per student (solo subset campi esposti ad app mobile).
-- TODO: collegare recorded_by_staff_id a staff profile quando esiste tabella dedicata.

CREATE POLICY students_select_policy ON public.students
  FOR SELECT USING (public.is_own_student(id) OR public.is_school_staff());

CREATE POLICY students_modify_staff ON public.students
  FOR ALL USING (public.is_school_staff()) WITH CHECK (public.is_school_staff());

CREATE POLICY financial_select_policy ON public.student_financial_summaries
  FOR SELECT USING (public.is_own_student(student_id) OR public.is_school_staff());

CREATE POLICY financial_staff_all ON public.student_financial_summaries
  FOR ALL USING (public.is_school_staff()) WITH CHECK (public.is_school_staff());

CREATE POLICY study_unlocks_select ON public.lesson_quiz_sheet_unlocks
  FOR SELECT USING (public.is_own_student(student_id) OR public.is_school_staff());

CREATE POLICY study_unlocks_staff_all ON public.lesson_quiz_sheet_unlocks
  FOR ALL USING (public.is_school_staff()) WITH CHECK (public.is_school_staff());

CREATE POLICY exam_access_select ON public.exam_quiz_access
  FOR SELECT USING (public.is_own_student(student_id) OR public.is_school_staff());

CREATE POLICY exam_access_staff_all ON public.exam_quiz_access
  FOR ALL USING (public.is_school_staff()) WITH CHECK (public.is_school_staff());

CREATE POLICY error_review_select ON public.error_review_topic_assignments
  FOR SELECT USING (public.is_own_student(student_id) OR public.is_school_staff());

CREATE POLICY error_review_staff_all ON public.error_review_topic_assignments
  FOR ALL USING (public.is_school_staff()) WITH CHECK (public.is_school_staff());

-- Appuntamenti: studente vede i propri (app Guida); staff gestisce.
CREATE POLICY guidance_select ON public.guidance_appointments
  FOR SELECT USING (public.is_own_student(student_id) OR public.is_school_staff());

CREATE POLICY guidance_staff_all ON public.guidance_appointments
  FOR ALL USING (public.is_school_staff()) WITH CHECK (public.is_school_staff());

-- Esami: sola lettura studente su propri tentativi (rientra in “own data”).
CREATE POLICY exam_attempts_select ON public.exam_attempts
  FOR SELECT USING (public.is_own_student(student_id) OR public.is_school_staff());

CREATE POLICY exam_attempts_staff_all ON public.exam_attempts
  FOR ALL USING (public.is_school_staff()) WITH CHECK (public.is_school_staff());

-- Pagamenti: tipicamente NO SELECT per studente grezzo; TODO policy export ricevuta.
-- Prima versione: student non select; solo staff.
CREATE POLICY payments_staff_all ON public.payments
  FOR ALL USING (public.is_school_staff()) WITH CHECK (public.is_school_staff());

-- TODO: aggiungere payments_select_student_ridotto (importo mascherato / ricevute proprie).

CREATE POLICY practice_staff_all ON public.practice_dossiers
  FOR ALL USING (public.is_school_staff()) WITH CHECK (public.is_school_staff());

-- TODO: practice_select_own se fascicolo deve essere visibile parzialmente allo studente.

CREATE POLICY staff_notes_staff_all ON public.staff_internal_notes
  FOR ALL USING (public.is_school_staff()) WITH CHECK (public.is_school_staff());

CREATE POLICY activity_staff_all ON public.backoffice_activity_events
  FOR ALL USING (public.is_school_staff()) WITH CHECK (public.is_school_staff());

-- Ruoli: utente legge il proprio record ruolo; staff legge/gestisce tutti.
CREATE POLICY school_roles_select_own ON public.school_user_roles
  FOR SELECT USING (user_id = auth.uid() OR public.is_school_staff());

CREATE POLICY school_roles_staff_write ON public.school_user_roles
  FOR INSERT WITH CHECK (public.is_school_staff());

CREATE POLICY school_roles_staff_update ON public.school_user_roles
  FOR UPDATE USING (public.is_school_staff()) WITH CHECK (public.is_school_staff());

-- =============================================================================
-- Fine migration foundation backoffice
-- =============================================================================
