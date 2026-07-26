import '../models/license_models.dart';

/// Regole simulazione esame patente (A12 motore, D1 vela entro 12 miglia).
abstract final class ExamQuizRules {
  /// Valori legacy A12 — preferire [examQuizRulesForCategory].
  static const int questionCount = 20;
  static const int durationMinutes = 30;
  static const int maxErrorsToPass = 4;
  static const int durationSeconds = 1800;

  /// Quota domande per `questions.exam_topic_code` (A12).
  static const Map<String, int> a12TopicQuotas = {
    'SCAFO': 1,
    'MOTORE': 1,
    'SICUREZZA': 3,
    'MANOVRE': 4,
    'COLREG': 2,
    'METEO': 2,
    'NAV': 4,
    'NORM': 3,
  };

  /// Quota domande per `questions.exam_topic_code` (D1).
  static const Map<String, int> d1TopicQuotas = {
    'SCAFO': 1,
    'MOTORE': 2,
    'SICUREZZA': 3,
    'MANOVRE': 2,
    'COLREG': 2,
    'METEO': 1,
    'NAV': 1,
    'NORM': 3,
  };
}

/// Regole esame per una singola categoria supportata.
class ExamQuizCategoryRules {
  const ExamQuizCategoryRules({
    required this.totalQuestions,
    required this.maxErrorsToPass,
    required this.durationSeconds,
    required this.topicQuotas,
  });

  final int totalQuestions;
  final int maxErrorsToPass;
  final int durationSeconds;
  final Map<String, int> topicQuotas;

  int get durationMinutes => durationSeconds ~/ 60;
}

/// Regole esame per categoria app. `null` se la categoria non è supportata.
ExamQuizCategoryRules? examQuizRulesForCategory(LicenseCategoryId category) {
  switch (category) {
    case LicenseCategoryId.motore:
      return const ExamQuizCategoryRules(
        totalQuestions: ExamQuizRules.questionCount,
        maxErrorsToPass: ExamQuizRules.maxErrorsToPass,
        durationSeconds: ExamQuizRules.durationSeconds,
        topicQuotas: ExamQuizRules.a12TopicQuotas,
      );
    case LicenseCategoryId.d1:
      return const ExamQuizCategoryRules(
        totalQuestions: 15,
        maxErrorsToPass: 3,
        durationSeconds: ExamQuizRules.durationSeconds,
        topicQuotas: ExamQuizRules.d1TopicQuotas,
      );
    case LicenseCategoryId.vela:
      return null;
  }
}

/// Regole esame per codice DB (`A12`, `D1`).
ExamQuizCategoryRules? examQuizRulesForDbCategory(String licenseCategoryDb) {
  switch (licenseCategoryDb) {
    case 'A12':
      return examQuizRulesForCategory(LicenseCategoryId.motore);
    case 'D1':
      return examQuizRulesForCategory(LicenseCategoryId.d1);
    default:
      return null;
  }
}

/// Esito simulazione esame (solo UI locale in P9C.4-A).
enum ExamQuizOutcome { passed, failed }

class ExamQuizSummary {
  const ExamQuizSummary({
    required this.totalQuestions,
    required this.correctCount,
    required this.wrongCount,
    required this.unansweredCount,
    required this.errorCount,
    required this.outcome,
  });

  final int totalQuestions;
  final int correctCount;
  final int wrongCount;
  final int unansweredCount;

  /// Errori ai fini del superamento: risposte sbagliate + non risposte.
  final int errorCount;
  final ExamQuizOutcome outcome;
}

/// Calcola conteggi ed esito esame.
///
/// Le domande non risposte contano come errore per il superamento
/// (soglia massima [maxErrorsToPass] errori).
ExamQuizSummary buildExamQuizSummary({
  required int totalQuestions,
  required int correctCount,
  required int wrongCount,
  required int unansweredCount,
  required int maxErrorsToPass,
}) {
  final errorCount = wrongCount + unansweredCount;
  final outcome = errorCount <= maxErrorsToPass
      ? ExamQuizOutcome.passed
      : ExamQuizOutcome.failed;

  return ExamQuizSummary(
    totalQuestions: totalQuestions,
    correctCount: correctCount,
    wrongCount: wrongCount,
    unansweredCount: unansweredCount,
    errorCount: errorCount,
    outcome: outcome,
  );
}

String formatExamDurationMmSs(Duration remaining) {
  final totalSeconds = remaining.inSeconds.clamp(0, 24 * 3600);
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}
