import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/data/supabase/dto/quiz_result_row.dart';
import 'package:scuola_nautica_liana/data/supabase/dto/quiz_sheet_catalog_row.dart';
import 'package:scuola_nautica_liana/data/supabase/student_quiz_statistics_data_source.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';
import 'package:scuola_nautica_liana/repositories/quiz_statistics_repository.dart';
import 'package:scuola_nautica_liana/repositories/student_quiz_statistics_repository.dart';

QuizResultRow _lessonResult({
  required String id,
  required int lesson,
  required int sheet,
  int correct = 16,
  int wrong = 2,
  int unanswered = 2,
  String category = 'A12',
}) {
  return QuizResultRow(
    id: id,
    quizSetId: 'set-$lesson-$sheet',
    totalQuestions: correct + wrong + unanswered,
    correctCount: correct,
    wrongCount: wrong,
    unansweredCount: unanswered,
    lessonNumber: lesson,
    sheetNumber: sheet,
    licenseCategory: category,
    kind: 'lesson',
    completedAt: DateTime.utc(2026, 10, 1, lesson, sheet),
  );
}

MultiTopicStatsAttemptRow _multi({
  required String id,
  required String userId,
  required String category,
  int correct = 10,
  int wrong = 5,
  int unanswered = 5,
}) {
  final total = correct + wrong + unanswered;
  return MultiTopicStatsAttemptRow(
    id: id,
    userId: userId,
    licenseCategory: category,
    sessionId: 'session-$id',
    sheetIndex: 1,
    completedAt: DateTime.utc(2026, 10, 2),
    totalQuestions: total,
    correctCount: correct,
    wrongCount: wrong,
    unansweredCount: unanswered,
  );
}

ExamStatsAttemptRow _exam({
  required String id,
  required String userId,
  required String category,
  bool passed = true,
  int correct = 15,
  int wrong = 3,
  int unanswered = 2,
}) {
  final total = correct + wrong + unanswered;
  return ExamStatsAttemptRow(
    id: id,
    userId: userId,
    licenseCategory: category,
    completedAt: DateTime.utc(2026, 10, 3),
    totalQuestions: total,
    correctCount: correct,
    wrongCount: wrong,
    unansweredCount: unanswered,
    passed: passed,
  );
}

List<MultiTopicStatsAnswerRow> _multiAnswersFor(
  String attemptId, {
  required int correct,
  required int wrong,
  required int unanswered,
  int lesson = 2,
}) {
  return [
    for (var i = 0; i < correct; i++)
      MultiTopicStatsAnswerRow(
        attemptId: attemptId,
        lessonNumberSnapshot: lesson,
        isCorrect: true,
        isUnanswered: false,
      ),
    for (var i = 0; i < wrong; i++)
      MultiTopicStatsAnswerRow(
        attemptId: attemptId,
        lessonNumberSnapshot: lesson,
        isCorrect: false,
        isUnanswered: false,
      ),
    for (var i = 0; i < unanswered; i++)
      MultiTopicStatsAnswerRow(
        attemptId: attemptId,
        lessonNumberSnapshot: lesson,
        isCorrect: false,
        isUnanswered: true,
      ),
  ];
}

List<ExamStatsAnswerRow> _examAnswersFor(
  String attemptId, {
  required int correct,
  required int wrong,
  required int unanswered,
}) {
  final out = <ExamStatsAnswerRow>[];
  var q = 0;
  for (var i = 0; i < correct; i++) {
    out.add(
      ExamStatsAnswerRow(
        attemptId: attemptId,
        questionId: '$attemptId-q${q++}',
        isCorrect: true,
        isUnanswered: false,
      ),
    );
  }
  for (var i = 0; i < wrong; i++) {
    out.add(
      ExamStatsAnswerRow(
        attemptId: attemptId,
        questionId: '$attemptId-q${q++}',
        isCorrect: false,
        isUnanswered: false,
      ),
    );
  }
  for (var i = 0; i < unanswered; i++) {
    out.add(
      ExamStatsAnswerRow(
        attemptId: attemptId,
        questionId: '$attemptId-q${q++}',
        isCorrect: false,
        isUnanswered: true,
      ),
    );
  }
  return out;
}

