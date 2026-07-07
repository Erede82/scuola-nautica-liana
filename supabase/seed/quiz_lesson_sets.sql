-- =============================================================================
-- P9C.3-B — Seed quiz_sets + quiz_set_items per schede lezione A12 / D1
-- =============================================================================
-- PREREQUISITI (applicare prima, con approvazione):
--   1. Migration 20260707120000_quiz_lesson_sheets_attempts.sql
--   2. Tabella questions già popolata (read-only in produzione)
--
-- NON eseguire su DB remoto senza approvazione esplicita.
-- Idempotente:
--   quiz_sets      → WHERE NOT EXISTS (anti-join): l'unicità è su indice UNIQUE
--                    parziale quiz_sets_lesson_sheet_uq — PostgreSQL non inferisce
--                    ON CONFLICT (kind, license_category, lesson_number, sheet_number).
--   quiz_set_items → ON CONFLICT (quiz_set_id, question_id) DO NOTHING (PK esistente)
--
-- Algoritmo domande per scheda (allineato a sliceLessonSheetQuestions in Flutter):
--   start = ((sheet_number - 1) * 20) % pool_size
--   count = LEAST(20, pool_size)
--   position i → pool[1 + mod(start + i - 1, pool_size)]  (array PostgreSQL 1-based)
--
-- Catalogo schede: lib/data/license_catalog.dart (patenteMotore.lessons[].quizSheets)
-- Categorie seed: A12 (motore), D1

BEGIN;

-- ---------------------------------------------------------------------------
-- 1) quiz_sets
-- ---------------------------------------------------------------------------
WITH lesson_catalog (lesson_number, sheet_count) AS (
  VALUES
    (1, 24),
    (2, 24),
    (3, 24),
    (4, 28),
    (5, 20),
    (6, 20),
    (7, 36),
    (8, 20),
    (9, 20),
    (10, 16),
    (11, 28),
    (12, 16),
    (13, 16),
    (14, 36)
),
seed_categories (license_category, category_label) AS (
  VALUES
    ('A12', 'Patente a motore'),
    ('D1', 'Patente D1')
),
sheet_grid AS (
  SELECT
    sc.license_category,
    sc.category_label,
    lc.lesson_number,
    gs.sheet_number
  FROM seed_categories sc
  CROSS JOIN lesson_catalog lc
  CROSS JOIN LATERAL generate_series(1, lc.sheet_count) AS gs(sheet_number)
),
question_pools AS (
  SELECT
    q.license_category,
    q.lesson_number,
    array_agg(q.id ORDER BY q.id) AS pool
  FROM public.questions q
  WHERE q.lesson_number IS NOT NULL
    AND q.license_category IN ('A12', 'D1')
  GROUP BY q.license_category, q.lesson_number
  HAVING count(*) > 0
)
INSERT INTO public.quiz_sets (
  title,
  category,
  lesson_number,
  kind,
  license_category,
  sheet_number
)
SELECT
  format('Lezione %s — Scheda %s', sg.lesson_number, sg.sheet_number),
  sg.category_label,
  sg.lesson_number,
  'lesson',
  sg.license_category,
  sg.sheet_number
FROM sheet_grid sg
INNER JOIN question_pools qp
  ON qp.license_category = sg.license_category
 AND qp.lesson_number = sg.lesson_number
WHERE NOT EXISTS (
  SELECT 1
  FROM public.quiz_sets qs
  WHERE qs.kind = 'lesson'
    AND qs.license_category = sg.license_category
    AND qs.lesson_number = sg.lesson_number
    AND qs.sheet_number = sg.sheet_number
);

-- ---------------------------------------------------------------------------
-- 2) quiz_set_items
-- ---------------------------------------------------------------------------
WITH lesson_catalog (lesson_number, sheet_count) AS (
  VALUES
    (1, 24),
    (2, 24),
    (3, 24),
    (4, 28),
    (5, 20),
    (6, 20),
    (7, 36),
    (8, 20),
    (9, 20),
    (10, 16),
    (11, 28),
    (12, 16),
    (13, 16),
    (14, 36)
),
seed_categories (license_category) AS (
  VALUES ('A12'), ('D1')
),
sheet_grid AS (
  SELECT
    sc.license_category,
    lc.lesson_number,
    gs.sheet_number
  FROM seed_categories sc
  CROSS JOIN lesson_catalog lc
  CROSS JOIN LATERAL generate_series(1, lc.sheet_count) AS gs(sheet_number)
),
question_pools AS (
  SELECT
    q.license_category,
    q.lesson_number,
    array_agg(q.id ORDER BY q.id) AS pool
  FROM public.questions q
  WHERE q.lesson_number IS NOT NULL
    AND q.license_category IN ('A12', 'D1')
  GROUP BY q.license_category, q.lesson_number
  HAVING count(*) > 0
),
resolved_sets AS (
  SELECT
    qs.id AS quiz_set_id,
    qs.license_category,
    qs.lesson_number,
    qs.sheet_number
  FROM public.quiz_sets qs
  WHERE qs.kind = 'lesson'
    AND qs.license_category IN ('A12', 'D1')
    AND qs.sheet_number IS NOT NULL
),
item_rows AS (
  SELECT
    rs.quiz_set_id,
    qp.pool[
      1 + mod(
        (rs.sheet_number - 1) * 20 + pos.i - 1,
        array_length(qp.pool, 1)
      )
    ] AS question_id,
    pos.i AS position
  FROM resolved_sets rs
  INNER JOIN question_pools qp
    ON qp.license_category = rs.license_category
   AND qp.lesson_number = rs.lesson_number
  CROSS JOIN LATERAL generate_series(
    1,
    LEAST(20, array_length(qp.pool, 1))
  ) AS pos(i)
)
INSERT INTO public.quiz_set_items (quiz_set_id, question_id, position)
SELECT quiz_set_id, question_id, position
FROM item_rows
ON CONFLICT (quiz_set_id, question_id) DO NOTHING;

COMMIT;

-- ---------------------------------------------------------------------------
-- Verifica post-seed (opzionale, read-only)
-- ---------------------------------------------------------------------------
-- SELECT license_category, count(*) AS quiz_sets
-- FROM public.quiz_sets
-- WHERE kind = 'lesson' AND license_category IN ('A12', 'D1')
-- GROUP BY 1;
--
-- SELECT count(*) AS quiz_set_items
-- FROM public.quiz_set_items qsi
-- JOIN public.quiz_sets qs ON qs.id = qsi.quiz_set_id
-- WHERE qs.kind = 'lesson' AND qs.license_category IN ('A12', 'D1');
