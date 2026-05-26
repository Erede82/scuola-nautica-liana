-- =============================================================================
-- Management foundation: nautica operations, accounting expenses, Extra purchases
-- =============================================================================
-- Incremental and idempotent. Reuses existing students, practice_dossiers,
-- guidance_appointments, student_financial_summaries, backoffice_activity_events
-- and record_payment when those migrations are applied.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Istruttori
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

-- ---------------------------------------------------------------------------
-- Contabilita: categorie uscite e uscite
-- ---------------------------------------------------------------------------
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
  payment_method text NOT NULL DEFAULT 'other'
    CHECK (payment_method IN ('card', 'sepaBankTransfer', 'cash', 'check', 'other')),
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
-- Documenti e foto allievo
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.student_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id uuid NOT NULL REFERENCES public.students (id) ON DELETE CASCADE,
  practice_dossier_id uuid REFERENCES public.practice_dossiers (id) ON DELETE SET NULL,
  document_type text NOT NULL DEFAULT 'other'
    CHECK (document_type IN (
      'identityCard', 'taxCode', 'medicalCertificate', 'photo',
      'privacyForm', 'paymentReceipt', 'practiceForm', 'other'
    )),
  title text NOT NULL,
  storage_path text,
  file_name text,
  mime_type text,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'uploaded', 'verified', 'rejected', 'expired')),
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
  photo_kind text NOT NULL DEFAULT 'profile'
    CHECK (photo_kind IN ('profile', 'document', 'license', 'other')),
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
-- Extra: prodotti, video e acquisti allievo
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
  status text NOT NULL DEFAULT 'purchased'
    CHECK (status IN ('pending', 'purchased', 'refunded', 'revoked')),
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
-- updated_at triggers
-- ---------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_instructors_updated ON public.instructors;
CREATE TRIGGER trg_instructors_updated
  BEFORE UPDATE ON public.instructors
  FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();

DROP TRIGGER IF EXISTS trg_expense_categories_updated ON public.expense_categories;
CREATE TRIGGER trg_expense_categories_updated
  BEFORE UPDATE ON public.expense_categories
  FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();

DROP TRIGGER IF EXISTS trg_expenses_updated ON public.expenses;
CREATE TRIGGER trg_expenses_updated
  BEFORE UPDATE ON public.expenses
  FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();

DROP TRIGGER IF EXISTS trg_fuel_logs_updated ON public.fuel_logs;
CREATE TRIGGER trg_fuel_logs_updated
  BEFORE UPDATE ON public.fuel_logs
  FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();

DROP TRIGGER IF EXISTS trg_student_documents_updated ON public.student_documents;
CREATE TRIGGER trg_student_documents_updated
  BEFORE UPDATE ON public.student_documents
  FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();

DROP TRIGGER IF EXISTS trg_student_photos_updated ON public.student_photos;
CREATE TRIGGER trg_student_photos_updated
  BEFORE UPDATE ON public.student_photos
  FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();

DROP TRIGGER IF EXISTS trg_extra_products_updated ON public.extra_products;
CREATE TRIGGER trg_extra_products_updated
  BEFORE UPDATE ON public.extra_products
  FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();

DROP TRIGGER IF EXISTS trg_extra_video_items_updated ON public.extra_video_items;
CREATE TRIGGER trg_extra_video_items_updated
  BEFORE UPDATE ON public.extra_video_items
  FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();

DROP TRIGGER IF EXISTS trg_student_extra_purchases_updated ON public.student_extra_purchases;
CREATE TRIGGER trg_student_extra_purchases_updated
  BEFORE UPDATE ON public.student_extra_purchases
  FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
ALTER TABLE public.instructors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expense_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fuel_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.extra_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.extra_video_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_extra_purchases ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS instructors_staff_all ON public.instructors;
CREATE POLICY instructors_staff_all ON public.instructors
  FOR ALL USING (public.is_school_staff()) WITH CHECK (public.is_school_staff());

DROP POLICY IF EXISTS expense_categories_staff_all ON public.expense_categories;
CREATE POLICY expense_categories_staff_all ON public.expense_categories
  FOR ALL USING (public.is_school_staff()) WITH CHECK (public.is_school_staff());

DROP POLICY IF EXISTS expenses_staff_all ON public.expenses;
CREATE POLICY expenses_staff_all ON public.expenses
  FOR ALL USING (public.is_school_staff()) WITH CHECK (public.is_school_staff());

DROP POLICY IF EXISTS fuel_logs_staff_all ON public.fuel_logs;
CREATE POLICY fuel_logs_staff_all ON public.fuel_logs
  FOR ALL USING (public.is_school_staff()) WITH CHECK (public.is_school_staff());

