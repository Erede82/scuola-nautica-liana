import '../models/license_models.dart';
import 'student_quiz_statistics_models.dart';
import 'student_stats_source.dart';

/// Soglie Top 3 (sample size).
const int kStudentStatsTop3PrimaryMinSeen = 8;
const int kStudentStatsTop3FallbackMinSeen = 5;
const int kStudentStatsTop3Limit = 3;

/// Laplace-smoothed error rate: (errors + 1) / (seen + 2).
///
/// Non mostrare questo score in UI — solo ranking interno.
double studentStatsLaplaceErrorScore({
  required int errors,
  required int seen,
}) {
  if (seen < 0 || errors < 0) return 0;
  return (errors + 1) / (seen + 2);
}

double studentStatsAccuracy({
  required int correct,
  required int wrong,
  required int unanswered,
}) {
  final seen = correct + wrong + unanswered;
  if (seen <= 0) return 0;
  return correct / seen;
}

int studentStatsErrorCount({
  required int wrong,
  required int unanswered,
}) => wrong + unanswered;

/// Input catalogo argomenti (denominatore Studio + titoli).
class StudentStatsTopicCatalogEntry {
  const StudentStatsTopicCatalogEntry({
    required this.lessonNumber,
    required this.title,
  });

  final int lessonNumber;
  final String title;
}

/// Costruisce [StudentQuizStatistics] da eventi già validati.
StudentQuizStatistics buildStudentQuizStatistics({
  required LicenseCategoryId categoryId,
  required List<StudentStatsSheetEvent> studySheets,
  required List<StudentStatsExamAttemptEvent> examAttempts,
  required List<StudentStatsAnswerEvent> answerEvents,
  required List<StudentStatsTopicCatalogEntry> catalog,
  int ignoredIncompleteLessonAttempts = 0,
  int ignoredIncompleteMultiAttempts = 0,
  int ignoredIncompleteExamAttempts = 0,
}) {
  final titleByLesson = <int, String>{
    for (final entry in catalog)
      if (entry.lessonNumber > 0) entry.lessonNumber: entry.title,
  };
  final topicsTotal = titleByLesson.length;

  var studyCorrect = 0;
  var studyWrong = 0;
  var studyUnanswered = 0;
  for (final sheet in studySheets) {
    studyCorrect += sheet.correct;
    studyWrong += sheet.wrong;
    studyUnanswered += sheet.unanswered;
  }

  final studyBuckets = <int, TopicAnswerCounts>{};
  final examBuckets = <int, TopicAnswerCounts>{};
  var examExcludedFromTopics = 0;

  for (final event in answerEvents) {
    if (event.source != StudentStatsSource.study &&
        event.source != StudentStatsSource.exam) {
      continue;
    }

    final lesson = event.lessonNumber;
    if (lesson == null || lesson <= 0) {
      if (event.source == StudentStatsSource.exam) {
        examExcludedFromTopics++;
      }
      continue;
    }

    final delta = TopicAnswerCounts(
      correct: event.isUnanswered ? 0 : (event.isCorrect ? 1 : 0),
      wrong: (!event.isUnanswered && !event.isCorrect) ? 1 : 0,
      unanswered: event.isUnanswered ? 1 : 0,
      lastActivity: event.completedAt,
    );

    if (event.source == StudentStatsSource.study) {
      studyBuckets[lesson] = (studyBuckets[lesson] ?? TopicAnswerCounts.empty)
          .merge(delta);
    } else {
      examBuckets[lesson] = (examBuckets[lesson] ?? TopicAnswerCounts.empty)
          .merge(delta);
    }
  }

  // Studio counts prefer sheet headers (activity metric); topic buckets
  // may also come from answer-level (multi) + sheet rollup events.
  // If answer events under-count vs sheets (lesson rows rolled as events),
  // study KPI still uses sheet headers.

  final topicsStudied = studyBuckets.keys
      .where((k) => (studyBuckets[k]?.questionsSeen ?? 0) > 0)
      .length;

  final study = StudyStatistics(
    sheetsCompleted: studySheets.length,
    correct: studyCorrect,
    wrong: studyWrong,
    unanswered: studyUnanswered,
    topicsStudied: topicsStudied,
    topicsTotal: topicsTotal,
  );

  final sortedExams = List<StudentStatsExamAttemptEvent>.of(examAttempts)
    ..sort((a, b) {
      final byDate = b.completedAt.compareTo(a.completedAt);
      if (byDate != 0) return byDate;
      // Tie-break deterministico (LOW Safe Review).
      return b.attemptId.compareTo(a.attemptId);
    });

  var passedCount = 0;
  var errorSum = 0;
  for (final attempt in sortedExams) {
    if (attempt.passed) passedCount++;
    errorSum += attempt.errorCount;
  }

  final exam = ExamStatistics(
    simulationsCount: sortedExams.length,
    passedCount: passedCount,
    averageErrors: sortedExams.isEmpty
        ? 0
        : errorSum / sortedExams.length,
    recentResults: sortedExams
        .take(5)
        .map(
          (a) => RecentExamResult(
            attemptId: a.attemptId,
            completedAt: a.completedAt,
            passed: a.passed,
            errorCount: a.errorCount,
          ),
        )
        .toList(growable: false),
    answersExcludedFromTopics: examExcludedFromTopics,
  );

  final topicsStudy = _topicsFromBuckets(
    buckets: studyBuckets,
    titleByLesson: titleByLesson,
  );
  final topicsExam = _topicsFromBuckets(
    buckets: examBuckets,
    titleByLesson: titleByLesson,
  );
  final topicsAll = _mergeTopicLists(topicsStudy, topicsExam, titleByLesson);

  return StudentQuizStatistics(
    categoryId: categoryId,
    study: study,
    exam: exam,
    topicsAll: topicsAll,
    topicsStudy: topicsStudy,
    topicsExam: topicsExam,
    reviewAll: selectStudentStatsReviewTopics(topicsAll),
    reviewStudy: selectStudentStatsReviewTopics(topicsStudy),
    reviewExam: selectStudentStatsReviewTopics(topicsExam),
    ignoredIncompleteLessonAttempts: ignoredIncompleteLessonAttempts,
    ignoredIncompleteMultiAttempts: ignoredIncompleteMultiAttempts,
    ignoredIncompleteExamAttempts: ignoredIncompleteExamAttempts,
  );
}

