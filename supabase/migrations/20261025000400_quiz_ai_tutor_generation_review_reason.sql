-- Persist the model self-flag reason for later staff review.
-- This is not a human reviewer comment and does not change status.

ALTER TABLE public.quiz_question_explanations
  ADD COLUMN generation_review_reason text;

ALTER TABLE public.quiz_question_explanations
  ADD CONSTRAINT quiz_question_explanations_generation_review_reason_chk
  CHECK (
    generation_review_reason IS NULL
    OR btrim(generation_review_reason) <> ''
  );

COMMENT ON COLUMN public.quiz_question_explanations.generation_review_reason IS
  'Optional machine note explaining why generation flagged the row for human attention. NULL when no special reason was supplied.';

CREATE OR REPLACE FUNCTION public.get_staff_quiz_question_explanation(
  p_question_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_question public.questions%ROWTYPE;
  v_tutor public.quiz_question_explanations%ROWTYPE;
  v_hash text;
BEGIN
  IF v_uid IS NULL OR NOT public.is_school_staff() THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  IF p_question_id IS NULL THEN
    RAISE EXCEPTION 'invalid_arguments';
  END IF;

  SELECT *
  INTO v_question
  FROM public.questions q
  WHERE q.id = p_question_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'question_not_found';
  END IF;

  v_hash := public.compute_quiz_question_tutor_source_hash(p_question_id);

  SELECT *
  INTO v_tutor
  FROM public.quiz_question_explanations t
  WHERE t.question_id = p_question_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'question_found', true,
      'tutor_present', false,
      'question_id', v_question.id,
      'current_source_hash', v_hash,
      'stored_source_hash', NULL,
      'is_stale', NULL,
      'status', NULL,
      'explanation', NULL,
      'simple_explanation', NULL,
      'memory_example', NULL,
      'generation_review_reason', NULL,
      'model', NULL,
      'prompt_version', NULL,
      'generated_at', NULL,
      'reviewed_at', NULL,
      'approved_at', NULL,
      'license_category', v_question.license_category,
      'lesson_number', v_question.lesson_number,
      'exam_topic_code', v_question.exam_topic_code,
      'prompt', v_question.prompt,
      'option_a', v_question.option_a,
      'option_b', v_question.option_b,
      'option_c', v_question.option_c,
      'correct_option', v_question.correct_option,
      'image_path', v_question.image_path
    );
  END IF;

  RETURN jsonb_build_object(
    'question_found', true,
    'tutor_present', true,
    'question_id', v_question.id,
    'current_source_hash', v_hash,
    'stored_source_hash', v_tutor.source_hash,
    'is_stale', v_tutor.source_hash IS DISTINCT FROM v_hash,
    'status', v_tutor.status,
    'explanation', v_tutor.explanation,
    'simple_explanation', v_tutor.simple_explanation,
    'memory_example', v_tutor.memory_example,
    'generation_review_reason', v_tutor.generation_review_reason,
    'model', v_tutor.model,
    'prompt_version', v_tutor.prompt_version,
    'generated_at', v_tutor.generated_at,
    'reviewed_at', v_tutor.reviewed_at,
    'approved_at', v_tutor.approved_at,
    'license_category', v_question.license_category,
    'lesson_number', v_question.lesson_number,
    'exam_topic_code', v_question.exam_topic_code,
    'prompt', v_question.prompt,
    'option_a', v_question.option_a,
    'option_b', v_question.option_b,
    'option_c', v_question.option_c,
    'correct_option', v_question.correct_option,
    'image_path', v_question.image_path
  );
END;
$$;