DROP POLICY IF EXISTS student_documents_staff_all ON public.student_documents;
CREATE POLICY student_documents_staff_all ON public.student_documents
  FOR ALL USING (public.is_school_staff()) WITH CHECK (public.is_school_staff());

DROP POLICY IF EXISTS student_photos_staff_all ON public.student_photos;
CREATE POLICY student_photos_staff_all ON public.student_photos
  FOR ALL USING (public.is_school_staff()) WITH CHECK (public.is_school_staff());

DROP POLICY IF EXISTS extra_products_select_active ON public.extra_products;
CREATE POLICY extra_products_select_active ON public.extra_products
  FOR SELECT USING (active OR public.is_school_staff());

DROP POLICY IF EXISTS extra_products_staff_all ON public.extra_products;
CREATE POLICY extra_products_staff_all ON public.extra_products
  FOR ALL USING (public.is_school_staff()) WITH CHECK (public.is_school_staff());

DROP POLICY IF EXISTS extra_video_items_select_purchased ON public.extra_video_items;
CREATE POLICY extra_video_items_select_purchased ON public.extra_video_items
  FOR SELECT USING (
    public.is_school_staff()
    OR EXISTS (
      SELECT 1
      FROM public.student_extra_purchases sep
      WHERE sep.product_id = extra_video_items.product_id
        AND sep.status = 'purchased'
        AND public.is_own_student(sep.student_id)
    )
  );

DROP POLICY IF EXISTS extra_video_items_staff_all ON public.extra_video_items;
CREATE POLICY extra_video_items_staff_all ON public.extra_video_items
  FOR ALL USING (public.is_school_staff()) WITH CHECK (public.is_school_staff());

DROP POLICY IF EXISTS student_extra_purchases_select_own ON public.student_extra_purchases;
CREATE POLICY student_extra_purchases_select_own ON public.student_extra_purchases
  FOR SELECT USING (public.is_own_student(student_id) OR public.is_school_staff());

-- Fase 1: consente al checkout UI attuale di rendere persistente l'acquisto.
-- Da sostituire con RPC/payment webhook quando ci sara un PSP reale.
DROP POLICY IF EXISTS student_extra_purchases_student_insert_own ON public.student_extra_purchases;
CREATE POLICY student_extra_purchases_student_insert_own ON public.student_extra_purchases
  FOR INSERT WITH CHECK (public.is_own_student(student_id));

DROP POLICY IF EXISTS student_extra_purchases_student_update_own ON public.student_extra_purchases;
CREATE POLICY student_extra_purchases_student_update_own ON public.student_extra_purchases
  FOR UPDATE USING (public.is_own_student(student_id)) WITH CHECK (public.is_own_student(student_id));

DROP POLICY IF EXISTS student_extra_purchases_staff_all ON public.student_extra_purchases;
CREATE POLICY student_extra_purchases_staff_all ON public.student_extra_purchases
  FOR ALL USING (public.is_school_staff()) WITH CHECK (public.is_school_staff());

-- ---------------------------------------------------------------------------
-- Seed iniziali
-- ---------------------------------------------------------------------------
INSERT INTO public.instructors (display_name, slug)
VALUES
  ('Vincenzo Scibile', 'vincenzo-scibile'),
  ('Vincenzo Lomiento', 'vincenzo-lomiento'),
  ('Luigi Visalli', 'luigi-visalli')
ON CONFLICT (slug) DO UPDATE
SET
  display_name = EXCLUDED.display_name,
  active = true,
  updated_at = now();

INSERT INTO public.expense_categories (name, slug, sort_order)
VALUES
  ('benzina', 'benzina', 10),
  ('pagamento istruttori', 'pagamento-istruttori', 20),
  ('affitto pontile', 'affitto-pontile', 30),
  ('tagliando', 'tagliando', 40),
  ('manutenzione', 'manutenzione', 50),
  ('altro manuale', 'altro-manuale', 60)
ON CONFLICT (slug) DO UPDATE
SET
  name = EXCLUDED.name,
  sort_order = EXCLUDED.sort_order,
  active = true,
  updated_at = now();

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
ON CONFLICT (id) DO UPDATE
SET
  title = EXCLUDED.title,
  subtitle = EXCLUDED.subtitle,
  description = EXCLUDED.description,
  price_cents = EXCLUDED.price_cents,
  sort_order = EXCLUDED.sort_order,
  active = true,
  updated_at = now();

-- =============================================================================
-- Fine migration management foundation
-- =============================================================================
