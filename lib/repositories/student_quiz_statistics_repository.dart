import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../data/supabase/dto/quiz_result_row.dart';
import '../data/supabase/dto/quiz_sheet_catalog_row.dart';
import '../data/supabase/mappers/quiz_statistics_mapper.dart';
import '../data/supabase/student_quiz_statistics_data_source.dart';
import '../domain/quiz_license_category.dart';
import '../domain/student_quiz_statistics_aggregator.dart';
import '../domain/student_quiz_statistics_input_helpers.dart';
import '../domain/student_quiz_statistics_models.dart';
import '../domain/student_stats_source.dart';
import '../models/license_models.dart';
import 'quiz_statistics_repository.dart'
    show QuizStatisticsUnauthenticatedException;

/// Repository STATISTICHE allievo v1 (Schede + Multischeda + Esame).
///
/// Assigned Quiz escluso. Nessuna scrittura DB.
abstract class StudentQuizStatisticsRepository {
  Future<StudentQuizStatistics> fetchCategoryStatistics({
    required LicenseCategoryId categoryId,
  });
}

class StudentQuizStatisticsRepositoryImpl
    implements StudentQuizStatisticsRepository {
  StudentQuizStatisticsRepositoryImpl({
    StudentQuizStatisticsDataSource? dataSource,
    Future<String?> Function()? resolveUserId,
  }) : _dataSource = dataSource ?? StudentQuizStatisticsDataSourceSupabase(),
       _resolveUserId =
           resolveUserId ??
           (() async => SupabaseConfig.isConfigured
               ? Supabase.instance.client.auth.currentUser?.id
               : null);

  final StudentQuizStatisticsDataSource _dataSource;
  final Future<String?> Function() _resolveUserId;

  @override
  Future<StudentQuizStatistics> fetchCategoryStatistics({
    required LicenseCategoryId categoryId,
  }) async {
    final dbCategory = dbLicenseCategoryFor(categoryId);
    if (dbCategory == null) {
      return StudentQuizStatistics.empty(categoryId);
    }

    final userId = await _resolveUserId();
    if (userId == null || userId.isEmpty) {
      throw const QuizStatisticsUnauthenticatedException();
    }

    // Round-trip paralleli indipendenti (Future.wait: errori non silenziati).
    final parallel = await Future.wait<Object?>([
      _dataSource.fetchLessonSheetCatalog(licenseCategoryDb: dbCategory),
      _dataSource.fetchLessonResultsForCategory(
        userId: userId,
        licenseCategoryDb: dbCategory,
      ),
      _dataSource.fetchMultiTopicAttempts(
        userId: userId,
        licenseCategoryDb: dbCategory,
      ),
      _dataSource.fetchExamAttempts(
        userId: userId,
        licenseCategoryDb: dbCategory,
      ),
    ]);

    final catalog = parallel[0]! as List<QuizSheetCatalogRow>;
    final lessonResults = parallel[1]! as List<QuizResultRow>;
    final multiAttemptsRaw = parallel[2]! as List<MultiTopicStatsAttemptRow>;
    final examAttemptsRaw = parallel[3]! as List<ExamStatsAttemptRow>;

    final catalogEntries = catalogEntriesFromLessonQuizSets(
      categoryId: categoryId,
      catalog: catalog,
    );

    Map<String, int> lessonAnswerCounts = const {};
    if (lessonResults.isNotEmpty) {
      lessonAnswerCounts = await _dataSource.fetchAnswerCountsByResultIds(
        userId: userId,
        quizResultIds: lessonResults.map((r) => r.id).toList(),
      );
    }

    final lessonPartition = partitionStatisticsAttempts(
      rows: lessonResults,
      answerCounts: lessonAnswerCounts,
    );

    final multiDeduped = dedupeMultiTopicStatsAttempts(multiAttemptsRaw);
    final multiValid = <MultiTopicStatsAttemptRow>[];
    var ignoredMulti = 0;
    for (final row in multiDeduped) {
      if (isCompleteMultiTopicStatsAttempt(row)) {
        multiValid.add(row);
      } else {
        ignoredMulti++;
      }
    }

    final examValid = <ExamStatsAttemptRow>[];
    var ignoredExam = 0;
    for (final row in examAttemptsRaw) {
      if (isCompleteExamStatsAttempt(row)) {
        examValid.add(row);
      } else {
        ignoredExam++;
      }
    }

    final multiAnswerFuture = multiValid.isEmpty
        ? Future.value(const <MultiTopicStatsAnswerRow>[])
        : _dataSource.fetchMultiTopicAnswers(
            attemptIds: multiValid.map((a) => a.id).toList(),
          );
    final examAnswerFuture = examValid.isEmpty
        ? Future.value(const <ExamStatsAnswerRow>[])
        : _dataSource.fetchExamAnswers(
            attemptIds: examValid.map((a) => a.id).toList(),
          );

    final multiAnswers = await multiAnswerFuture;
    final examAnswers = await examAnswerFuture;

    // Zero-answer guard: tentativi senza risposte utili non entrano.
    final multiAnswerCounts = <String, int>{};
    for (final a in multiAnswers) {
      multiAnswerCounts[a.attemptId] = (multiAnswerCounts[a.attemptId] ?? 0) + 1;
    }
    final multiWithAnswers = <MultiTopicStatsAttemptRow>[];
    var ignoredMultiNoAnswers = 0;
    for (final attempt in multiValid) {
      final count = multiAnswerCounts[attempt.id] ?? 0;
      if (count == 0 || count != attempt.totalQuestions) {
        ignoredMultiNoAnswers++;
        continue;
      }
      multiWithAnswers.add(attempt);
    }

    final examAnswerCounts = <String, int>{};
    for (final a in examAnswers) {
      examAnswerCounts[a.attemptId] = (examAnswerCounts[a.attemptId] ?? 0) + 1;
    }
    final examWithAnswers = <ExamStatsAttemptRow>[];
    var ignoredExamNoAnswers = 0;
    for (final attempt in examValid) {
      final count = examAnswerCounts[attempt.id] ?? 0;
      if (count == 0 || count != attempt.totalQuestions) {
        ignoredExamNoAnswers++;
        continue;
      }
      examWithAnswers.add(attempt);
    }

    final examQuestionIds = examAnswers
        .where((a) => examWithAnswers.any((e) => e.id == a.attemptId))
        .map((a) => a.questionId)
        .toSet()
        .toList();

    final questionLessons = examQuestionIds.isEmpty
        ? const <String, int?>{}
        : await _dataSource.fetchQuestionLessonNumbers(
            questionIds: examQuestionIds,
          );

    final studySheets = <StudentStatsSheetEvent>[];
    final answerEvents = <StudentStatsAnswerEvent>[];

    for (final row in lessonPartition.validResults) {
      final at = activityTimestamp(row);
      studySheets.add(
        StudentStatsSheetEvent(
          completedAt: at,
          correct: row.correctCount,
          wrong: row.wrongCount,
          unanswered: row.unansweredCount,
        ),
      );
      // Schede: attributo topic = quiz_sets.lesson_number (rollup header).
      addRollupAnswerEvents(
        into: answerEvents,
        source: StudentStatsSource.study,
        lessonNumber: row.lessonNumber,
        completedAt: at,
        correct: row.correctCount,
        wrong: row.wrongCount,
        unanswered: row.unansweredCount,
      );
    }

    final multiIds = multiWithAnswers.map((a) => a.id).toSet();
    final multiById = {
      for (final a in multiWithAnswers) a.id: a,
    };
    for (final attempt in multiWithAnswers) {
      studySheets.add(
        StudentStatsSheetEvent(
          completedAt: attempt.completedAt,
          correct: attempt.correctCount,
          wrong: attempt.wrongCount,
          unanswered: attempt.unansweredCount,
        ),
      );
    }
    for (final answer in multiAnswers) {
      if (!multiIds.contains(answer.attemptId)) continue;
      final attempt = multiById[answer.attemptId]!;
      answerEvents.add(
        StudentStatsAnswerEvent(
          source: StudentStatsSource.study,
          lessonNumber: answer.lessonNumberSnapshot,
          isCorrect: answer.isCorrect,
          isUnanswered: answer.isUnanswered,
          completedAt: attempt.completedAt,
        ),
      );
    }

    final examIds = examWithAnswers.map((a) => a.id).toSet();
    final examById = {for (final a in examWithAnswers) a.id: a};
    final examAttemptEvents = <StudentStatsExamAttemptEvent>[
      for (final a in examWithAnswers)
        StudentStatsExamAttemptEvent(
          attemptId: a.id,
          completedAt: a.completedAt,
          passed: a.passed,
          correct: a.correctCount,
          wrong: a.wrongCount,
          unanswered: a.unansweredCount,
        ),
    ];

    for (final answer in examAnswers) {
      if (!examIds.contains(answer.attemptId)) continue;
      final attempt = examById[answer.attemptId]!;
      answerEvents.add(
        StudentStatsAnswerEvent(
          source: StudentStatsSource.exam,
          lessonNumber: questionLessons[answer.questionId],
          isCorrect: answer.isCorrect,
          isUnanswered: answer.isUnanswered,
          completedAt: attempt.completedAt,
        ),
      );
    }

    return buildStudentQuizStatistics(
      categoryId: categoryId,
      studySheets: studySheets,
      examAttempts: examAttemptEvents,
      answerEvents: answerEvents,
      catalog: catalogEntries,
      ignoredIncompleteLessonAttempts:
          lessonPartition.ignoredIncompleteAttempts,
      ignoredIncompleteMultiAttempts: ignoredMulti + ignoredMultiNoAnswers,
      ignoredIncompleteExamAttempts: ignoredExam + ignoredExamNoAnswers,
    );
  }

}

class StudentQuizStatisticsRepositoryEmpty
    implements StudentQuizStatisticsRepository {
  const StudentQuizStatisticsRepositoryEmpty();

  @override
  Future<StudentQuizStatistics> fetchCategoryStatistics({
    required LicenseCategoryId categoryId,
  }) async {
    return StudentQuizStatistics.empty(categoryId);
  }
}

StudentQuizStatisticsRepository get studentQuizStatisticsRepository {
  if (SupabaseConfig.isConfigured) {
    return StudentQuizStatisticsRepositoryImpl();
  }
  return const StudentQuizStatisticsRepositoryEmpty();
}