void main() {
  group('StudentQuizStatisticsRepositoryImpl', () {
    test('maps lesson + multi + exam; Assigned excluded; D1 catalog denom',
        () async {
      final fake = StudentQuizStatisticsDataSourceFake(
        catalog: [
          for (var lesson = 1; lesson <= 10; lesson++)
            for (var sheet = 1; sheet <= 2; sheet++)
              QuizSheetCatalogRow(
                id: 'd1-$lesson-$sheet',
                kind: 'lesson',
                licenseCategory: 'D1',
                lessonNumber: lesson,
                sheetNumber: sheet,
              ),
        ],
        lessonResults: [
          _lessonResult(
            id: 'lr1',
            lesson: 1,
            sheet: 1,
            category: 'D1',
            correct: 12,
            wrong: 2,
            unanswered: 1,
          ),
        ],
        answerCounts: const {'lr1': 15},
        multiAttempts: [
          _multi(id: 'm1', userId: 'user-1', category: 'D1'),
        ],
        multiAnswers: _multiAnswersFor(
          'm1',
          correct: 10,
          wrong: 5,
          unanswered: 5,
        ),
        examAttempts: [
          _exam(id: 'e1', userId: 'user-1', category: 'D1'),
        ],
        examAnswers: _examAnswersFor(
          'e1',
          correct: 15,
          wrong: 3,
          unanswered: 2,
        ),
        questionLessonNumbers: {
          for (var i = 0; i < 18; i++) 'e1-q$i': 3,
          'e1-q18': null,
          'e1-q19': null,
        },
      );

      final repo = StudentQuizStatisticsRepositoryImpl(
        dataSource: fake,
        resolveUserId: () async => 'user-1',
      );

      final stats = await repo.fetchCategoryStatistics(
        categoryId: LicenseCategoryId.d1,
      );

      expect(stats.study.topicsTotal, 10);
      expect(stats.study.sheetsCompleted, 2); // lesson + multi
      expect(stats.exam.simulationsCount, 1);
      expect(stats.exam.passedCount, 1);
      expect(stats.exam.answersExcludedFromTopics, 2);
      expect(stats.topicsStudy.any((t) => t.lessonNumber == 1), isTrue);
      expect(stats.topicsStudy.any((t) => t.lessonNumber == 2), isTrue);
      expect(stats.topicsExam.any((t) => t.lessonNumber == 3), isTrue);
      expect(fake.lastMultiUserId, 'user-1');
      expect(fake.lastMultiLicenseCategoryDb, 'D1');
      expect(fake.lastExamUserId, 'user-1');
      expect(fake.lastExamLicenseCategoryDb, 'D1');
    });

    test('staff scenario: USER_A stats exclude USER_B multi+exam', () async {
      const userA = 'USER_A';
      const userB = 'USER_B';

      final fake = StudentQuizStatisticsDataSourceFake(
        catalog: [
          const QuizSheetCatalogRow(
            id: 'a12-1-1',
            kind: 'lesson',
            licenseCategory: 'A12',
            lessonNumber: 1,
            sheetNumber: 1,
          ),
        ],
        multiAttempts: [
          _multi(id: 'm-a', userId: userA, category: 'A12', correct: 18, wrong: 1, unanswered: 1),
          _multi(id: 'm-b', userId: userB, category: 'A12', correct: 0, wrong: 20, unanswered: 0),
        ],
        multiAnswers: [
          ..._multiAnswersFor('m-a', correct: 18, wrong: 1, unanswered: 1, lesson: 1),
          ..._multiAnswersFor('m-b', correct: 0, wrong: 20, unanswered: 0, lesson: 1),
        ],
        examAttempts: [
          _exam(id: 'e-a', userId: userA, category: 'A12', passed: true, correct: 18, wrong: 1, unanswered: 1),
          _exam(id: 'e-b', userId: userB, category: 'A12', passed: false, correct: 5, wrong: 10, unanswered: 5),
        ],
        examAnswers: [
          ..._examAnswersFor('e-a', correct: 18, wrong: 1, unanswered: 1),
          ..._examAnswersFor('e-b', correct: 5, wrong: 10, unanswered: 5),
        ],
        questionLessonNumbers: {
          for (var i = 0; i < 20; i++) 'e-a-q$i': 1,
          for (var i = 0; i < 20; i++) 'e-b-q$i': 1,
        },
      );

      final repo = StudentQuizStatisticsRepositoryImpl(
        dataSource: fake,
        resolveUserId: () async => userA,
      );

      final stats = await repo.fetchCategoryStatistics(
        categoryId: LicenseCategoryId.motore,
      );

      // Propagazione esplicita userId al datasource (non solo RLS).
      expect(fake.lastMultiUserId, userA);
      expect(fake.lastExamUserId, userA);
      expect(fake.lastMultiLicenseCategoryDb, 'A12');
      expect(fake.lastExamLicenseCategoryDb, 'A12');

      expect(stats.study.sheetsCompleted, 1);
      expect(stats.exam.simulationsCount, 1);
      expect(stats.exam.passedCount, 1);
      expect(stats.exam.recentResults.single.attemptId, 'e-a');
      // USER_B errors non contaminano Studio/Esame.
      expect(stats.study.wrong, 1);
      expect(stats.exam.averageErrors, 2);
    });

    test('user + category isolation: USER_A A12 only', () async {
      const userA = 'USER_A';
      const userB = 'USER_B';

      final fake = StudentQuizStatisticsDataSourceFake(
        catalog: [
          for (final cat in ['A12', 'D1'])
            QuizSheetCatalogRow(
              id: '$cat-1-1',
              kind: 'lesson',
              licenseCategory: cat,
              lessonNumber: 1,
              sheetNumber: 1,
            ),
        ],
        multiAttempts: [
          _multi(id: 'm-a-a12', userId: userA, category: 'A12'),
          _multi(id: 'm-a-d1', userId: userA, category: 'D1'),
          _multi(id: 'm-b-a12', userId: userB, category: 'A12'),
        ],
        multiAnswers: [
          ..._multiAnswersFor('m-a-a12', correct: 10, wrong: 5, unanswered: 5, lesson: 1),
          ..._multiAnswersFor('m-a-d1', correct: 10, wrong: 5, unanswered: 5, lesson: 1),
          ..._multiAnswersFor('m-b-a12', correct: 10, wrong: 5, unanswered: 5, lesson: 1),
        ],
        examAttempts: [
          _exam(id: 'e-a-a12', userId: userA, category: 'A12'),
          _exam(id: 'e-a-d1', userId: userA, category: 'D1'),
          _exam(id: 'e-b-a12', userId: userB, category: 'A12'),
        ],
        examAnswers: [
          ..._examAnswersFor('e-a-a12', correct: 15, wrong: 3, unanswered: 2),
          ..._examAnswersFor('e-a-d1', correct: 15, wrong: 3, unanswered: 2),
          ..._examAnswersFor('e-b-a12', correct: 15, wrong: 3, unanswered: 2),
        ],
        questionLessonNumbers: {
          for (final prefix in ['e-a-a12', 'e-a-d1', 'e-b-a12'])
            for (var i = 0; i < 20; i++) '$prefix-q$i': 1,
        },
      );

      final repo = StudentQuizStatisticsRepositoryImpl(
        dataSource: fake,
        resolveUserId: () async => userA,
      );

      final stats = await repo.fetchCategoryStatistics(
        categoryId: LicenseCategoryId.motore,
      );

      expect(fake.lastMultiUserId, userA);
      expect(fake.lastMultiLicenseCategoryDb, 'A12');
      expect(fake.lastExamUserId, userA);
      expect(fake.lastExamLicenseCategoryDb, 'A12');

      expect(stats.study.sheetsCompleted, 1);
      expect(stats.exam.simulationsCount, 1);
      expect(stats.exam.recentResults.single.attemptId, 'e-a-a12');
    });

    test('query error propagates (not empty stats)', () async {
      final fake = StudentQuizStatisticsDataSourceFake(
        catalog: [
          const QuizSheetCatalogRow(
            id: 'a12-1-1',
            kind: 'lesson',
            licenseCategory: 'A12',
            lessonNumber: 1,
            sheetNumber: 1,
          ),
        ],
        multiFetchError: StateError('multi unavailable'),
      );

      final repo = StudentQuizStatisticsRepositoryImpl(
        dataSource: fake,
        resolveUserId: () async => 'user-1',
      );

      await expectLater(
        repo.fetchCategoryStatistics(categoryId: LicenseCategoryId.motore),
        throwsA(isA<StateError>()),
      );
    });

    test('zero-answer multi attempt excluded', () async {
      final fake = StudentQuizStatisticsDataSourceFake(
        catalog: [
          const QuizSheetCatalogRow(
            id: 'a12-1-1',
            kind: 'lesson',
            licenseCategory: 'A12',
            lessonNumber: 1,
            sheetNumber: 1,
          ),
        ],
        multiAttempts: [
          _multi(
            id: 'm0',
            userId: 'user-1',
            category: 'A12',
            correct: 0,
            wrong: 0,
            unanswered: 20,
          ),
        ],
        multiAnswers: const [], // zero answers persisted
      );

      final repo = StudentQuizStatisticsRepositoryImpl(
        dataSource: fake,
        resolveUserId: () async => 'user-1',
      );

      final stats = await repo.fetchCategoryStatistics(
        categoryId: LicenseCategoryId.motore,
      );

      expect(stats.study.sheetsCompleted, 0);
      expect(stats.ignoredIncompleteMultiAttempts, greaterThan(0));
    });

    test('unauthenticated throws', () async {
      final repo = StudentQuizStatisticsRepositoryImpl(
        dataSource: StudentQuizStatisticsDataSourceFake(),
        resolveUserId: () async => null,
      );
      await expectLater(
        repo.fetchCategoryStatistics(categoryId: LicenseCategoryId.motore),
        throwsA(isA<QuizStatisticsUnauthenticatedException>()),
      );
    });

    test('vela / unsupported category → empty', () async {
      final repo = StudentQuizStatisticsRepositoryImpl(
        dataSource: StudentQuizStatisticsDataSourceFake(),
        resolveUserId: () async => 'user-1',
      );
      final stats = await repo.fetchCategoryStatistics(
        categoryId: LicenseCategoryId.vela,
      );
      expect(stats.hasAnyActivity, isFalse);
    });
  });
}
