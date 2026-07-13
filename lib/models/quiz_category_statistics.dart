import 'lesson_quiz_performance_snapshot.dart';
import 'license_models.dart';
import 'quiz_attempt_activity.dart';
import 'quiz_statistics_summary.dart';

/// Statistiche quiz reali per una categoria patente (schede lezione).
class QuizCategoryStatistics {
  const QuizCategoryStatistics({
    required this.categoryId,
    required this.summary,
    required this.lessonSnapshots,
    required this.recentAttempts,
  });

  final LicenseCategoryId categoryId;
  final QuizStatisticsSummary summary;
  final List<LessonQuizPerformanceSnapshot> lessonSnapshots;
  final List<QuizAttemptActivity> recentAttempts;

  bool get hasData => summary.completedSheetsCount > 0;

  bool get hasIgnoredAttempts => summary.ignoredIncompleteAttempts > 0;

  static QuizCategoryStatistics empty(LicenseCategoryId categoryId) {
    return QuizCategoryStatistics(
      categoryId: categoryId,
      summary: QuizStatisticsSummary.empty,
      lessonSnapshots: const [],
      recentAttempts: const [],
    );
  }

  /// Storico con tentativi presenti ma tutti scartati per incoerenza.
  static QuizCategoryStatistics ignoredOnly({
    required LicenseCategoryId categoryId,
    required int ignoredIncompleteAttempts,
  }) {
    return QuizCategoryStatistics(
      categoryId: categoryId,
      summary: QuizStatisticsSummary(
        completedSheetsCount: 0,
        totalQuestions: 0,
        correctCount: 0,
        wrongCount: 0,
        unansweredCount: 0,
        accuracyPercentage: 0,
        errorPercentage: 0,
        averageErrorsPerSheet: 0,
        ignoredIncompleteAttempts: ignoredIncompleteAttempts,
      ),
      lessonSnapshots: const [],
      recentAttempts: const [],
    );
  }
}
