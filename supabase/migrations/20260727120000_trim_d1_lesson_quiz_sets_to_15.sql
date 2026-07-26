-- =============================================================================
-- P9F-D1.3-A — Trim schede lezione D1: 20 → 15 quiz_set_items
-- =============================================================================
-- Ambito: solo quiz_sets.kind = 'lesson' AND license_category = 'D1'
--         (valore DB domande/schede = 'D1', non 'd1' degli accessi studio).
--
-- Elimina esclusivamente quiz_set_items.position BETWEEN 16 AND 20.
-- Non tocca: quiz_sets, quiz_results, quiz_attempt_answers, questions, A12.
--
-- Storico: i tentativi già salvati (anche da 20 domande) restano intenzionalmente
-- invariati. quiz_attempt_answers non ha FK verso quiz_set_items; la DELETE
-- sugli item non cascada su risultati/risposte.
--
-- Idempotente / safe su DB vuoto (reset locale prima del seed → no-op).
-- Eseguita in transazione dal migrator Supabase: eccezioni ⇒ rollback completo.
-- =============================================================================

DO $$
DECLARE
  v_d1_set_count integer;
  v_invalid_sets integer;
  v_target_delete integer;
  v_deleted integer;
  v_bad_post integer;
BEGIN
  -- Scope esplicito: mai A12 / motore. Solo license_category = 'D1'.
  SELECT count(*)::integer
  INTO v_d1_set_count
  FROM public.quiz_sets qs
  WHERE qs.kind = 'lesson'
    AND qs.license_category = 'D1';

  IF v_d1_set_count = 0 THEN
    RAISE NOTICE
      'P9F-D1.3-A: nessun quiz_sets lesson D1 — no-op (DB vuoto o seed non ancora applicato).';
    RETURN;
  END IF;

  -- Precondition: ogni set D1 lesson deve essere 15×(1–15) oppure 20×(1–20).
  SELECT count(*)::integer
  INTO v_invalid_sets
  FROM (
    SELECT
      qs.id,
      count(i.question_id)::integer AS item_count,
      coalesce(min(i.position), 0)::integer AS min_pos,
      coalesce(max(i.position), 0)::integer AS max_pos,
      count(DISTINCT i.position)::integer AS distinct_pos,
      count(*) FILTER (
        WHERE i.position IS NOT NULL
          AND (i.position < 1 OR i.position > 20)
      )::integer AS out_of_range
    FROM public.quiz_sets qs
    LEFT JOIN public.quiz_set_items i ON i.quiz_set_id = qs.id
    WHERE qs.kind = 'lesson'
      AND qs.license_category = 'D1'
    GROUP BY qs.id
  ) s
  WHERE NOT (
    (
      s.item_count = 15
      AND s.min_pos = 1
      AND s.max_pos = 15
      AND s.distinct_pos = 15
      AND s.out_of_range = 0
    )
    OR (
      s.item_count = 20
      AND s.min_pos = 1
      AND s.max_pos = 20
      AND s.distinct_pos = 20
      AND s.out_of_range = 0
    )
  );

  IF v_invalid_sets > 0 THEN
    RAISE EXCEPTION
      'P9F-D1.3-A: % set D1 lesson in stato inatteso (attesi solo 15×1–15 o 20×1–20)',
      v_invalid_sets;
  END IF;

  SELECT count(*)::integer
  INTO v_target_delete
  FROM public.quiz_set_items i
  INNER JOIN public.quiz_sets qs ON qs.id = i.quiz_set_id
  WHERE qs.kind = 'lesson'
    AND qs.license_category = 'D1'
    AND i.position BETWEEN 16 AND 20;

  DELETE FROM public.quiz_set_items i
  USING public.quiz_sets qs
  WHERE i.quiz_set_id = qs.id
    AND qs.kind = 'lesson'
    AND qs.license_category = 'D1'
    AND i.position BETWEEN 16 AND 20;

  GET DIAGNOSTICS v_deleted = ROW_COUNT;

  IF v_deleted IS DISTINCT FROM v_target_delete THEN
    RAISE EXCEPTION
      'P9F-D1.3-A: delete mismatch (target=%, deleted=%)',
      v_target_delete,
      v_deleted;
  END IF;

  -- Postcondition: ogni set D1 lesson esistente ha esattamente posizioni 1–15.
  SELECT count(*)::integer
  INTO v_bad_post
  FROM (
    SELECT
      qs.id,
      count(i.question_id)::integer AS item_count,
      coalesce(min(i.position), 0)::integer AS min_pos,
      coalesce(max(i.position), 0)::integer AS max_pos,
      count(DISTINCT i.position)::integer AS distinct_pos,
      count(*) FILTER (
        WHERE i.position IS NOT NULL
          AND (i.position < 1 OR i.position > 15)
      )::integer AS out_of_range
    FROM public.quiz_sets qs
    LEFT JOIN public.quiz_set_items i ON i.quiz_set_id = qs.id
    WHERE qs.kind = 'lesson'
      AND qs.license_category = 'D1'
    GROUP BY qs.id
  ) s
  WHERE NOT (
    s.item_count = 15
    AND s.min_pos = 1
    AND s.max_pos = 15
    AND s.distinct_pos = 15
    AND s.out_of_range = 0
  );

  IF v_bad_post > 0 THEN
    RAISE EXCEPTION
      'P9F-D1.3-A: postcondition fallita su % set D1 (attesi 15 item, posizioni 1–15)',
      v_bad_post;
  END IF;

  RAISE NOTICE
    'P9F-D1.3-A: trim D1 lesson completato (sets=%, deleted_items=%)',
    v_d1_set_count,
    v_deleted;
END
$$;
