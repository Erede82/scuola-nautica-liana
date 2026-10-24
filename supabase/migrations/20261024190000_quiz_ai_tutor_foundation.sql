-- QUIZ.AI.TUTOR.1 — pre-generated Tutor Liana foundation.
--
-- One Tutor record per question. No student read path yet.
-- Does not modify public.questions or generate Tutor text.

-- ---------------------------------------------------------------------------
-- Source hash
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.compute_quiz_question_tutor_source_hash(
  p_question_id uuid
)
RETURNS text
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public, extensions, pg_temp
AS $$
  SELECT encode(
    extensions.digest(
      convert_to(
        concat_ws(
          E'\n',
          'prompt=' || coalesce(btrim(q.prompt), ''),
          'option_a=' || coalesce(btrim(q.option_a), ''),
          'option_b=' || coalesce(btrim(q.option_b), ''),
          'option_c=' || coalesce(btrim(q.option_c), ''),
          'correct_option=' || coalesce(btrim(q.correct_option::text), ''),
          'image_path=' || coalesce(btrim(q.image_path), ''),
          'official_explanation=' || coalesce(btrim(q.explanation), '')
        ),
        'UTF8'
      ),
      'sha256'
    ),
    'hex'
  )
  FROM public.questions q
  WHERE q.id = p_question_id;
$$;

COMMENT ON FUNCTION public.compute_quiz_question_tutor_source_hash(uuid) IS
  'SHA-256 hex of Tutor-relevant question source. Read-only. NULL if the question does not exist.';

REVOKE ALL ON FUNCTION public.compute_quiz_question_tutor_source_hash(uuid) FROM PUBLIC;

-- ---------------------------------------------------------------------------
-- Tutor records
-- ---------------------------------------------------------------------------
CREATE TABLE public.quiz_question_explanations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  question_id uuid NOT NULL UNIQUE
    REFERENCES public.questions (id) ON DELETE RESTRICT,
  source_hash text NOT NULL,
  explanation text NOT NULL,
  simple_explanation text NOT NULL,
  memory_example text NOT NULL,
  status text NOT NULL,
  model text,
  prompt_version text NOT NULL,
  generated_at timestamptz NOT NULL,
  reviewed_at timestamptz,
  approved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT quiz_question_explanations_status_chk
    CHECK (status IN ('generated', 'review_required', 'approved', 'stale')),
  CONSTRAINT quiz_question_explanations_source_hash_chk
    CHECK (source_hash ~ '^[0-9a-f]{64}$'),
  CONSTRAINT quiz_question_explanations_explanation_chk
    CHECK (btrim(explanation) <> ''),
  CONSTRAINT quiz_question_explanations_simple_chk
    CHECK (btrim(simple_explanation) <> ''),
  CONSTRAINT quiz_question_explanations_memory_chk
    CHECK (btrim(memory_example) <> ''),
  CONSTRAINT quiz_question_explanations_prompt_version_chk
    CHECK (btrim(prompt_version) <> '')
);

COMMENT ON TABLE public.quiz_question_explanations IS
  'Pre-generated Tutor Liana outputs. One row per question. Student access is not granted in v1.';

CREATE INDEX quiz_question_explanations_status_generated_at_idx
  ON public.quiz_question_explanations (status, generated_at DESC);

DROP TRIGGER IF EXISTS quiz_question_explanations_set_updated_at
  ON public.quiz_question_explanations;

CREATE TRIGGER quiz_question_explanations_set_updated_at
  BEFORE UPDATE ON public.quiz_question_explanations
  FOR EACH ROW
  EXECUTE PROCEDURE public.set_updated_at();

ALTER TABLE public.quiz_question_explanations ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.quiz_question_explanations FROM PUBLIC;
REVOKE ALL ON TABLE public.quiz_question_explanations FROM anon;
REVOKE ALL ON TABLE public.quiz_question_explanations FROM authenticated;

-- ---------------------------------------------------------------------------
-- Staff read RPC
-- ---------------------------------------------------------------------------
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

COMMENT ON FUNCTION public.get_staff_quiz_question_explanation(uuid) IS
  'Staff read of one Tutor record. is_school_staff only. Absent Tutor row is tutor_present=false, not an error.';

REVOKE ALL ON FUNCTION public.get_staff_quiz_question_explanation(uuid) FROM PUBLIC;

DO $$
BEGIN
  BEGIN
    REVOKE ALL ON FUNCTION public.compute_quiz_question_tutor_source_hash(uuid) FROM anon;
    REVOKE ALL ON FUNCTION public.get_staff_quiz_question_explanation(uuid) FROM anon;
  EXCEPTION
    WHEN undefined_object THEN
      NULL;
  END;

  GRANT EXECUTE ON FUNCTION public.compute_quiz_question_tutor_source_hash(uuid)
    TO service_role;
  GRANT SELECT, INSERT, UPDATE, DELETE
    ON TABLE public.quiz_question_explanations
    TO service_role;
  GRANT EXECUTE ON FUNCTION public.get_staff_quiz_question_explanation(uuid)
    TO authenticated;
END;
$$;
