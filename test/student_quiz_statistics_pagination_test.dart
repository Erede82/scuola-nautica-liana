import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/data/supabase/dto/quiz_sheet_catalog_row.dart';
import 'package:scuola_nautica_liana/data/supabase/student_quiz_statistics_data_source.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';
import 'package:scuola_nautica_liana/repositories/student_quiz_statistics_repository.dart';

const _catalog = [
  QuizSheetCatalogRow(
    id: 'a12-1-1',
    kind: 'lesson',
    licenseCategory: 'A12',
    lessonNumber: 1,
    sheetNumber: 1,
  ),
];

ExamStatsAttemptRow _exam({
  required int index,
  required int wrong,
  required bool passed,
}) {
  return ExamStatsAttemptRow(
    id: 'exam-$index',
    userId: 'user-1',
    licenseCategory: 'A12',
    completedAt: DateTime.utc(2026, 1, 1).add(Duration(days: index)),
    totalQuestions: 20,
    correctCount: 20 - wrong,
    wrongCount: wrong,
    unansweredCount: 0,
    passed: passed,
  );
}

List<ExamStatsAnswerRow> _examAnswers(int index) {
  return [
    for (var position = 0; position < 20; position++)
      ExamStatsAnswerRow(
        attemptId: 'exam-$index',
        questionId: 'exam-$index-q$position',
        isCorrect: position >= 1,
        isUnanswered: false,
      ),
  ];
}

MultiTopicStatsAttemptRow _multi({required int index, required int wrong}) {
  return MultiTopicStatsAttemptRow(
    id: 'multi-$index',
    userId: 'user-1',
    licenseCategory: 'A12',
    sessionId: 'session-$index',
    sheetIndex: 1,
    completedAt: DateTime.utc(2026, 2, 1).add(Duration(days: index)),
    totalQuestions: 20,
    correctCount: 20 - wrong,
    wrongCount: wrong,
    unansweredCount: 0,
  );
}

List<MultiTopicStatsAnswerRow> _multiAnswers(int index) {
  return [
    for (var position = 0; position < 20; position++)
      MultiTopicStatsAnswerRow(
        attemptId: 'multi-$index',
        lessonNumberSnapshot: 1,
        isCorrect: position >= 1,
        isUnanswered: false,
      ),
  ];
}

void main() {
  test('58 complete exams keep headers, pass rate, and every answer', () async {
    const count = 58;
    final attempts = [
      for (var i = 0; i < count; i++)
        _exam(index: i, wrong: i < 50 ? 1 : 10, passed: i < 30),
    ];
    final answers = [for (var i = 0; i < count; i++) ..._examAnswers(i)];
    expect(answers, hasLength(1160));

    final stats = await StudentQuizStatisticsRepositoryImpl(
      dataSource: StudentQuizStatisticsDataSourceFake(
        catalog: _catalog,
        examAttempts: attempts,
        examAnswers: answers,
        questionLessonNumbers: {
          for (final answer in answers) answer.questionId: 1,
        },
      ),
      resolveUserId: () async => 'user-1',
    ).fetchCategoryStatistics(categoryId: LicenseCategoryId.motore);

    expect(stats.exam.simulationsCount, 58);
    expect(stats.exam.passedCount, 30);
    expect(stats.exam.simulationsCount - stats.exam.passedCount, 28);
    expect(stats.exam.passRate, 30 / 58);
    expect(stats.exam.averageErrors, (50 * 1 + 8 * 10) / 58);
    expect(stats.topicsExam.single.counts.questionsSeen, 1160);
    expect(stats.ignoredIncompleteExamAttempts, 0);
  });

  test('exam headlines stay on headers when answers are partial', () async {
    const count = 58;
    final attempts = [
      for (var i = 0; i < count; i++)
        _exam(index: i, wrong: i < 50 ? 1 : 10, passed: i < 30),
    ];
    final answers = [for (var i = 0; i < 10; i++) ..._examAnswers(i)];

    final stats = await StudentQuizStatisticsRepositoryImpl(
      dataSource: StudentQuizStatisticsDataSourceFake(
        catalog: _catalog,
        examAttempts: attempts,
        examAnswers: answers,
        questionLessonNumbers: {
          for (final answer in answers) answer.questionId: 1,
        },
      ),
      resolveUserId: () async => 'user-1',
    ).fetchCategoryStatistics(categoryId: LicenseCategoryId.motore);

    expect(stats.exam.simulationsCount, 58);
    expect(stats.exam.passedCount, 30);
    expect(stats.exam.passRate, 30 / 58);
    expect(stats.exam.averageErrors, (50 * 1 + 8 * 10) / 58);
    expect(stats.topicsExam.single.counts.questionsSeen, 200);
  });

  test('91 complete multi sheets keep every header and answer', () async {
    const count = 91;
    final attempts = [
      for (var i = 0; i < count; i++) _multi(index: i, wrong: i < 50 ? 1 : 4),
    ];
    final answers = [for (var i = 0; i < count; i++) ..._multiAnswers(i)];
    expect(answers, hasLength(1820));

    final stats = await StudentQuizStatisticsRepositoryImpl(
      dataSource: StudentQuizStatisticsDataSourceFake(
        catalog: _catalog,
        multiAttempts: attempts,
        multiAnswers: answers,
      ),
      resolveUserId: () async => 'user-1',
    ).fetchCategoryStatistics(categoryId: LicenseCategoryId.motore);

    expect(stats.study.sheetsCompleted, 91);
    expect(stats.study.wrong, 50 * 1 + 41 * 4);
    expect(stats.topicsStudy.single.counts.questionsSeen, 1820);
    expect(stats.ignoredIncompleteMultiAttempts, 0);
  });
}
