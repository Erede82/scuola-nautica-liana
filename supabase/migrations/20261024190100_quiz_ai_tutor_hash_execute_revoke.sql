-- Default privileges grant EXECUTE to authenticated at function creation.
-- The hash is an internal/service helper, not a student or staff client RPC.

REVOKE ALL ON FUNCTION public.compute_quiz_question_tutor_source_hash(uuid)
  FROM authenticated;
