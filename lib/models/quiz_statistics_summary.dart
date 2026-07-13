/// Aggregati globali statistiche quiz per categoria patente.
class QuizStatisticsSummary {
  const QuizStatisticsSummary({
    required this.completedSheetsCount,
    required this.totalQuestions,
    required this.correctCount,
    required this.wrongCount,
    required this.unansweredCount,
    required this.accuracyPercentage,
    required this.errorPercentage,
    required this.averageErrorsPerSheet,
    required this.ignoredIncompleteAttempts,
    this.lastActivityAt,
    this.lastLessonNumber,
    this.lastSheetNumber,
    this.weakestLessonNumber,
    this.strongestLessonNumber,
  });

  final int completedSheetsCount;
  final int totalQuestions;
  final int correctCount;
  final int wrongCount;
  final int unansweredCount;

  /// Corrette / totale domande (0–100).
  final double accuracyPercentage;

  /// (Errate + non risposte) / totale domande (0–100).
  final double errorPercentage;

  /// Media risposte errate per scheda completata (solo [wrongCount], non le non risposte).
  final double averageErrorsPerSheet;

  /// Tentativi scartati per metadati incoerenti o answer count non valido.
  final int ignoredIncompleteAttempts;

  final DateTime? lastActivityAt;
  final int? lastLessonNumber;
  final int? lastSheetNumber;
  final int? weakestLessonNumber;
  final int? strongestLessonNumber;

  static const empty = QuizStatisticsSummary(
    completedSheetsCount: 0,
    totalQuestions: 0,
    correctCount: 0,
    wrongCount: 0,
    unansweredCount: 0,
    accuracyPercentage: 0,
    errorPercentage: 0,
    averageErrorsPerSheet: 0,
    ignoredIncompleteAttempts: 0,
  );
}
