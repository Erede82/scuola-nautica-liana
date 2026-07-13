/// Singolo tentativo scheda lezione per timeline / ultime attività.
class QuizAttemptActivity {
  const QuizAttemptActivity({
    required this.quizResultId,
    required this.lessonNumber,
    required this.sheetNumber,
    required this.totalQuestions,
    required this.correctCount,
    required this.wrongCount,
    required this.unansweredCount,
    required this.errorPercentage,
    required this.completedAt,
  });

  final String quizResultId;
  final int lessonNumber;
  final int sheetNumber;
  final int totalQuestions;
  final int correctCount;
  final int wrongCount;
  final int unansweredCount;
  final double errorPercentage;
  final DateTime completedAt;
}
