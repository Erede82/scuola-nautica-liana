/// Regole simulazione esame patente entro 12 miglia (motore / A12).
abstract final class ExamQuizRules {
  static const int questionCount = 20;
  static const int durationMinutes = 30;
  static const int maxErrorsToPass = 4;

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
/// (soglia massima [ExamQuizRules.maxErrorsToPass] errori).
ExamQuizSummary buildExamQuizSummary({
  required int totalQuestions,
  required int correctCount,
  required int wrongCount,
  required int unansweredCount,
}) {
  final errorCount = wrongCount + unansweredCount;
  final outcome = errorCount <= ExamQuizRules.maxErrorsToPass
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
