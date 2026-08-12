-- =============================================================================
-- Extra entitlements: paid/staff-only writes to student_extra_purchases
--
-- The original management foundation allowed authenticated students to INSERT
-- or UPDATE their own purchase rows while checkout was still a local UI flow.
-- Stripe fulfillment now treats student_extra_purchases as the source of truth,
-- so student writes would let a user self-grant paid videocourse access.
-- =============================================================================

DROP POLICY IF EXISTS student_extra_purchases_student_insert_own
  ON public.student_extra_purchases;

DROP POLICY IF EXISTS student_extra_purchases_student_update_own
  ON public.student_extra_purchases;
