import '../models/license_models.dart';
import 'student_stats_source.dart';

/// Conteggi answer-level per un argomento (lesson_number).
class TopicAnswerCounts {
  const TopicAnswerCounts({
    this.correct = 0,
    this.wrong = 0,
    this.unanswered = 0,
    this.lastActivity,
  });

  final int correct;
  final int wrong;
  final int unanswered;
  final DateTime? lastActivity;

  int get questionsSeen => correct + wrong + unanswered;

  /// errors = wrong + unanswered (regola unica STUDENT.STATS.1).
  int get errors => wrong + unanswered;

  /// accuracy = correct / total_seen; 0 se nessun dato.
  double get accuracy {
    final seen = questionsSeen;
    if (seen <= 0) return 0;
    return correct / seen;
  }

  double get accuracyPercentage => accuracy * 100;

  TopicAnswerCounts merge(TopicAnswerCounts other) {
    DateTime? last = lastActivity;
    final otherLast = other.lastActivity;
    if (otherLast != null && (last == null || otherLast.isAfter(last))) {
      last = otherLast;
    }
    return TopicAnswerCounts(
      correct: correct + other.correct,
      wrong: wrong + other.wrong,
      unanswered: unanswered + other.unanswered,
      lastActivity: last,
    );
  }

  static const empty = TopicAnswerCounts();
}

/// Statistiche per argomento (lesson_number canonico).
class TopicStatistics {
  const TopicStatistics({
    required this.lessonNumber,
    required this.title,
    required this.counts,
  });

  final int lessonNumber;
  final String title;
  final TopicAnswerCounts counts;

  int get questionsSeen => counts.questionsSeen;
  int get correct => counts.correct;
  int get wrong => counts.wrong;
  int get unanswered => counts.unanswered;
  int get errors => counts.errors;
  double get accuracyPercentage => counts.accuracyPercentage;
  DateTime? get lastActivity => counts.lastActivity;
}

/// Card Studio: schede + Multischeda.
class StudyStatistics {
  const StudyStatistics({
    required this.sheetsCompleted,
    required this.correct,
    required this.wrong,
    required this.unanswered,
    required this.topicsStudied,
    required this.topicsTotal,
  });

  final int sheetsCompleted;
  final int correct;
  final int wrong;
  final int unanswered;
  final int topicsStudied;
  final int topicsTotal;

  int get questionsSeen => correct + wrong + unanswered;

  int get errors => wrong + unanswered;

  double get accuracy {
    final seen = questionsSeen;
    if (seen <= 0) return 0;
    return correct / seen;
  }

  double get accuracyPercentage => accuracy * 100;

  bool get hasActivity => sheetsCompleted > 0 || questionsSeen > 0;

  static const empty = StudyStatistics(
    sheetsCompleted: 0,
    correct: 0,
    wrong: 0,
    unanswered: 0,
    topicsStudied: 0,
    topicsTotal: 0,
  );
}

/// Esito recente simulazione d'esame (compact).
class RecentExamResult {
  const RecentExamResult({
    required this.attemptId,
    required this.completedAt,
    required this.passed,
    required this.errorCount,
  });

  final String attemptId;
  final DateTime completedAt;
  final bool passed;
  final int errorCount;
}

/// Card Simulazioni d'esame.
class ExamStatistics {
  const ExamStatistics({
    required this.simulationsCount,
    required this.passedCount,
    required this.averageErrors,
    required this.recentResults,
    this.answersExcludedFromTopics = 0,
  });

  final int simulationsCount;
  final int passedCount;
  final double averageErrors;
  final List<RecentExamResult> recentResults;

  /// Risposte esame senza lesson_number: nei totali Esame ma non nel Top 3 / per-topic.
  final int answersExcludedFromTopics;

  double get passRate {
    if (simulationsCount <= 0) return 0;
    return passedCount / simulationsCount;
  }

  double get passRatePercentage => passRate * 100;

  bool get hasActivity => simulationsCount > 0;

  static const empty = ExamStatistics(
    simulationsCount: 0,
    passedCount: 0,
    averageErrors: 0,
    recentResults: [],
  );
}

