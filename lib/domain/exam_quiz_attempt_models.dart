import '../models/license_models.dart';
import 'exam_quiz_rules.dart';

/// Riepilogo di un tentativo esame concluso (lista storico, senza snapshot).
class ExamQuizAttemptSummary {
  const ExamQuizAttemptSummary({
    required this.id,
    required this.licenseCategory,
    required this.completedAt,
    required this.duration,
    required this.timeExpired,
    required this.totalQuestions,
    required this.correctCount,
    required this.wrongCount,
    required this.unansweredCount,
    required this.outcome,
  });

  final String id;
  final LicenseCategoryId licenseCategory;
  final DateTime completedAt;
  final Duration duration;
  final bool timeExpired;
  final int totalQuestions;
  final int correctCount;
  final int wrongCount;
  final int unansweredCount;
  final ExamQuizOutcome outcome;

  bool get passed => outcome == ExamQuizOutcome.passed;

  int get errorCount => wrongCount + unansweredCount;

  @override
  bool operator ==(Object other) =>
      other is ExamQuizAttemptSummary &&
      other.id == id &&
      other.licenseCategory == licenseCategory &&
      other.completedAt == completedAt &&
      other.duration == duration &&
      other.timeExpired == timeExpired &&
      other.totalQuestions == totalQuestions &&
      other.correctCount == correctCount &&
      other.wrongCount == wrongCount &&
      other.unansweredCount == unansweredCount &&
      other.outcome == outcome;

  @override
  int get hashCode => Object.hash(
    id,
    licenseCategory,
    completedAt,
    duration,
    timeExpired,
    totalQuestions,
    correctCount,
    wrongCount,
    unansweredCount,
    outcome,
  );
}

/// Risposta della RPC `submit_exam_quiz_attempt`.
///
/// Contiene il riepilogo persistito e il flag [idempotent].
/// Non include lo snapshot risposte (caricabile via dettaglio).
class ExamQuizAttemptSubmitResult {
  const ExamQuizAttemptSubmitResult({
    required this.attempt,
    required this.idempotent,
  });

  final ExamQuizAttemptSummary attempt;
  final bool idempotent;

  String get attemptId => attempt.id;

  @override
  bool operator ==(Object other) =>
      other is ExamQuizAttemptSubmitResult &&
      other.attempt == attempt &&
      other.idempotent == idempotent;

  @override
  int get hashCode => Object.hash(attempt, idempotent);
}
