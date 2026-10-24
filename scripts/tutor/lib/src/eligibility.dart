enum TutorPlanAction {
  generate,
  skipApprovedCurrent,
  skipReviewCurrent,
  regenerateStale,
  regenerateMarkedStale,
  regenerateCurrent,
  forceApproved,
}

extension TutorPlanActionX on TutorPlanAction {
  String get label {
    switch (this) {
      case TutorPlanAction.generate:
        return 'GENERATE';
      case TutorPlanAction.skipApprovedCurrent:
        return 'SKIP_APPROVED_CURRENT';
      case TutorPlanAction.skipReviewCurrent:
        return 'SKIP_REVIEW_CURRENT';
      case TutorPlanAction.regenerateStale:
        return 'REGENERATE_STALE';
      case TutorPlanAction.regenerateMarkedStale:
        return 'REGENERATE_MARKED_STALE';
      case TutorPlanAction.regenerateCurrent:
        return 'REGENERATE_CURRENT';
      case TutorPlanAction.forceApproved:
        return 'FORCE_APPROVED';
    }
  }

  bool get callsProvider {
    switch (this) {
      case TutorPlanAction.generate:
      case TutorPlanAction.regenerateStale:
      case TutorPlanAction.regenerateMarkedStale:
      case TutorPlanAction.regenerateCurrent:
      case TutorPlanAction.forceApproved:
        return true;
      case TutorPlanAction.skipApprovedCurrent:
      case TutorPlanAction.skipReviewCurrent:
        return false;
    }
  }

  bool get writesRow => callsProvider;
}

class TutorExistingRow {
  const TutorExistingRow({
    required this.questionId,
    required this.sourceHash,
    required this.status,
  });

  final String questionId;
  final String sourceHash;
  final String status;
}

/// Eligibility before any provider call.
///
/// Approved + current hash is skipped unless [forceApproved].
/// review_required or generated + current hash is skipped unless [regenerate].
/// A different hash is always a stale regeneration candidate, including when
/// the stored row is still marked approved.
TutorPlanAction planTutorAction({
  required TutorExistingRow? existing,
  required String currentHash,
  required bool regenerate,
  required bool forceApproved,
}) {
  if (existing == null) return TutorPlanAction.generate;
  final sameHash = existing.sourceHash == currentHash;
  if (!sameHash) return TutorPlanAction.regenerateStale;
  switch (existing.status) {
    case 'approved':
      return forceApproved
          ? TutorPlanAction.forceApproved
          : TutorPlanAction.skipApprovedCurrent;
    case 'stale':
      return TutorPlanAction.regenerateMarkedStale;
    case 'review_required':
    case 'generated':
      return regenerate
          ? TutorPlanAction.regenerateCurrent
          : TutorPlanAction.skipReviewCurrent;
    default:
      return regenerate
          ? TutorPlanAction.regenerateCurrent
          : TutorPlanAction.skipReviewCurrent;
  }
}
