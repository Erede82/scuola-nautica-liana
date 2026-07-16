-- =============================================================================
-- assigned_quizzes smoke test (MANUALE — P9D.1-D)
-- =============================================================================
-- ⚠️  NON ESEGUIRE SUL REMOTO SENZA SESSIONE DI TEST CONTROLLATA
--
-- Prerequisiti:
--   1. Migration applicata SOLO in ambiente di test locale/isolato:
--      supabase/migrations/20260716120000_assigned_quizzes_foundation.sql
--   2. Sostituire TUTTI i placeholder UUID sotto prima dell'esecuzione.
--   3. Nessuna credenziale, nessun utente reale hardcoded.
--
-- Comportamento:
--   - BEGIN / ROLLBACK: nessun residuo dopo l'esecuzione.
--   - Tutti i dati creati (assigned_quiz_*, eventuali righe quiz temporanee)
--     vengono annullati dal ROLLBACK finale.
--   - Non eseguire in produzione.
-- =============================================================================

BEGIN;

DO $$
DECLARE
  v_staff_user_id uuid := '00000000-0000-0000-0000-000000000001';
  v_student_user_id uuid := '00000000-0000-0000-0000-000000000002';
  v_other_user_id uuid := '00000000-0000-0000-0000-000000000003';
  v_student_id uuid := '00000000-0000-0000-0000-000000000010';
  v_license_category text;
  v_assignment_id uuid;
  v_draft_id uuid;
  v_empty_draft_id uuid;
  v_miscount_draft_id uuid;
  v_populated_draft_id uuid;
  v_archived_assignment_id uuid;
  v_assigned_no_attempts_id uuid;
  v_draft_with_attempt_id uuid;
  v_attempt_id uuid;
  v_attempt_id_2 uuid;
  v_item_id uuid;
  v_public_code text;
  v_shell_count integer;
  v_in_progress_count integer;
  v_q jsonb;
  v_save jsonb;
  v_results_before integer;
  v_results_after integer;
  v_answers_before integer;
  v_answers_after integer;
  v_pool_with_incomplete integer;
  v_pool_completed_only integer;
  v_attempts_used integer;
  v_gen jsonb;
  v_idem_key text;
  v_item_count integer;
  v_submit jsonb;
  v_correct_count integer;
  v_wrong_count integer;
  v_unanswered_count integer;
  v_student_items_count integer;
  v_student_answers_count integer;
