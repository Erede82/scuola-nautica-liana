import '../models/license_models.dart';

/// Risultato RPC `submit_multi_topic_quiz_attempt`.
class MultiTopicQuizAttemptResult {
  const MultiTopicQuizAttemptResult({
    required this.attemptId,
    required this.sessionId,
    required this.sheetIndex,
    required this.totalSheets,
    required this.licenseCategory,
    required this.lessonNumbers,
    required this.completedAt,
    required this.durationSeconds,
    required this.totalQuestions,
    required this.correctCount,
    required this.wrongCount,
    required this.unansweredCount,
    required this.idempotent,
  });

  final String attemptId;
  final String sessionId;
  final int sheetIndex;
  final int totalSheets;
  final LicenseCategoryId licenseCategory;
  final List<int> lessonNumbers;
  final DateTime completedAt;
  final int durationSeconds;
  final int totalQuestions;
  final int correctCount;
  final int wrongCount;
  final int unansweredCount;
  final bool idempotent;

  @override
  bool operator ==(Object other) =>
      other is MultiTopicQuizAttemptResult &&
      other.attemptId == attemptId &&
      other.sessionId == sessionId &&
      other.sheetIndex == sheetIndex &&
      other.totalSheets == totalSheets &&
      other.licenseCategory == licenseCategory &&
      _intsEqual(other.lessonNumbers, lessonNumbers) &&
      other.completedAt == completedAt &&
      other.durationSeconds == durationSeconds &&
      other.totalQuestions == totalQuestions &&
      other.correctCount == correctCount &&
      other.wrongCount == wrongCount &&
      other.unansweredCount == unansweredCount &&
      other.idempotent == idempotent;

  @override
  int get hashCode => Object.hash(
    attemptId,
    sessionId,
    sheetIndex,
    totalSheets,
    licenseCategory,
    Object.hashAll(lessonNumbers),
    completedAt,
    durationSeconds,
    totalQuestions,
    correctCount,
    wrongCount,
    unansweredCount,
    idempotent,
  );
}

bool _intsEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
