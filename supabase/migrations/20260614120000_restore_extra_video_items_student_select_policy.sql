-- =============================================================================
-- Restore student SELECT on extra_video_items for purchased products (H1 fix)
-- =============================================================================
-- Remote production had only extra_video_items_staff_all; students could read
-- student_extra_purchases (grant / "Acquistato") but RLS returned zero rows for
-- extra_video_items. Idempotent DROP + CREATE.
-- =============================================================================

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

COMMENT ON POLICY extra_video_items_select_purchased ON public.extra_video_items IS
  'Allievo: legge video dei product_id acquistati (student_extra_purchases.student_id = students.id).';
