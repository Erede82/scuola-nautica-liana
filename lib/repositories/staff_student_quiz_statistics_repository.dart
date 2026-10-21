import 'package:postgrest/postgrest.dart';

import '../config/supabase_config.dart';
import '../data/supabase/dto/staff_student_quiz_statistics_rpc_payload.dart';
import '../data/supabase/mappers/quiz_statistics_mapper.dart';
import '../data/supabase/staff_student_quiz_statistics_data_source.dart';
import '../data/supabase/student_quiz_statistics_data_source.dart';
import '../domain/quiz_license_category.dart';
import '../domain/student_quiz_statistics_aggregator.dart';
import '../domain/student_quiz_statistics_input_helpers.dart';
import '../domain/student_quiz_statistics_models.dart';
import '../domain/student_stats_source.dart';
import '../models/license_models.dart';

/// Esito load staff statistics (prima dell’aggregatore o stati speciali).
sealed class StaffStudentQuizStatisticsResult {
  const StaffStudentQuizStatisticsResult();
}

/// Allievo esistente ma senza Auth quiz collegata.
class StaffStudentQuizStatisticsUnlinked
    extends StaffStudentQuizStatisticsResult {
  const StaffStudentQuizStatisticsUnlinked();
}

/// Categoria non supportata dal RPC (es. Vela) — RPC non chiamato.
class StaffStudentQuizStatisticsUnsupportedCategory
    extends StaffStudentQuizStatisticsResult {
  const StaffStudentQuizStatisticsUnsupportedCategory();
}

/// Statistiche aggregate (linked_user true, anche se history vuota).
class StaffStudentQuizStatisticsLoaded
    extends StaffStudentQuizStatisticsResult {
  const StaffStudentQuizStatisticsLoaded(this.statistics);

  final StudentQuizStatistics statistics;
}

class StaffStudentQuizStatisticsNotAuthorized
    extends StaffStudentQuizStatisticsResult {
  const StaffStudentQuizStatisticsNotAuthorized();
}

class StaffStudentQuizStatisticsStudentNotFound
    extends StaffStudentQuizStatisticsResult {
  const StaffStudentQuizStatisticsStudentNotFound();
}

class StaffStudentQuizStatisticsFailure
    extends StaffStudentQuizStatisticsResult {
  const StaffStudentQuizStatisticsFailure(this.error);

  final Object error;
}

/// Repository staff READ-ONLY — separato dal self repository.
abstract class StaffStudentQuizStatisticsRepository {
  /// [studentId] = `public.students.id` (mai auth UUID dalla UI).
  Future<StaffStudentQuizStatisticsResult> fetchStudentCategoryStatistics({
    required String studentId,
    required LicenseCategoryId categoryId,
  });
}

class StaffStudentQuizStatisticsRepositoryImpl
    implements StaffStudentQuizStatisticsRepository {
  StaffStudentQuizStatisticsRepositoryImpl({
    StaffStudentQuizStatisticsDataSource? dataSource,
  }) : _dataSource =
           dataSource ?? StaffStudentQuizStatisticsDataSourceSupabase();

  final StaffStudentQuizStatisticsDataSource _dataSource;

  @override
  Future<StaffStudentQuizStatisticsResult> fetchStudentCategoryStatistics({
    required String studentId,
    required LicenseCategoryId categoryId,
  }) async {
    final dbCategory = dbLicenseCategoryFor(categoryId);
    if (dbCategory == null) {
      return const StaffStudentQuizStatisticsUnsupportedCategory();
    }

    try {
      final payload = await _dataSource.fetchInputs(
        studentId: studentId,
        licenseCategoryDb: dbCategory,
      );
      if (!payload.linkedUser) {
        return const StaffStudentQuizStatisticsUnlinked();
      }
      final stats = assembleStudentQuizStatisticsFromStaffPayload(
        categoryId: categoryId,
        payload: payload,
      );
      return StaffStudentQuizStatisticsLoaded(stats);
    } on PostgrestException catch (e) {
      final mapped = _mapPostgrest(e);
      if (mapped != null) return mapped;
      return StaffStudentQuizStatisticsFailure(e);
    } catch (e) {
      return StaffStudentQuizStatisticsFailure(e);
    }
  }

  StaffStudentQuizStatisticsResult? _mapPostgrest(PostgrestException e) {
    final msg = e.message.toLowerCase();
    final details = (e.details?.toString() ?? '').toLowerCase();
    final hint = (e.hint ?? '').toLowerCase();
    final blob = '$msg $details $hint';
    if (blob.contains('not authorized')) {
      return const StaffStudentQuizStatisticsNotAuthorized();
    }
    if (blob.contains('student_not_found')) {
      return const StaffStudentQuizStatisticsStudentNotFound();
    }
    return null;
  }
}