List<TopicStatistics> _topicsFromBuckets({
  required Map<int, TopicAnswerCounts> buckets,
  required Map<int, String> titleByLesson,
}) {
  final numbers = buckets.keys.toList()..sort();
  return [
    for (final n in numbers)
      if ((buckets[n]?.questionsSeen ?? 0) > 0)
        TopicStatistics(
          lessonNumber: n,
          title: titleByLesson[n] ?? 'Lezione $n',
          counts: buckets[n]!,
        ),
  ];
}

List<TopicStatistics> _mergeTopicLists(
  List<TopicStatistics> study,
  List<TopicStatistics> exam,
  Map<int, String> titleByLesson,
) {
  final merged = <int, TopicAnswerCounts>{};
  for (final t in study) {
    merged[t.lessonNumber] = t.counts;
  }
  for (final t in exam) {
    merged[t.lessonNumber] =
        (merged[t.lessonNumber] ?? TopicAnswerCounts.empty).merge(t.counts);
  }
  return _topicsFromBuckets(buckets: merged, titleByLesson: titleByLesson);
}

/// Top 3 "Da ripassare" con Laplace + soglie sample.
List<ReviewTopic> selectStudentStatsReviewTopics(
  List<TopicStatistics> topics, {
  int primaryMinSeen = kStudentStatsTop3PrimaryMinSeen,
  int fallbackMinSeen = kStudentStatsTop3FallbackMinSeen,
  int limit = kStudentStatsTop3Limit,
}) {
  if (topics.isEmpty || limit <= 0) return const [];

  List<TopicStatistics> eligible(int minSeen) {
    final list = topics.where((t) => t.questionsSeen >= minSeen).toList();
    list.sort(_compareReviewTopics);
    return list;
  }

  var selected = eligible(primaryMinSeen);
  if (selected.length < limit) {
    final primaryIds = selected.map((t) => t.lessonNumber).toSet();
    final fallback = eligible(fallbackMinSeen)
        .where((t) => !primaryIds.contains(t.lessonNumber));
    selected = [...selected, ...fallback];
  }

  // Hard floor: never include seen < fallbackMinSeen.
  selected = selected
      .where((t) => t.questionsSeen >= fallbackMinSeen)
      .toList();
  selected.sort(_compareReviewTopics);

  final top = selected.take(limit).toList(growable: false);
  return [
    for (var i = 0; i < top.length; i++)
      ReviewTopic(rank: i + 1, topic: top[i]),
  ];
}

int _compareReviewTopics(TopicStatistics a, TopicStatistics b) {
  final scoreA = studentStatsLaplaceErrorScore(
    errors: a.errors,
    seen: a.questionsSeen,
  );
  final scoreB = studentStatsLaplaceErrorScore(
    errors: b.errors,
    seen: b.questionsSeen,
  );
  final byScore = scoreB.compareTo(scoreA);
  if (byScore != 0) return byScore;

  final byErrors = b.errors.compareTo(a.errors);
  if (byErrors != 0) return byErrors;

  final aLast = a.lastActivity ?? DateTime.fromMillisecondsSinceEpoch(0);
  final bLast = b.lastActivity ?? DateTime.fromMillisecondsSinceEpoch(0);
  final byRecency = bLast.compareTo(aLast);
  if (byRecency != 0) return byRecency;

  return a.lessonNumber.compareTo(b.lessonNumber);
}

/// Conteggi distinct lesson_number dal catalogo quiz_sets (kind=lesson).
Set<int> distinctLessonNumbersFromCatalogSheets(
  Iterable<({int lessonNumber})> sheets,
) {
  return {
    for (final sheet in sheets)
      if (sheet.lessonNumber > 0) sheet.lessonNumber,
  };
}
