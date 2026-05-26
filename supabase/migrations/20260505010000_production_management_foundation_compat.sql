-- =============================================================================
-- Production management foundation compatibility
-- =============================================================================
-- Production-safe, idempotent, non-destructive.
-- Rules followed:
-- - no DROP
-- - no TRUNCATE
-- - no database reset
-- - no destructive ALTER
-- - does not recreate public.payments
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Shared helpers expected by RLS and triggers
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.is_school_staff()
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
      AND sur.role IN ('admin', 'staff')
  );
$$;

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

-- ---------------------------------------------------------------------------
-- Existing payments compatibility: add only missing columns used by RPC
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  v_blocking_columns text;
BEGIN
  SELECT string_agg(column_name, ', ' ORDER BY ordinal_position)
  INTO v_blocking_columns
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = 'payments'
    AND is_nullable = 'NO'
    AND column_default IS NULL
    AND column_name NOT IN (
      'student_id',
      'amount',
      'paid_at',
      'amount_cents',
      'currency_code',
      'received_at',
      'method',
      'source',
      'category',
      'receipt_reference',
      'notes',
      'recorded_by_staff_id',
      'idempotency_key'
    );

  IF v_blocking_columns IS NOT NULL THEN
    RAISE EXCEPTION
      'payments has NOT NULL columns without defaults not written by record_payment: %',
      v_blocking_columns;
  END IF;
END
$$;

ALTER TABLE public.payments
  ADD COLUMN IF NOT EXISTS amount_cents integer;

ALTER TABLE public.payments
  ADD COLUMN IF NOT EXISTS currency_code text DEFAULT 'EUR';

ALTER TABLE public.payments
  ADD COLUMN IF NOT EXISTS received_at timestamptz;

ALTER TABLE public.payments
  ADD COLUMN IF NOT EXISTS receipt_reference text;

ALTER TABLE public.payments
  ADD COLUMN IF NOT EXISTS fiscal_receipt_number text;

ALTER TABLE public.payments
  ADD COLUMN IF NOT EXISTS notes text;

ALTER TABLE public.payments
  ADD COLUMN IF NOT EXISTS recorded_by_staff_id uuid;

ALTER TABLE public.payments
  ADD COLUMN IF NOT EXISTS idempotency_key text;

CREATE UNIQUE INDEX IF NOT EXISTS payments_idempotency_key_uq
  ON public.payments (idempotency_key)
  WHERE idempotency_key IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_payments_student_received
  ON public.payments (student_id, received_at DESC);

ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

-- Direct client writes are intentionally blocked: payments must be inserted by
-- public.record_payment(), which runs as SECURITY DEFINER and updates the
-- financial summary/audit log atomically.
REVOKE INSERT, UPDATE, DELETE ON TABLE public.payments FROM anon, authenticated;
GRANT SELECT ON TABLE public.payments TO authenticated;

-- ---------------------------------------------------------------------------
-- Backoffice accounting/audit foundation
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

CREATE TABLE IF NOT EXISTS public.backoffice_activity_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id uuid NOT NULL REFERENCES public.students (id) ON DELETE CASCADE,
  event_type text NOT NULL,
  title text NOT NULL,
  description text,
  actor_staff_id uuid,
  actor_display_name text,
  occurred_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_activity_student_time
  ON public.backoffice_activity_events (student_id, occurred_at DESC);

-- ---------------------------------------------------------------------------
-- Pratiche and Guide/Agenda
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.practice_dossiers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id uuid NOT NULL UNIQUE REFERENCES public.students (id) ON DELETE CASCADE,
  practice_number text,
  license_number text,
  issue_date date,
  expiration_date date,
  document_status text NOT NULL DEFAULT 'notStarted',
  practice_status text NOT NULL DEFAULT 'notOpen',
  authority_notes text,
  last_checked_at timestamptz,
  updated_by_staff_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.guidance_appointments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id uuid NOT NULL REFERENCES public.students (id) ON DELETE CASCADE,
  lesson_date date NOT NULL,
  start_time timestamptz,
  end_time timestamptz,
  instructor_name text,
  instructor_staff_id uuid,
  lesson_type text NOT NULL DEFAULT 'other',
  reminder_status text NOT NULL DEFAULT 'none',
  completion_outcome text NOT NULL DEFAULT 'pending',
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_guidance_student_date
  ON public.guidance_appointments (student_id, lesson_date);

