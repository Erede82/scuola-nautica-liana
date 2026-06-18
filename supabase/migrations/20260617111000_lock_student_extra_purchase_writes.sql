-- =============================================================================
-- Lock student_extra_purchases writes to staff / trusted server flows only.
-- =============================================================================
-- Earlier development policy allowed students to insert/update their own
-- purchase rows for client-side checkout. Production checkout is server-side:
-- students may read their purchases, but must not grant or re-grant paid videos.
-- =============================================================================

DROP POLICY IF EXISTS student_extra_purchases_student_insert_own
  ON public.student_extra_purchases;

DROP POLICY IF EXISTS student_extra_purchases_student_update_own
  ON public.student_extra_purchases;