/// Pure: payload RPC → stessi input di [buildStudentQuizStatistics] del path self.
StudentQuizStatistics assembleStudentQuizStatisticsFromStaffPayload({
  required LicenseCategoryId categoryId,
  required StaffStudentQuizStatisticsRpcPayload payload,
}) {
  final catalogEntries = catalogEntriesFromLessonQuizSets(
    categoryId: categoryId,
    catalog: payload.lessonCatalog,
  );

  final lessonPartition = partitionStatisticsAttempts(
    rows: payload.lessonAttempts,
    answerCounts: payload.lessonAnswerCounts,
  );

  final multiDeduped = dedupeMultiTopicStatsAttempts(payload.multiAttempts);
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
  for (final row in payload.examAttempts) {
    if (isCompleteExamStatsAttempt(row)) {
      examValid.add(row);
    } else {
      ignoredExam++;
    }
  }

  final multiAnswerCounts = <String, int>{};
  for (final a in payload.multiAnswerEvents) {
    multiAnswerCounts[a.attemptId] =
        (multiAnswerCounts[a.attemptId] ?? 0) + 1;
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
  for (final a in payload.examAnswerEvents) {
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
  final multiById = {for (final a in multiWithAnswers) a.id: a};
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
  for (final answer in payload.multiAnswerEvents) {
    if (!multiIds.contains(answer.attemptId)) continue;
    final attempt = multiById[answer.attemptId];
    if (attempt == null) continue;
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

  for (final answer in payload.examAnswerEvents) {
    if (!examIds.contains(answer.attemptId)) continue;
    final attempt = examById[answer.attemptId];
    if (attempt == null) continue;
    answerEvents.add(
      StudentStatsAnswerEvent(
        source: StudentStatsSource.exam,
        lessonNumber: answer.lessonNumber,
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
    ignoredIncompleteLessonAttempts: lessonPartition.ignoredIncompleteAttempts,
    ignoredIncompleteMultiAttempts: ignoredMulti + ignoredMultiNoAnswers,
    ignoredIncompleteExamAttempts: ignoredExam + ignoredExamNoAnswers,
  );
}

StaffStudentQuizStatisticsRepository get staffStudentQuizStatisticsRepository {
  if (SupabaseConfig.isConfigured) {
    return StaffStudentQuizStatisticsRepositoryImpl();
  }
  return const _StaffStudentQuizStatisticsRepositoryEmpty();
}

class _StaffStudentQuizStatisticsRepositoryEmpty
    implements StaffStudentQuizStatisticsRepository {
  const _StaffStudentQuizStatisticsRepositoryEmpty();

  @override
  Future<StaffStudentQuizStatisticsResult> fetchStudentCategoryStatistics({
    required String studentId,
    required LicenseCategoryId categoryId,
  }) async {
    if (dbLicenseCategoryFor(categoryId) == null) {
      return const StaffStudentQuizStatisticsUnsupportedCategory();
    }
    return const StaffStudentQuizStatisticsUnlinked();
  }
}