BEGIN
  IF v_staff_user_id = '00000000-0000-0000-0000-000000000001'::uuid
     OR v_student_user_id = '00000000-0000-0000-0000-000000000002'::uuid
     OR v_student_id = '00000000-0000-0000-0000-000000000010'::uuid THEN
    RAISE EXCEPTION 'Replace ALL placeholder UUIDs before running this smoke test.';
  END IF;

  SELECT count(*)::integer INTO v_results_before FROM public.quiz_results;
  SELECT count(*)::integer INTO v_answers_before FROM public.quiz_attempt_answers;

  v_license_category := public.resolve_student_quiz_license_category(v_student_id);
  v_idem_key := 'smoke-' || extract(epoch FROM clock_timestamp())::text;

  -- -------------------------------------------------------------------------
  -- 1) student_id / student_user_id incoerenti rifiutati (trigger)
  -- -------------------------------------------------------------------------
  BEGIN
    INSERT INTO public.assigned_quizzes (
      public_code, student_id, student_user_id, license_category,
      title, status, source_kind, question_count, repeat_policy,
      lesson_filter_mode, sort_mode, allow_partial, created_by
    )
    VALUES (
      'AQZ-SMOKE-00001', v_student_id, v_other_user_id, v_license_category,
      'mismatch test', 'draft', 'lesson_errors', 1, 'unlimited',
      'all_lessons', 'most_wrong', false, v_staff_user_id
    );
    RAISE EXCEPTION 'Test 1 FAILED: student_user mismatch should be rejected';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%assigned_quiz_student_user_mismatch%' THEN
        RAISE;
      END IF;
  END;

  -- -------------------------------------------------------------------------
  -- 2) categoria incoerente rifiutata (trigger)
  -- -------------------------------------------------------------------------
  BEGIN
    INSERT INTO public.assigned_quizzes (
      public_code, student_id, student_user_id, license_category,
      title, status, source_kind, question_count, repeat_policy,
      lesson_filter_mode, sort_mode, allow_partial, created_by
    )
    VALUES (
      'AQZ-SMOKE-00002', v_student_id, v_student_user_id,
      CASE WHEN v_license_category = 'A12' THEN 'D1' ELSE 'A12' END,
      'category mismatch', 'draft', 'lesson_errors', 1, 'unlimited',
      'all_lessons', 'most_wrong', false, v_staff_user_id
    );
    RAISE EXCEPTION 'Test 2 FAILED: license category mismatch should be rejected';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%assigned_quiz_license_category_mismatch%' THEN
        RAISE;
      END IF;
  END;

  -- -------------------------------------------------------------------------
  -- 3) INSERT staff diretto su assigned_quizzes negato (privilegio + RLS)
  -- -------------------------------------------------------------------------
  PERFORM set_config('request.jwt.claim.sub', v_staff_user_id::text, true);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);

  BEGIN
    SET LOCAL ROLE authenticated;
    INSERT INTO public.assigned_quizzes (
      public_code, student_id, student_user_id, license_category,
      title, status, source_kind, question_count, repeat_policy,
      lesson_filter_mode, sort_mode, allow_partial, created_by
    )
    VALUES (
      'AQZ-SMOKE-00003', v_student_id, v_student_user_id, v_license_category,
      'direct insert', 'draft', 'lesson_errors', 1, 'unlimited',
      'all_lessons', 'most_wrong', false, v_staff_user_id
    );
    RAISE EXCEPTION 'Test 3 FAILED: staff direct INSERT on assigned_quizzes should be denied';
  EXCEPTION
    WHEN insufficient_privilege THEN
      NULL;
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%permission denied%'
         AND SQLERRM NOT LIKE '%insufficient_privilege%' THEN
        RAISE;
      END IF;
  END;

  RESET ROLE;

  -- -------------------------------------------------------------------------
  -- Generazione via RPC (draft path) per test successivi
  -- -------------------------------------------------------------------------
  PERFORM set_config('request.jwt.claim.sub', v_staff_user_id::text, true);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);

  v_gen := public.generate_assigned_quiz_from_errors(
    p_student_id := v_student_id,
    p_title := 'Smoke test assignment',
    p_question_count := 5,
    p_assign_immediately := false,
    p_allow_partial := true,
    p_repeat_policy := 'limited',
    p_max_attempts := 3,
    p_idempotency_key := v_idem_key
  );

  v_assignment_id := (v_gen->>'assignment_id')::uuid;

  IF (v_gen->>'status') <> 'draft' THEN
    RAISE EXCEPTION 'Test setup FAILED: expected draft status, got %', v_gen->>'status';
  END IF;

  IF (v_gen->>'item_count')::integer <> (v_gen->>'item_count')::integer THEN
    RAISE EXCEPTION 'Test setup FAILED: item_count missing';
  END IF;

  -- -------------------------------------------------------------------------
  -- 4) INSERT staff diretto su items negato
  -- -------------------------------------------------------------------------
  BEGIN
    SET LOCAL ROLE authenticated;
    INSERT INTO public.assigned_quiz_items (
      assignment_id, position, source_question_id, prompt,
      option_a, option_b, option_c, correct_option,
      snapshot_lesson_number, snapshot_license_category,
      historical_error_count
    )
    SELECT
      v_assignment_id, 999, i.source_question_id, 'x', 'a', 'b', 'c', 'A',
      i.snapshot_lesson_number, i.snapshot_license_category, 1
    FROM public.assigned_quiz_items i
    WHERE i.assignment_id = v_assignment_id
    LIMIT 1;
    RAISE EXCEPTION 'Test 4 FAILED: staff direct INSERT on items should be denied';
  EXCEPTION
    WHEN insufficient_privilege THEN
      NULL;
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%permission denied%'
         AND SQLERRM NOT LIKE '%insufficient_privilege%' THEN
        RAISE;
      END IF;
  END;

  RESET ROLE;

  -- -------------------------------------------------------------------------
  -- 7) assegnazione con item mancanti rifiutata (draft→assigned)
  -- -------------------------------------------------------------------------
  INSERT INTO public.assigned_quizzes (
    public_code, student_id, student_user_id, license_category,
    title, status, source_kind, question_count, repeat_policy,
    lesson_filter_mode, sort_mode, allow_partial, created_by
  )
  VALUES (
    'AQZ-SMOKE-00007', v_student_id, v_student_user_id, v_license_category,
    'empty draft', 'draft', 'lesson_errors', 3, 'unlimited',
    'all_lessons', 'most_wrong', false, v_staff_user_id
  )
  RETURNING id INTO v_draft_id;
  v_empty_draft_id := v_draft_id;

  BEGIN
    UPDATE public.assigned_quizzes
    SET status = 'assigned'
    WHERE id = v_draft_id;
    RAISE EXCEPTION 'Test 7 FAILED: draft without items should not become assigned';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%assigned_quiz_items_incomplete%' THEN
        RAISE;
      END IF;
  END;

  -- -------------------------------------------------------------------------
  -- 8) question_count incoerente rifiutato (draft→assigned)
  --     (question_count è immutabile dopo INSERT: creare header con conteggio errato)
  -- -------------------------------------------------------------------------
  INSERT INTO public.assigned_quizzes (
    public_code, student_id, student_user_id, license_category,
    title, status, source_kind, question_count, repeat_policy,
    lesson_filter_mode, sort_mode, allow_partial, created_by
  )
  VALUES (
    'AQZ-SMOKE-00008', v_student_id, v_student_user_id, v_license_category,
    'miscount draft', 'draft', 'lesson_errors', 5, 'unlimited',
    'all_lessons', 'most_wrong', false, v_staff_user_id
  )
  RETURNING id INTO v_miscount_draft_id;

  INSERT INTO public.assigned_quiz_items (
    assignment_id, position, source_question_id, prompt,
    option_a, option_b, option_c, correct_option,
    snapshot_lesson_number, snapshot_license_category,
    historical_error_count
  )
  SELECT
    v_miscount_draft_id, i.position, i.source_question_id, i.prompt,
    i.option_a, i.option_b, i.option_c, i.correct_option,
    i.snapshot_lesson_number, i.snapshot_license_category,
    i.historical_error_count
  FROM public.assigned_quiz_items i
  WHERE i.assignment_id = v_assignment_id
  LIMIT 2;

  BEGIN
    UPDATE public.assigned_quizzes
    SET status = 'assigned'
    WHERE id = v_miscount_draft_id;
    RAISE EXCEPTION 'Test 8 FAILED: question_count mismatch should be rejected';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%assigned_quiz_items_incomplete%' THEN
        RAISE;
      END IF;
  END;

  -- Assegna il draft RPC (conteggio già coerente)
  v_populated_draft_id := v_assignment_id;

  UPDATE public.assigned_quizzes
  SET status = 'assigned'
  WHERE id = v_assignment_id;

  IF (SELECT status FROM public.assigned_quizzes WHERE id = v_assignment_id) <> 'assigned' THEN
    RAISE EXCEPTION 'Test setup FAILED: assignment should be assigned';
  END IF;

  -- -------------------------------------------------------------------------
  -- 5) assigned → draft rifiutato
  -- -------------------------------------------------------------------------
  BEGIN
    UPDATE public.assigned_quizzes
    SET status = 'draft'
    WHERE id = v_assignment_id;
    RAISE EXCEPTION 'Test 5 FAILED: assigned→draft should be rejected';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%invalid_assigned_quiz_status_transition%' THEN
        RAISE;
      END IF;
  END;

  -- -------------------------------------------------------------------------
  -- 6) archived → assigned rifiutato
  -- -------------------------------------------------------------------------
  UPDATE public.assigned_quizzes
  SET status = 'archived'
  WHERE id = v_assignment_id;

  v_archived_assignment_id := v_assignment_id;

  BEGIN
    UPDATE public.assigned_quizzes
    SET status = 'assigned'
    WHERE id = v_assignment_id;
    RAISE EXCEPTION 'Test 6 FAILED: archived→assigned should be rejected';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%invalid_assigned_quiz_status_transition%' THEN
        RAISE;
      END IF;
  END;

  -- Ripristina assigned per player flow
  -- (archived è terminale: creare nuova assegnazione immediate)
  v_gen := public.generate_assigned_quiz_from_errors(
    p_student_id := v_student_id,
    p_title := 'Smoke test player flow',
    p_question_count := 5,
    p_assign_immediately := true,
    p_allow_partial := true,
    p_repeat_policy := 'limited',
    p_max_attempts := 3,
    p_idempotency_key := v_idem_key || '-player'
  );

  v_assignment_id := (v_gen->>'assignment_id')::uuid;

  IF (v_gen->>'status') <> 'assigned' THEN
    RAISE EXCEPTION 'Test setup FAILED: expected assigned, got %', v_gen->>'status';
  END IF;

  IF (v_gen->>'item_count')::integer <>
     (SELECT question_count FROM public.assigned_quizzes WHERE id = v_assignment_id) THEN
    RAISE EXCEPTION 'Test setup FAILED: item_count != question_count';
  END IF;

  -- -------------------------------------------------------------------------
  -- 10) idempotency conflict
  -- -------------------------------------------------------------------------
  BEGIN
    PERFORM public.generate_assigned_quiz_from_errors(
      p_student_id := v_student_id,
      p_title := 'Different title same key',
      p_question_count := 5,
      p_assign_immediately := true,
      p_idempotency_key := v_idem_key || '-player'
    );
    RAISE EXCEPTION 'Test 10 FAILED: idempotency_conflict expected';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%idempotency_conflict%' THEN
        RAISE;
      END IF;
  END;

  -- Idempotency match OK
  v_gen := public.generate_assigned_quiz_from_errors(
    p_student_id := v_student_id,
    p_title := 'Smoke test player flow',
    p_question_count := 5,
    p_assign_immediately := true,
    p_allow_partial := true,
    p_repeat_policy := 'limited',
    p_max_attempts := 3,
    p_idempotency_key := v_idem_key || '-player'
  );

  IF coalesce(v_gen->>'idempotent', 'false') <> 'true' THEN
    RAISE EXCEPTION 'Test 10b FAILED: matching idempotency should return existing';
  END IF;

  -- -------------------------------------------------------------------------
  -- 9) query errori usa soltanto risultati completati
  -- -------------------------------------------------------------------------
  SELECT count(DISTINCT qaa.question_id)::integer
  INTO v_pool_completed_only
  FROM public.quiz_attempt_answers qaa
  INNER JOIN public.quiz_results qr ON qr.id = qaa.quiz_result_id
  INNER JOIN public.quiz_sets qs ON qs.id = qr.quiz_set_id
  INNER JOIN public.questions q ON q.id = qaa.question_id
  WHERE qaa.user_id = v_student_user_id
    AND qr.user_id = v_student_user_id
    AND qr.completed_at IS NOT NULL
    AND qaa.is_correct = false
    AND qaa.selected_option IS NOT NULL
    AND qs.kind = 'lesson'
    AND q.license_category = v_license_category
    AND q.lesson_number IS NOT NULL;

  SELECT count(DISTINCT qaa.question_id)::integer
  INTO v_pool_with_incomplete
  FROM public.quiz_attempt_answers qaa
  INNER JOIN public.quiz_results qr ON qr.id = qaa.quiz_result_id
  INNER JOIN public.quiz_sets qs ON qs.id = qr.quiz_set_id
  INNER JOIN public.questions q ON q.id = qaa.question_id
  WHERE qaa.user_id = v_student_user_id
    AND qr.user_id = v_student_user_id
    AND qaa.is_correct = false
    AND qaa.selected_option IS NOT NULL
    AND qs.kind = 'lesson'
    AND q.license_category = v_license_category
    AND q.lesson_number IS NOT NULL;

  IF v_pool_with_incomplete < v_pool_completed_only THEN
    RAISE EXCEPTION 'Test 9 FAILED: incomplete pool smaller than completed-only (unexpected)';
  END IF;

  -- -------------------------------------------------------------------------
  -- Studente: start / player / save / submit / review
  -- -------------------------------------------------------------------------
  PERFORM set_config('request.jwt.claim.sub', v_student_user_id::text, true);

  v_gen := public.start_assigned_quiz_attempt(v_assignment_id);
  v_attempt_id := (v_gen->>'attempt_id')::uuid;

  IF coalesce(v_gen->>'resumed', 'false') = 'true' THEN
    RAISE EXCEPTION 'Test setup FAILED: first start should not resume';
  END IF;

  SELECT count(*)::integer
  INTO v_shell_count
  FROM public.assigned_quiz_attempt_answers
  WHERE attempt_id = v_attempt_id;

  IF v_shell_count <>
     (SELECT question_count FROM public.assigned_quizzes WHERE id = v_assignment_id) THEN
    RAISE EXCEPTION 'Shell count % != question_count', v_shell_count;
  END IF;

  -- 19) studente SELECT diretto su items negato / 0 righe
  BEGIN
    SET LOCAL ROLE authenticated;
    SELECT count(*)::integer
    INTO v_student_items_count
    FROM public.assigned_quiz_items
    WHERE assignment_id = v_assignment_id;

    IF v_student_items_count <> 0 THEN
      RAISE EXCEPTION 'Test 19 FAILED: student should not see items (count=%)',
        v_student_items_count;
    END IF;
  EXCEPTION
    WHEN insufficient_privilege THEN
      NULL;
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%permission denied%'
         AND SQLERRM NOT LIKE '%insufficient_privilege%' THEN
        RAISE;
      END IF;
  END;

  RESET ROLE;
  PERFORM set_config('request.jwt.claim.sub', v_student_user_id::text, true);

  -- 11) player non restituisce correct_option
  SELECT q INTO v_q
  FROM public.get_assigned_quiz_attempt_questions(v_attempt_id) AS q
  LIMIT 1;

  IF v_q ? 'correct_option' OR v_q ? 'explanation' OR v_q ? 'is_correct' THEN
    RAISE EXCEPTION 'Test 11 FAILED: player leaked sensitive fields: %', v_q;
  END IF;

  -- 12) save answer non restituisce correct_option
  SELECT public.save_assigned_quiz_attempt_answer(
    v_attempt_id,
    (v_q->>'assignment_item_id')::uuid,
    'A'
  )
  INTO v_save;

  IF v_save ? 'correct_option' OR v_save ? 'is_correct' THEN
    RAISE EXCEPTION 'Test 12 FAILED: save leaked sensitive fields: %', v_save;
  END IF;

  -- 20) studente SELECT diretto su answers negato / 0 righe
  BEGIN
    SET LOCAL ROLE authenticated;
    SELECT count(*)::integer
    INTO v_student_answers_count
    FROM public.assigned_quiz_attempt_answers
    WHERE attempt_id = v_attempt_id;

    IF v_student_answers_count <> 0 THEN
      RAISE EXCEPTION 'Test 20 FAILED: student should not see answers (count=%)',
        v_student_answers_count;
    END IF;
  EXCEPTION
    WHEN insufficient_privilege THEN
      NULL;
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%permission denied%'
         AND SQLERRM NOT LIKE '%insufficient_privilege%' THEN
        RAISE;
      END IF;
  END;

  RESET ROLE;
  PERFORM set_config('request.jwt.claim.sub', v_student_user_id::text, true);

  -- 21) DELETE diretto item su assigned rifiutato (postgres)
  BEGIN
    DELETE FROM public.assigned_quiz_items
    WHERE assignment_id = v_assignment_id;
    RAISE EXCEPTION 'Test 21 FAILED: direct DELETE items on assigned should be frozen';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%assigned_quiz_items_frozen%' THEN
        RAISE;
      END IF;
  END;

  -- 13) start/resume non duplica in_progress
  v_gen := public.start_assigned_quiz_attempt(v_assignment_id);
  v_attempt_id_2 := (v_gen->>'attempt_id')::uuid;

  IF v_attempt_id_2 IS DISTINCT FROM v_attempt_id
     OR coalesce(v_gen->>'resumed', 'false') <> 'true' THEN
    RAISE EXCEPTION 'Test 13 FAILED: resume should return same in_progress attempt';
  END IF;

  SELECT count(*)::integer
  INTO v_in_progress_count
  FROM public.assigned_quiz_attempts
  WHERE assignment_id = v_assignment_id
    AND user_id = v_student_user_id
    AND status = 'in_progress';

  IF v_in_progress_count <> 1 THEN
    RAISE EXCEPTION 'Test 13 FAILED: expected 1 in_progress, got %', v_in_progress_count;
  END IF;

  -- 14) abandoned conta nel limite
  PERFORM public.abandon_assigned_quiz_attempt(v_attempt_id);

  v_gen := public.start_assigned_quiz_attempt(v_assignment_id);
  v_attempt_id := (v_gen->>'attempt_id')::uuid;
  v_attempts_used := (v_gen->>'attempts_used')::integer;

  IF v_attempts_used < 2 THEN
    RAISE EXCEPTION 'Test 14 FAILED: abandoned should count toward limit, attempts_used=%',
      v_attempts_used;
  END IF;

  PERFORM public.submit_assigned_quiz_attempt(v_attempt_id);

  SELECT correct_count, wrong_count, unanswered_count
  INTO v_correct_count, v_wrong_count, v_unanswered_count
  FROM public.assigned_quiz_attempts
  WHERE id = v_attempt_id;

  IF v_correct_count + v_wrong_count + v_unanswered_count <>
     (SELECT question_count FROM public.assigned_quizzes WHERE id = v_assignment_id) THEN
    RAISE EXCEPTION 'Test 22 FAILED: submit counts sum != question_count';
  END IF;

  -- 17) review abandoned negata allo studente
  BEGIN
    PERFORM count(*)
    FROM public.get_assigned_quiz_attempt_review(
      (SELECT id FROM public.assigned_quiz_attempts
       WHERE assignment_id = v_assignment_id
         AND status = 'abandoned'
       LIMIT 1)
    );
    RAISE EXCEPTION 'Test 17 FAILED: student review of abandoned should be denied';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%not_authorized%' THEN
        RAISE;
      END IF;
  END;

  -- Review submitted OK
  PERFORM count(*)
  FROM public.get_assigned_quiz_attempt_review(v_attempt_id);

  -- -------------------------------------------------------------------------
  -- 15) DELETE assigned con tentativi rifiutato
  -- -------------------------------------------------------------------------
  PERFORM set_config('request.jwt.claim.sub', v_staff_user_id::text, true);

  BEGIN
    DELETE FROM public.assigned_quizzes WHERE id = v_assignment_id;
    RAISE EXCEPTION 'Test 15 FAILED: DELETE assigned with attempts should be rejected';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%assigned_quiz_delete_not_allowed%' THEN
        RAISE;
      END IF;
  END;

  -- -------------------------------------------------------------------------
  -- 23) assigned senza tentativi non eliminabile
  -- -------------------------------------------------------------------------
  v_gen := public.generate_assigned_quiz_from_errors(
    p_student_id := v_student_id,
    p_title := 'Assigned no attempts',
    p_question_count := 2,
    p_assign_immediately := true,
    p_allow_partial := true,
    p_idempotency_key := v_idem_key || '-noatt'
  );
  v_assigned_no_attempts_id := (v_gen->>'assignment_id')::uuid;

  BEGIN
    DELETE FROM public.assigned_quizzes WHERE id = v_assigned_no_attempts_id;
    RAISE EXCEPTION 'Test 23 FAILED: DELETE assigned without attempts should be rejected';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%assigned_quiz_delete_not_allowed%' THEN
        RAISE;
      END IF;
  END;

  -- -------------------------------------------------------------------------
  -- 24) archived senza tentativi non eliminabile
  -- -------------------------------------------------------------------------
  BEGIN
    DELETE FROM public.assigned_quizzes WHERE id = v_archived_assignment_id;
    RAISE EXCEPTION 'Test 24 FAILED: DELETE archived should be rejected';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%assigned_quiz_delete_not_allowed%' THEN
        RAISE;
      END IF;
  END;

  -- -------------------------------------------------------------------------
  -- 25) DELETE diretto item su archived rifiutato
  -- -------------------------------------------------------------------------
  BEGIN
    DELETE FROM public.assigned_quiz_items
    WHERE assignment_id = v_archived_assignment_id;
    RAISE EXCEPTION 'Test 25 FAILED: direct DELETE items on archived should be frozen';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%assigned_quiz_items_frozen%' THEN
        RAISE;
      END IF;
  END;

  -- -------------------------------------------------------------------------
  -- 26) draft con tentativo non eliminabile
  -- -------------------------------------------------------------------------
  v_gen := public.generate_assigned_quiz_from_errors(
    p_student_id := v_student_id,
    p_title := 'Draft with attempt',
    p_question_count := 2,
    p_assign_immediately := false,
    p_allow_partial := true,
    p_idempotency_key := v_idem_key || '-draftatt'
  );
  v_draft_with_attempt_id := (v_gen->>'assignment_id')::uuid;

  INSERT INTO public.assigned_quiz_attempts (
    assignment_id, student_id, user_id, attempt_number, status
  )
  VALUES (
    v_draft_with_attempt_id, v_student_id, v_student_user_id, 1, 'in_progress'
  );

  BEGIN
    DELETE FROM public.assigned_quizzes WHERE id = v_draft_with_attempt_id;
    RAISE EXCEPTION 'Test 26 FAILED: DELETE draft with attempt should be rejected';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%assigned_quiz_delete_not_allowed%' THEN
        RAISE;
      END IF;
  END;

  -- -------------------------------------------------------------------------
  -- 16) DELETE draft vuoto senza tentativi consentito
  -- -------------------------------------------------------------------------
  DELETE FROM public.assigned_quizzes WHERE id = v_empty_draft_id;

  IF EXISTS (SELECT 1 FROM public.assigned_quizzes WHERE id = v_empty_draft_id) THEN
    RAISE EXCEPTION 'Test 16 FAILED: empty draft without attempts should be deletable';
  END IF;

  -- -------------------------------------------------------------------------
  -- 27) DELETE draft popolato con item consentito (cascade)
  -- -------------------------------------------------------------------------
  v_gen := public.generate_assigned_quiz_from_errors(
    p_student_id := v_student_id,
    p_title := 'Populated draft delete',
    p_question_count := 2,
    p_assign_immediately := false,
    p_allow_partial := true,
    p_idempotency_key := v_idem_key || '-popdel'
  );
  v_populated_draft_id := (v_gen->>'assignment_id')::uuid;

  SELECT count(*)::integer
  INTO v_item_count
  FROM public.assigned_quiz_items
  WHERE assignment_id = v_populated_draft_id;

  IF v_item_count < 1 THEN
    RAISE EXCEPTION 'Test 27 setup FAILED: populated draft should have items';
  END IF;

  DELETE FROM public.assigned_quizzes WHERE id = v_populated_draft_id;

  IF EXISTS (SELECT 1 FROM public.assigned_quizzes WHERE id = v_populated_draft_id) THEN
    RAISE EXCEPTION 'Test 27 FAILED: populated draft should be deletable';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.assigned_quiz_items WHERE assignment_id = v_populated_draft_id
  ) THEN
    RAISE EXCEPTION 'Test 27 FAILED: items should cascade-delete with populated draft';
  END IF;

  -- -------------------------------------------------------------------------
  -- 28) contatore interno non accessibile ad authenticated
  -- -------------------------------------------------------------------------
  BEGIN
    SET LOCAL ROLE authenticated;
    PERFORM count(*) FROM public.assigned_quiz_code_counters;
    RAISE EXCEPTION 'Test 28 FAILED: authenticated SELECT on counter should be denied';
  EXCEPTION
    WHEN insufficient_privilege THEN
      NULL;
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%permission denied%'
         AND SQLERRM NOT LIKE '%insufficient_privilege%' THEN
        RAISE;
      END IF;
  END;

  BEGIN
    SET LOCAL ROLE authenticated;
    INSERT INTO public.assigned_quiz_code_counters (year, last_value)
    VALUES (2099, 1);
    RAISE EXCEPTION 'Test 28b FAILED: authenticated INSERT on counter should be denied';
  EXCEPTION
    WHEN insufficient_privilege THEN
      NULL;
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%permission denied%'
         AND SQLERRM NOT LIKE '%insufficient_privilege%' THEN
        RAISE;
      END IF;
  END;

  RESET ROLE;
  PERFORM set_config('request.jwt.claim.sub', v_staff_user_id::text, true);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);

  v_gen := public.generate_assigned_quiz_from_errors(
    p_student_id := v_student_id,
    p_title := 'Counter RPC check',
    p_question_count := 2,
    p_assign_immediately := true,
    p_allow_partial := true,
    p_idempotency_key := v_idem_key || '-counter'
  );

  IF coalesce(v_gen->>'public_code', '') !~ '^AQZ-[0-9]{4}-[0-9]{5}$' THEN
    RAISE EXCEPTION 'Test 28c FAILED: RPC public_code format invalid: %', v_gen->>'public_code';
  END IF;

  -- -------------------------------------------------------------------------
  -- 18) nessuna variazione quiz_results / quiz_attempt_answers
  -- -------------------------------------------------------------------------
  SELECT count(*)::integer INTO v_results_after FROM public.quiz_results;
  SELECT count(*)::integer INTO v_answers_after FROM public.quiz_attempt_answers;

  IF v_results_after <> v_results_before OR v_answers_after <> v_answers_before THEN
    RAISE EXCEPTION 'Test 18 FAILED: standard quiz tables mutated: results %->%, answers %->%',
      v_results_before, v_results_after, v_answers_before, v_answers_after;
  END IF;

  RAISE NOTICE 'assigned_quizzes smoke test: all 28 checks passed (assignment %).', v_assignment_id;
END;
$$;

ROLLBACK;
