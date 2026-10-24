import 'prompt.dart';
import 'validation.dart';

/// The only status this generator is allowed to persist.
const String tutorStoredStatus = 'review_required';

/// Reason stored for this generation only.
///
/// `needs_review: false` always yields null, even if the model sent a reason.
/// A blank reason is never stored.
String? persistedGenerationReviewReason(TutorParsedOutput output) {
  if (!output.needsReview) return null;
  final reason = output.reviewReason?.trim();
  if (reason == null || reason.isEmpty) return null;
  return reason;
}

class TutorWritePayload {
  TutorWritePayload({
    required this.questionId,
    required this.sourceHash,
    required this.explanation,
    required this.simpleExplanation,
    required this.memoryExample,
    required this.model,
    required this.generatedAt,
    required TutorParsedOutput output,
  }) : promptVersion = tutorLianaPromptVersion,
       status = tutorStoredStatus,
       reviewedAt = null,
       approvedAt = null,
       generationReviewReason = persistedGenerationReviewReason(output);

  final String questionId;
  final String sourceHash;
  final String explanation;
  final String simpleExplanation;
  final String memoryExample;
  final String status;
  final String model;
  final String promptVersion;
  final DateTime generatedAt;
  final DateTime? reviewedAt;
  final DateTime? approvedAt;
  final String? generationReviewReason;

  Map<String, Object?> toJson() {
    return {
      'question_id': questionId,
      'source_hash': sourceHash,
      'explanation': explanation,
      'simple_explanation': simpleExplanation,
      'memory_example': memoryExample,
      'status': status,
      'model': model,
      'prompt_version': promptVersion,
      'generated_at': generatedAt.toUtc().toIso8601String(),
      'reviewed_at': null,
      'approved_at': null,
      'generation_review_reason': generationReviewReason,
    };
  }
}

enum TutorWriteMode { insert, updateProtected, updateForced }

class TutorPersistencePlan {
  const TutorPersistencePlan({required this.mode, required this.payload});

  final TutorWriteMode mode;
  final TutorWritePayload payload;
}

/// PostgREST filter that refuses to replace an approved current-hash row.
String protectedUpdateFilter({
  required String questionId,
  required String currentHash,
}) {
  return 'question_id=eq.$questionId'
      '&or=(status.neq.approved,source_hash.neq.$currentHash)';
}

String forcedUpdateFilter({required String questionId}) {
  return 'question_id=eq.$questionId';
}