-- ---------------------------------------------------------------------------
-- Management foundation
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.instructors (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  display_name text NOT NULL,
  slug text NOT NULL UNIQUE,
  phone text,
  email text,
  active boolean NOT NULL DEFAULT true,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_instructors_active_name
  ON public.instructors (active, display_name);

CREATE TABLE IF NOT EXISTS public.expense_categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text NOT NULL UNIQUE,
  description text,
  active boolean NOT NULL DEFAULT true,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_expense_categories_active_sort
  ON public.expense_categories (active, sort_order, name);

CREATE TABLE IF NOT EXISTS public.expenses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category_id uuid REFERENCES public.expense_categories (id) ON DELETE SET NULL,
  instructor_id uuid REFERENCES public.instructors (id) ON DELETE SET NULL,
  amount_cents integer NOT NULL CHECK (amount_cents > 0),
  currency_code text NOT NULL DEFAULT 'EUR',
  expense_date date NOT NULL DEFAULT current_date,
  payment_method text NOT NULL DEFAULT 'other',
  title text NOT NULL,
  notes text,
  receipt_reference text,
  recorded_by_staff_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_expenses_date
  ON public.expenses (expense_date DESC);

CREATE INDEX IF NOT EXISTS idx_expenses_category_date
  ON public.expenses (category_id, expense_date DESC);

CREATE TABLE IF NOT EXISTS public.fuel_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  expense_id uuid REFERENCES public.expenses (id) ON DELETE SET NULL,
  instructor_id uuid REFERENCES public.instructors (id) ON DELETE SET NULL,
  fuel_date date NOT NULL DEFAULT current_date,
  liters numeric(10, 2) CHECK (liters IS NULL OR liters > 0),
  amount_cents integer CHECK (amount_cents IS NULL OR amount_cents > 0),
  currency_code text NOT NULL DEFAULT 'EUR',
  boat_name text,
  supplier text,
  notes text,
  recorded_by_staff_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fuel_logs_date
  ON public.fuel_logs (fuel_date DESC);

-- ---------------------------------------------------------------------------
-- Student documents/photos metadata
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.student_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id uuid NOT NULL REFERENCES public.students (id) ON DELETE CASCADE,
  practice_dossier_id uuid REFERENCES public.practice_dossiers (id) ON DELETE SET NULL,
  document_type text NOT NULL DEFAULT 'other',
  title text NOT NULL,
  storage_path text,
  file_name text,
  mime_type text,
  status text NOT NULL DEFAULT 'pending',
  expires_at date,
  notes text,
  uploaded_by_staff_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_student_documents_student
  ON public.student_documents (student_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.student_photos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id uuid NOT NULL REFERENCES public.students (id) ON DELETE CASCADE,
  photo_kind text NOT NULL DEFAULT 'profile',
  storage_path text,
  file_name text,
  mime_type text,
  notes text,
  uploaded_by_staff_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_student_photos_student
  ON public.student_photos (student_id, created_at DESC);

-- ---------------------------------------------------------------------------
-- Extra products/videos/purchases
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.extra_products (
  id text PRIMARY KEY,
  title text NOT NULL,
  subtitle text,
  description text,
  price_cents integer CHECK (price_cents IS NULL OR price_cents >= 0),
  currency_code text NOT NULL DEFAULT 'EUR',
  active boolean NOT NULL DEFAULT true,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_extra_products_active_sort
  ON public.extra_products (active, sort_order, title);

CREATE TABLE IF NOT EXISTS public.extra_video_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id text NOT NULL REFERENCES public.extra_products (id) ON DELETE CASCADE,
  title text NOT NULL,
  description text,
  video_url text,
  duration_seconds integer CHECK (duration_seconds IS NULL OR duration_seconds >= 0),
  sort_order integer NOT NULL DEFAULT 0,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_extra_video_items_product_sort
  ON public.extra_video_items (product_id, active, sort_order);

CREATE TABLE IF NOT EXISTS public.student_extra_purchases (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id uuid NOT NULL REFERENCES public.students (id) ON DELETE CASCADE,
  product_id text NOT NULL REFERENCES public.extra_products (id) ON DELETE RESTRICT,
  status text NOT NULL DEFAULT 'purchased',
  purchased_at timestamptz NOT NULL DEFAULT now(),
  amount_cents integer CHECK (amount_cents IS NULL OR amount_cents >= 0),
  currency_code text NOT NULL DEFAULT 'EUR',
  payment_reference text,
  notes text,
  recorded_by_staff_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT student_extra_purchase_unique_product UNIQUE (student_id, product_id)
);

CREATE INDEX IF NOT EXISTS idx_student_extra_purchases_student
  ON public.student_extra_purchases (student_id, purchased_at DESC);

CREATE INDEX IF NOT EXISTS idx_student_extra_purchases_product
  ON public.student_extra_purchases (product_id, status);

-- ---------------------------------------------------------------------------
-- Triggers: create only if missing, no DROP
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_practice_dossiers_updated') THEN
    CREATE TRIGGER trg_practice_dossiers_updated
      BEFORE UPDATE ON public.practice_dossiers
      FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_guidance_appointments_updated') THEN
    CREATE TRIGGER trg_guidance_appointments_updated
      BEFORE UPDATE ON public.guidance_appointments
      FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_instructors_updated') THEN
    CREATE TRIGGER trg_instructors_updated
      BEFORE UPDATE ON public.instructors
      FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_expense_categories_updated') THEN
    CREATE TRIGGER trg_expense_categories_updated
      BEFORE UPDATE ON public.expense_categories
      FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_expenses_updated') THEN
    CREATE TRIGGER trg_expenses_updated
      BEFORE UPDATE ON public.expenses
      FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_fuel_logs_updated') THEN
    CREATE TRIGGER trg_fuel_logs_updated
      BEFORE UPDATE ON public.fuel_logs
      FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_student_documents_updated') THEN
    CREATE TRIGGER trg_student_documents_updated
      BEFORE UPDATE ON public.student_documents
      FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_student_photos_updated') THEN
    CREATE TRIGGER trg_student_photos_updated
      BEFORE UPDATE ON public.student_photos
      FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_extra_products_updated') THEN
    CREATE TRIGGER trg_extra_products_updated
      BEFORE UPDATE ON public.extra_products
      FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_extra_video_items_updated') THEN
    CREATE TRIGGER trg_extra_video_items_updated
      BEFORE UPDATE ON public.extra_video_items
      FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_student_extra_purchases_updated') THEN
    CREATE TRIGGER trg_student_extra_purchases_updated
      BEFORE UPDATE ON public.student_extra_purchases
      FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();
  END IF;
END
$$;

-- ---------------------------------------------------------------------------
-- RLS enablement
-- ---------------------------------------------------------------------------
ALTER TABLE public.student_financial_summaries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.backoffice_activity_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.practice_dossiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guidance_appointments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.instructors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expense_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fuel_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.extra_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.extra_video_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_extra_purchases ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- Idempotent RLS policies (no DROP)
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'student_financial_summaries' AND policyname = 'financial_select_policy') THEN
    CREATE POLICY financial_select_policy ON public.student_financial_summaries
      FOR SELECT USING (public.is_own_student(student_id) OR public.is_school_staff());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'payments' AND policyname = 'payments_staff_select') THEN
    CREATE POLICY payments_staff_select ON public.payments
      FOR SELECT USING (public.is_school_staff());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'student_financial_summaries' AND policyname = 'financial_staff_all') THEN
    CREATE POLICY financial_staff_all ON public.student_financial_summaries
      FOR ALL USING (public.is_school_staff()) WITH CHECK (public.is_school_staff());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'backoffice_activity_events' AND policyname = 'activity_staff_all') THEN
    CREATE POLICY activity_staff_all ON public.backoffice_activity_events
      FOR ALL USING (public.is_school_staff()) WITH CHECK (public.is_school_staff());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'practice_dossiers' AND policyname = 'practice_staff_all') THEN
    CREATE POLICY practice_staff_all ON public.practice_dossiers
      FOR ALL USING (public.is_school_staff()) WITH CHECK (public.is_school_staff());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'guidance_appointments' AND policyname = 'guidance_select') THEN
    CREATE POLICY guidance_select ON public.guidance_appointments
      FOR SELECT USING (public.is_own_student(student_id) OR public.is_school_staff());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'guidance_appointments' AND policyname = 'guidance_staff_all') THEN
    CREATE POLICY guidance_staff_all ON public.guidance_appointments
      FOR ALL USING (public.is_school_staff()) WITH CHECK (public.is_school_staff());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'instructors' AND policyname = 'instructors_staff_all') THEN
    CREATE POLICY instructors_staff_all ON public.instructors
      FOR ALL USING (public.is_school_staff()) WITH CHECK (public.is_school_staff());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'expense_categories' AND policyname = 'expense_categories_staff_all') THEN
    CREATE POLICY expense_categories_staff_all ON public.expense_categories
      FOR ALL USING (public.is_school_staff()) WITH CHECK (public.is_school_staff());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'expenses' AND policyname = 'expenses_staff_all') THEN
    CREATE POLICY expenses_staff_all ON public.expenses
      FOR ALL USING (public.is_school_staff()) WITH CHECK (public.is_school_staff());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'fuel_logs' AND policyname = 'fuel_logs_staff_all') THEN
    CREATE POLICY fuel_logs_staff_all ON public.fuel_logs
      FOR ALL USING (public.is_school_staff()) WITH CHECK (public.is_school_staff());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'student_documents' AND policyname = 'student_documents_staff_all') THEN
    CREATE POLICY student_documents_staff_all ON public.student_documents
      FOR ALL USING (public.is_school_staff()) WITH CHECK (public.is_school_staff());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'student_photos' AND policyname = 'student_photos_staff_all') THEN
    CREATE POLICY student_photos_staff_all ON public.student_photos
      FOR ALL USING (public.is_school_staff()) WITH CHECK (public.is_school_staff());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'extra_products' AND policyname = 'extra_products_select_active') THEN
    CREATE POLICY extra_products_select_active ON public.extra_products
      FOR SELECT USING (active OR public.is_school_staff());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'extra_products' AND policyname = 'extra_products_staff_all') THEN
    CREATE POLICY extra_products_staff_all ON public.extra_products
      FOR ALL USING (public.is_school_staff()) WITH CHECK (public.is_school_staff());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'extra_video_items' AND policyname = 'extra_video_items_staff_all') THEN
    CREATE POLICY extra_video_items_staff_all ON public.extra_video_items
      FOR ALL USING (public.is_school_staff()) WITH CHECK (public.is_school_staff());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'student_extra_purchases' AND policyname = 'student_extra_purchases_select_own') THEN
    CREATE POLICY student_extra_purchases_select_own ON public.student_extra_purchases
      FOR SELECT USING (public.is_own_student(student_id) OR public.is_school_staff());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'student_extra_purchases' AND policyname = 'student_extra_purchases_staff_all') THEN
    CREATE POLICY student_extra_purchases_staff_all ON public.student_extra_purchases
      FOR ALL USING (public.is_school_staff()) WITH CHECK (public.is_school_staff());
  END IF;