/// Voce Top 3 "Da ripassare".
class ReviewTopic {
  const ReviewTopic({
    required this.rank,
    required this.topic,
  });

  final int rank;
  final TopicStatistics topic;
}

/// Aggregato completo STATISTICHE allievo (v1).
class StudentQuizStatistics {
  const StudentQuizStatistics({
    required this.categoryId,
    required this.study,
    required this.exam,
    required this.topicsAll,
    required this.topicsStudy,
    required this.topicsExam,
    required this.reviewAll,
    required this.reviewStudy,
    required this.reviewExam,
    this.ignoredIncompleteLessonAttempts = 0,
    this.ignoredIncompleteMultiAttempts = 0,
    this.ignoredIncompleteExamAttempts = 0,
  });

  final LicenseCategoryId categoryId;
  final StudyStatistics study;
  final ExamStatistics exam;

  final List<TopicStatistics> topicsAll;
  final List<TopicStatistics> topicsStudy;
  final List<TopicStatistics> topicsExam;

  final List<ReviewTopic> reviewAll;
  final List<ReviewTopic> reviewStudy;
  final List<ReviewTopic> reviewExam;

  final int ignoredIncompleteLessonAttempts;
  final int ignoredIncompleteMultiAttempts;
  final int ignoredIncompleteExamAttempts;

  bool get hasAnyActivity => study.hasActivity || exam.hasActivity;

  bool get hasCatalog => study.topicsTotal > 0;

  bool get showDashboard => hasAnyActivity || hasCatalog;

  List<TopicStatistics> topicsFor(StudentStatsSource source) {
    switch (source) {
      case StudentStatsSource.all:
        return topicsAll;
      case StudentStatsSource.study:
        return topicsStudy;
      case StudentStatsSource.exam:
        return topicsExam;
    }
  }

  List<ReviewTopic> reviewFor(StudentStatsSource source) {
    switch (source) {
      case StudentStatsSource.all:
        return reviewAll;
      case StudentStatsSource.study:
        return reviewStudy;
      case StudentStatsSource.exam:
        return reviewExam;
    }
  }

  static StudentQuizStatistics empty(
    LicenseCategoryId categoryId, {
    int topicsTotal = 0,
  }) {
    return StudentQuizStatistics(
      categoryId: categoryId,
      study: StudyStatistics(
        sheetsCompleted: 0,
        correct: 0,
        wrong: 0,
        unanswered: 0,
        topicsStudied: 0,
        topicsTotal: topicsTotal,
      ),
      exam: ExamStatistics.empty,
      topicsAll: const [],
      topicsStudy: const [],
      topicsExam: const [],
      reviewAll: const [],
      reviewStudy: const [],
      reviewExam: const [],
    );
  }
}

/// Evento answer-level per aggregazione topic.
class StudentStatsAnswerEvent {
  const StudentStatsAnswerEvent({
    required this.source,
    required this.lessonNumber,
    required this.isCorrect,
    required this.isUnanswered,
    required this.completedAt,
  });

  /// Solo [StudentStatsSource.study] o [StudentStatsSource.exam].
  final StudentStatsSource source;
  final int? lessonNumber;
  final bool isCorrect;
  final bool isUnanswered;
  final DateTime completedAt;
}

/// Tentativo scheda (Studio) per conteggio attività.
class StudentStatsSheetEvent {
  const StudentStatsSheetEvent({
    required this.completedAt,
    required this.correct,
    required this.wrong,
    required this.unanswered,
  });

  final DateTime completedAt;
  final int correct;
  final int wrong;
  final int unanswered;

  int get questionsSeen => correct + wrong + unanswered;
}

/// Tentativo esame valido (header).
class StudentStatsExamAttemptEvent {
  const StudentStatsExamAttemptEvent({
    required this.attemptId,
    required this.completedAt,
    required this.passed,
    required this.correct,
    required this.wrong,
    required this.unanswered,
  });

  final String attemptId;
  final DateTime completedAt;
  final bool passed;
  final int correct;
  final int wrong;
  final int unanswered;

  int get errorCount => wrong + unanswered;
}
