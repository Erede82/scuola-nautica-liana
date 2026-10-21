import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/data/supabase/dto/quiz_result_row.dart';
import 'package:scuola_nautica_liana/data/supabase/dto/quiz_sheet_catalog_row.dart';
import 'package:scuola_nautica_liana/data/supabase/dto/staff_student_quiz_statistics_rpc_payload.dart';
import 'package:scuola_nautica_liana/data/supabase/mappers/quiz_statistics_mapper.dart';
import 'package:scuola_nautica_liana/data/supabase/student_quiz_statistics_data_source.dart';
import 'package:scuola_nautica_liana/domain/student_quiz_statistics_aggregator.dart';
import 'package:scuola_nautica_liana/domain/student_quiz_statistics_input_helpers.dart';
import 'package:scuola_nautica_liana/domain/student_quiz_statistics_models.dart';
import 'package:scuola_nautica_liana/domain/student_stats_source.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';
import 'package:scuola_nautica_liana/repositories/staff_student_quiz_statistics_repository.dart';

/// Path A: assembly stile self-repository (stessi helper pubblici).
StudentQuizStatistics _assembleSelfStyle({
  required List<QuizResultRow> lessons,
  required Map<String, int> lessonAnswerCounts,
  required List<MultiTopicStatsAttemptRow> multiAttempts,
  required List<MultiTopicStatsAnswerRow> multiAnswers,
  required List<ExamStatsAttemptRow> examAttempts,
  required Map<String, int?> examQuestionLessons,
  required List<ExamStatsAnswerRow> examAnswers,
  required List<QuizSheetCatalogRow> catalog,
}) {
  final catalogEntries = catalogEntriesFromLessonQuizSets(
    categoryId: LicenseCategoryId.motore,
    catalog: catalog,
  );
  final lessonPartition = partitionStatisticsAttempts(
    rows: lessons,
    answerCounts: lessonAnswerCounts,
  );
  final multiDeduped = dedupeMultiTopicStatsAttempts(multiAttempts);
  final multiValid = multiDeduped
      .where(isCompleteMultiTopicStatsAttempt)
      .toList();
  final examValid = examAttempts.where(isCompleteExamStatsAttempt).toList();

  final multiAnswerCounts = <String, int>{};
  for (final a in multiAnswers) {
    multiAnswerCounts[a.attemptId] =
        (multiAnswerCounts[a.attemptId] ?? 0) + 1;
  }
  final multiWithAnswers = multiValid
      .where((a) {
        final c = multiAnswerCounts[a.id] ?? 0;
        return c > 0 && c == a.totalQuestions;
      })
      .toList();

  final examAnswerCounts = <String, int>{};
  for (final a in examAnswers) {
    examAnswerCounts[a.attemptId] = (examAnswerCounts[a.attemptId] ?? 0) + 1;
  }
  final examWithAnswers = examValid
      .where((a) {
        final c = examAnswerCounts[a.id] ?? 0;
        return c > 0 && c == a.totalQuestions;
      })
      .toList();

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
  for (final a in multiWithAnswers) {
    studySheets.add(
      StudentStatsSheetEvent(
        completedAt: a.completedAt,
        correct: a.correctCount,
        wrong: a.wrongCount,
        unanswered: a.unansweredCount,
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
  final examEvents = <StudentStatsExamAttemptEvent>[
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
        lessonNumber: examQuestionLessons[answer.questionId],
        isCorrect: answer.isCorrect,
        isUnanswered: answer.isUnanswered,
        completedAt: attempt.completedAt,
      ),
    );
  }

  return buildStudentQuizStatistics(
    categoryId: LicenseCategoryId.motore,
    studySheets: studySheets,
    examAttempts: examEvents,
    answerEvents: answerEvents,
    catalog: catalogEntries,
    ignoredIncompleteLessonAttempts: lessonPartition.ignoredIncompleteAttempts,
    ignoredIncompleteMultiAttempts:
        multiDeduped.length - multiWithAnswers.length,
    ignoredIncompleteExamAttempts: examAttempts.length - examWithAnswers.length,
  );
}

void main() {
  test('STAFF.STUDENT.STATS.1 parity: staff RPC assembly == self-style', () {
    final lesson = QuizResultRow(
      id: 'lesson-1',
      quizSetId: 'set-1-1',
      totalQuestions: 20,
      correctCount: 16,
      wrongCount: 2,
      unansweredCount: 2,
      lessonNumber: 1,
      sheetNumber: 1,
      licenseCategory: 'A12',
      kind: 'lesson',
      completedAt: DateTime.utc(2026, 10, 1),
      createdAt: DateTime.utc(2026, 10, 1),
    );
    final multiA = MultiTopicStatsAttemptRow(
      id: 'multi-old',
      userId: 'u1',
      licenseCategory: 'A12',
      sessionId: 'sess-1',
      sheetIndex: 1,
      completedAt: DateTime.utc(2026, 10, 2, 10),
      totalQuestions: 10,
      correctCount: 5,
      wrongCount: 3,
      unansweredCount: 2,
    );
    final multiB = MultiTopicStatsAttemptRow(
      id: 'multi-new',
      userId: 'u1',
      licenseCategory: 'A12',
      sessionId: 'sess-1',
      sheetIndex: 1,
      completedAt: DateTime.utc(2026, 10, 2, 12),
      totalQuestions: 10,
      correctCount: 7,
      wrongCount: 2,
      unansweredCount: 1,
    );
    final multiAnswers = [
      for (var i = 0; i < 7; i++)
        const MultiTopicStatsAnswerRow(
          attemptId: 'multi-new',
          lessonNumberSnapshot: 2,
          isCorrect: true,
          isUnanswered: false,
        ),
      for (var i = 0; i < 2; i++)
        const MultiTopicStatsAnswerRow(
          attemptId: 'multi-new',
          lessonNumberSnapshot: 2,
          isCorrect: false,
          isUnanswered: false,
        ),
      const MultiTopicStatsAnswerRow(
        attemptId: 'multi-new',
        lessonNumberSnapshot: 2,
        isCorrect: false,
        isUnanswered: true,
      ),
      // old attempt answers (should be ignored after dedupe)
      for (var i = 0; i < 10; i++)
        const MultiTopicStatsAnswerRow(
          attemptId: 'multi-old',
          lessonNumberSnapshot: 2,
          isCorrect: true,
          isUnanswered: false,
        ),
    ];
    final exam = ExamStatsAttemptRow(
      id: 'exam-1',
      userId: 'u1',
      licenseCategory: 'A12',
      completedAt: DateTime.utc(2026, 10, 3),
      totalQuestions: 20,
      correctCount: 15,
      wrongCount: 3,
      unansweredCount: 2,
      passed: true,
    );
    final examAnswers = [
      for (var i = 0; i < 15; i++)
        ExamStatsAnswerRow(
          attemptId: 'exam-1',
          questionId: 'q-c-$i',
          isCorrect: true,
          isUnanswered: false,
        ),
      for (var i = 0; i < 3; i++)
        ExamStatsAnswerRow(
          attemptId: 'exam-1',
          questionId: 'q-w-$i',
          isCorrect: false,
          isUnanswered: false,
        ),
      for (var i = 0; i < 2; i++)
        ExamStatsAnswerRow(
          attemptId: 'exam-1',
          questionId: 'q-u-$i',
          isCorrect: false,
          isUnanswered: true,
        ),
    ];
    final examLessons = <String, int?>{
      for (var i = 0; i < 15; i++) 'q-c-$i': 3,
      for (var i = 0; i < 3; i++) 'q-w-$i': 3,
      for (var i = 0; i < 2; i++) 'q-u-$i': null,
    };
    final catalog = [
      const QuizSheetCatalogRow(
        id: 'set-1-1',
        kind: 'lesson',
        licenseCategory: 'A12',
        lessonNumber: 1,
        sheetNumber: 1,
      ),
      const QuizSheetCatalogRow(
        id: 'set-2-1',
        kind: 'lesson',
        licenseCategory: 'A12',
        lessonNumber: 2,
        sheetNumber: 1,
      ),
      const QuizSheetCatalogRow(
        id: 'set-3-1',
        kind: 'lesson',
        licenseCategory: 'A12',
        lessonNumber: 3,
        sheetNumber: 1,
      ),
    ];

    final selfStats = _assembleSelfStyle(
      lessons: [lesson],
      lessonAnswerCounts: {'lesson-1': 20},
      multiAttempts: [multiA, multiB],
      multiAnswers: multiAnswers,
      examAttempts: [exam],
      examQuestionLessons: examLessons,
      examAnswers: examAnswers,
      catalog: catalog,
    );

    final staffPayload = StaffStudentQuizStatisticsRpcPayload(
      linkedUser: true,
      category: 'A12',
      lessonAttempts: [lesson],
      lessonAnswerCounts: {'lesson-1': 20},
      multiAttempts: [multiA, multiB],
      multiAnswerEvents: multiAnswers,
      examAttempts: [exam],
      examAnswerEvents: [
        for (final a in examAnswers)
          StaffExamAnswerEvent(
            attemptId: a.attemptId,
            lessonNumber: examLessons[a.questionId],
            isCorrect: a.isCorrect,
            isUnanswered: a.isUnanswered,
          ),
      ],
      lessonCatalog: catalog,
    );

    final staffStats = assembleStudentQuizStatisticsFromStaffPayload(
      categoryId: LicenseCategoryId.motore,
      payload: staffPayload,
    );

    expect(staffStats.study.sheetsCompleted, selfStats.study.sheetsCompleted);
    expect(staffStats.study.correct, selfStats.study.correct);
    expect(staffStats.study.wrong, selfStats.study.wrong);
    expect(staffStats.study.unanswered, selfStats.study.unanswered);
    expect(staffStats.study.topicsStudied, selfStats.study.topicsStudied);
    expect(staffStats.study.topicsTotal, selfStats.study.topicsTotal);
    expect(staffStats.study.accuracyPercentage, selfStats.study.accuracyPercentage);

    expect(staffStats.exam.simulationsCount, selfStats.exam.simulationsCount);
    expect(staffStats.exam.passedCount, selfStats.exam.passedCount);
    expect(staffStats.exam.averageErrors, selfStats.exam.averageErrors);
    expect(staffStats.exam.passRatePercentage, selfStats.exam.passRatePercentage);
    expect(
      staffStats.exam.recentResults.length,
      selfStats.exam.recentResults.length,
    );

    expect(staffStats.reviewAll.length, selfStats.reviewAll.length);
    for (var i = 0; i < staffStats.reviewAll.length; i++) {
      expect(staffStats.reviewAll[i].rank, selfStats.reviewAll[i].rank);
      expect(
        staffStats.reviewAll[i].topic.lessonNumber,
        selfStats.reviewAll[i].topic.lessonNumber,
      );
      expect(
        staffStats.reviewAll[i].topic.accuracyPercentage,
        selfStats.reviewAll[i].topic.accuracyPercentage,
      );
    }

    expect(staffStats.topicsAll.length, selfStats.topicsAll.length);
    for (var i = 0; i < staffStats.topicsAll.length; i++) {
      final a = staffStats.topicsAll[i];
      final b = selfStats.topicsAll[i];
      expect(a.lessonNumber, b.lessonNumber);
      expect(a.correct, b.correct);
      expect(a.wrong, b.wrong);
      expect(a.unanswered, b.unanswered);
      expect(a.questionsSeen, b.questionsSeen);
      expect(a.accuracyPercentage, b.accuracyPercentage);
      expect(a.lastActivity, b.lastActivity);
    }
  });
}