END
$$;

-- ---------------------------------------------------------------------------
-- Storage buckets and policies
-- ---------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public)
VALUES
  ('student-documents', 'student-documents', false),
  ('student-photos', 'student-photos', false)
ON CONFLICT (id) DO NOTHING;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'student_documents_staff_select') THEN
    CREATE POLICY student_documents_staff_select ON storage.objects
      FOR SELECT USING (bucket_id = 'student-documents' AND public.is_school_staff());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'student_documents_staff_insert') THEN
    CREATE POLICY student_documents_staff_insert ON storage.objects
      FOR INSERT WITH CHECK (bucket_id = 'student-documents' AND public.is_school_staff());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'student_documents_staff_update') THEN
    CREATE POLICY student_documents_staff_update ON storage.objects
      FOR UPDATE USING (bucket_id = 'student-documents' AND public.is_school_staff()) WITH CHECK (bucket_id = 'student-documents' AND public.is_school_staff());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'student_documents_staff_delete') THEN
    CREATE POLICY student_documents_staff_delete ON storage.objects
      FOR DELETE USING (bucket_id = 'student-documents' AND public.is_school_staff());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'student_photos_staff_select') THEN
    CREATE POLICY student_photos_staff_select ON storage.objects
      FOR SELECT USING (bucket_id = 'student-photos' AND public.is_school_staff());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'student_photos_staff_insert') THEN
    CREATE POLICY student_photos_staff_insert ON storage.objects
      FOR INSERT WITH CHECK (bucket_id = 'student-photos' AND public.is_school_staff());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'student_photos_staff_update') THEN
    CREATE POLICY student_photos_staff_update ON storage.objects
      FOR UPDATE USING (bucket_id = 'student-photos' AND public.is_school_staff()) WITH CHECK (bucket_id = 'student-photos' AND public.is_school_staff());
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'student_photos_staff_delete') THEN
    CREATE POLICY student_photos_staff_delete ON storage.objects
      FOR DELETE USING (bucket_id = 'student-photos' AND public.is_school_staff());
  END IF;
END
$$;

-- ---------------------------------------------------------------------------
-- Atomic/idempotent payment registration RPC
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.record_payment(
  p_student_id uuid,
  p_amount_cents integer,
  p_method text,
  p_received_at timestamptz,
  p_notes text DEFAULT NULL,
  p_receipt_reference text DEFAULT NULL,
  p_activity_title text DEFAULT 'Pagamento registrato',
  p_activity_description text DEFAULT NULL,
  p_idempotency_key text DEFAULT NULL,
  p_source text DEFAULT 'school',
  p_category text DEFAULT 'patente'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_payment_id uuid;
  v_registration_fee_cents integer;
  v_total_paid_cents integer;
  v_currency_code text;
  v_new_total integer;
  v_new_remaining integer;
  v_idempotency_key text;
  v_source public.payment_source;
  v_category public.payment_category;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  IF NOT public.is_school_staff() THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  IF p_student_id IS NULL THEN
    RAISE EXCEPTION 'student_id_required';
  END IF;

  IF p_amount_cents IS NULL OR p_amount_cents <= 0 THEN
    RAISE EXCEPTION 'amount_cents_must_be_positive';
  END IF;

  IF p_method IS NULL OR p_method NOT IN (
    'card', 'sepaBankTransfer', 'cash', 'check', 'other'
  ) THEN
    RAISE EXCEPTION 'invalid_payment_method';
  END IF;

  IF p_received_at IS NULL THEN
    RAISE EXCEPTION 'received_at_required';
  END IF;

  IF p_source IS NULL OR p_source NOT IN ('school', 'online') THEN
    RAISE EXCEPTION 'invalid_payment_source';
  END IF;

  IF p_category IS NULL OR p_category NOT IN ('patente', 'extra') THEN
    RAISE EXCEPTION 'invalid_payment_category';
  END IF;

  v_source := p_source::public.payment_source;
  v_category := p_category::public.payment_category;
  v_idempotency_key := nullif(trim(p_idempotency_key), '');

  IF v_idempotency_key IS NOT NULL THEN
    SELECT id
    INTO v_payment_id
    FROM public.payments
    WHERE idempotency_key = v_idempotency_key;

    IF FOUND THEN
      RETURN jsonb_build_object(
        'status', 'already_recorded',
        'idempotent', true,
        'payment_id', v_payment_id
      );
    END IF;
  END IF;

  INSERT INTO public.student_financial_summaries (
    student_id,
    registration_fee_cents,
    currency_code,
    total_paid_cents,
    remaining_balance_cents,
    last_updated_at
  )
  VALUES (
    p_student_id,
    0,
    'EUR',
    0,
    0,
    now()
  )
  ON CONFLICT (student_id) DO NOTHING;

  SELECT
    registration_fee_cents,
    total_paid_cents,
    currency_code
  INTO
    v_registration_fee_cents,
    v_total_paid_cents,
    v_currency_code
  FROM public.student_financial_summaries
  WHERE student_id = p_student_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'financial_summary_not_found';
  END IF;

  IF v_idempotency_key IS NOT NULL THEN
    SELECT id
    INTO v_payment_id
    FROM public.payments
    WHERE idempotency_key = v_idempotency_key;

    IF FOUND THEN
      RETURN jsonb_build_object(
        'status', 'already_recorded',
        'idempotent', true,
        'payment_id', v_payment_id
      );
    END IF;
  END IF;

  v_new_total := v_total_paid_cents + p_amount_cents;
  v_new_remaining := greatest(v_registration_fee_cents - v_new_total, 0);

  INSERT INTO public.payments (
    student_id,
    amount,
    paid_at,
    amount_cents,
    currency_code,
    received_at,
    method,
    source,
    category,
    receipt_reference,
    notes,
    recorded_by_staff_id,
    idempotency_key
  )
  VALUES (
    p_student_id,
    p_amount_cents::numeric / 100,
    p_received_at,
    p_amount_cents,
    v_currency_code,
    p_received_at,
    p_method,
    v_source,
    v_category,
    p_receipt_reference,
    p_notes,
    auth.uid(),
    v_idempotency_key
  )
  ON CONFLICT (idempotency_key) WHERE idempotency_key IS NOT NULL
  DO NOTHING
  RETURNING id INTO v_payment_id;

  IF v_payment_id IS NULL THEN
    SELECT id
    INTO v_payment_id
    FROM public.payments
    WHERE idempotency_key = v_idempotency_key;

    IF v_payment_id IS NULL THEN
      RAISE EXCEPTION 'payment_insert_failed';
    END IF;

    RETURN jsonb_build_object(
      'status', 'already_recorded',
      'idempotent', true,
      'payment_id', v_payment_id
    );
  END IF;

  UPDATE public.student_financial_summaries
  SET
    total_paid_cents = v_new_total,
    remaining_balance_cents = v_new_remaining,
    last_updated_at = now()
  WHERE student_id = p_student_id;

  INSERT INTO public.backoffice_activity_events (
    student_id,
    event_type,
    title,
    description,
    actor_staff_id,
    occurred_at
  )
  VALUES (
    p_student_id,
    'paymentAdded',
    coalesce(nullif(trim(p_activity_title), ''), 'Pagamento registrato'),
    p_activity_description,
    auth.uid(),
    now()
  );

  RETURN jsonb_build_object(
    'status', 'recorded',
    'idempotent', false,
    'payment_id', v_payment_id,
    'student_id', p_student_id,
    'total_paid_cents', v_new_total,
    'remaining_balance_cents', v_new_remaining
  );
END;
$$;

COMMENT ON FUNCTION public.record_payment(
  uuid, integer, text, timestamptz, text, text, text, text, text, text, text
) IS
  'Registra pagamento idempotente e aggiorna student_financial_summaries in modo atomico con SELECT FOR UPDATE.';

GRANT EXECUTE ON FUNCTION public.record_payment(
  uuid, integer, text, timestamptz, text, text, text, text, text, text, text
) TO authenticated;

-- ---------------------------------------------------------------------------
-- Seed iniziali
-- ---------------------------------------------------------------------------
INSERT INTO public.instructors (display_name, slug)
VALUES
  ('Vincenzo Scibile', 'vincenzo-scibile'),
  ('Vincenzo Lomiento', 'vincenzo-lomiento'),
  ('Luigi Visalli', 'luigi-visalli')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.expense_categories (name, slug, sort_order)
VALUES
  ('benzina', 'benzina', 10),
  ('pagamento istruttori', 'pagamento-istruttori', 20),
  ('affitto pontile', 'affitto-pontile', 30),
  ('tagliando', 'tagliando', 40),
  ('manutenzione', 'manutenzione', 50),
  ('altro manuale', 'altro-manuale', 60)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.extra_products (
  id,
  title,
  subtitle,
  description,
  price_cents,
  sort_order
)
VALUES
  (
    'ex-theory',
    'Video corso lezioni teoriche',
    'Corso video dedicato alla preparazione teorica nautica.',
    'Lezioni teoriche in video per affiancare corso in aula e ripasso.',
    4900,
    10
  ),
  (
    'ex-drive',
    'Video preparazione esame di guida',
    'Contenuti video dedicati alla preparazione della prova pratica/guida.',
    'Esercitazione e approccio all''esame pratico e alla guida in mare.',
    3900,
    20
  ),
  (
    'ex-chart',
    'Video corso carteggio',
    'Percorso video dedicato al carteggio nautico e agli esercizi pratici.',
    'Carteggio: strumenti, tracciamento, lettura carta.',
    3500,
    30
  ),
  (
    'ex-bundle',
    'Pacchetto completo',
    'Comprende teoria, guida e carteggio.',
    'Accesso a tutti i percorsi video: teoria, guida, carteggio in un''unica offerta.',
    9900,
    40
  )
ON CONFLICT (id) DO NOTHING;

-- =============================================================================
-- Fine migration production management foundation compatibility
-- =============================================================================
