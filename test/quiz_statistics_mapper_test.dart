import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/data/supabase/dto/quiz_result_row.dart';
import 'package:scuola_nautica_liana/data/supabase/mappers/quiz_statistics_mapper.dart';
import 'package:scuola_nautica_liana/domain/quiz_license_category.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';

import 'helpers/statistics_catalog_fixtures.dart';

QuizResultRow _result({
  required String id,
  required int sheetNumber,
  required int correct,
  required int wrong,
  required int unanswered,
  int lessonNumber = 1,
  String quizSetId = '',
  DateTime? completedAt,
  String licenseCategory = 'A12',
}) {
  final total = correct + wrong + unanswered;
  return QuizResultRow(
    id: id,
    quizSetId: quizSetId.isEmpty ? 'set-$sheetNumber' : quizSetId,
    totalQuestions: total,
    correctCount: correct,
    wrongCount: wrong,
    unansweredCount: unanswered,
    lessonNumber: lessonNumber,
    sheetNumber: sheetNumber,
    licenseCategory: licenseCategory,
    kind: 'lesson',
    completedAt: completedAt ?? DateTime.utc(2026, 7, 10, sheetNumber),
  );
}

/// Fixture allineata ai dati DB Guard utente test (6 schede L1 A12).
List<QuizResultRow> testUserLessonResults() {
  return [
    _result(id: 'r1', sheetNumber: 1, correct: 1, wrong: 4, unanswered: 15),
    _result(id: 'r2', sheetNumber: 2, correct: 1, wrong: 4, unanswered: 15),
    _result(id: 'r3', sheetNumber: 3, correct: 0, wrong: 4, unanswered: 16),
    _result(id: 'r4', sheetNumber: 4, correct: 1, wrong: 3, unanswered: 16),
    _result(id: 'r5', sheetNumber: 5, correct: 0, wrong: 4, unanswered: 16),
    _result(id: 'r6', sheetNumber: 6, correct: 0, wrong: 3, unanswered: 17),
  ];
}

Map<String, int> fullAnswerCountsFor(Iterable<QuizResultRow> rows) {
  return {for (final row in rows) row.id: row.totalQuestions};
}

void main() {
  group('isCompleteLessonQuizResult', () {
    test('tentativo coerente lesson è completo', () {
      expect(isCompleteLessonQuizResult(testUserLessonResults().first), isTrue);
    });

    test('kind diverso da lesson → non completo', () {
      final row = _result(
        id: 'x',
        sheetNumber: 1,
        correct: 10,
        wrong: 5,
        unanswered: 5,
      );
      expect(
        isCompleteLessonQuizResult(
          QuizResultRow(
            id: row.id,
            quizSetId: row.quizSetId,
            totalQuestions: row.totalQuestions,
            correctCount: row.correctCount,
            wrongCount: row.wrongCount,
            unansweredCount: row.unansweredCount,
            lessonNumber: row.lessonNumber,
            sheetNumber: row.sheetNumber,
            licenseCategory: row.licenseCategory,
            kind: 'exam',
          ),
        ),
        isFalse,
      );
    });

    test('conteggi incoerenti → non completo', () {
      expect(
        isCompleteLessonQuizResult(
          QuizResultRow(
            id: 'bad',
            quizSetId: 'set-bad',
            totalQuestions: 20,
            correctCount: 1,
            wrongCount: 1,
            unansweredCount: 1,
            lessonNumber: 1,
            sheetNumber: 9,
            licenseCategory: 'A12',
            kind: 'lesson',
          ),
        ),
        isFalse,
      );
    });

    test('categoria DB sconosciuta → non completo', () {
      expect(
        isCompleteLessonQuizResult(
          _result(
            id: 'unk',
            sheetNumber: 1,
            correct: 1,
            wrong: 1,
            unanswered: 18,
            licenseCategory: 'ZZZ',
          ),
        ),
        isFalse,
      );
      expect(licenseCategoryIdFromDb('ZZZ'), isNull);
    });
  });

  group('isCompleteQuizStatisticsAttempt', () {
    test('richiede answerCount == totalQuestions', () {
      final row = testUserLessonResults().first;
      expect(
        isCompleteQuizStatisticsAttempt(result: row, answerCount: 20),
        isTrue,
      );
      expect(
        isCompleteQuizStatisticsAttempt(result: row, answerCount: 19),
        isFalse,
      );
      expect(
        isCompleteQuizStatisticsAttempt(result: row, answerCount: 21),
        isFalse,
      );
      expect(
        isCompleteQuizStatisticsAttempt(result: row, answerCount: null),
        isFalse,
      );
    });
  });

  group('partitionStatisticsAttempts', () {
    test('answerCounts vuoto → tutti ignorati', () {
      final rows = testUserLessonResults();
      final partition = partitionStatisticsAttempts(
        rows: rows,
        answerCounts: const {},
      );

      expect(partition.validResults, isEmpty);
      expect(partition.ignoredIncompleteAttempts, 6);
    });

    test('stesso quizSetId: passa solo result.id completo', () {
      final sharedSetId = 'set-shared';
      final complete = _result(
        id: 'complete',
        sheetNumber: 1,
        correct: 2,
        wrong: 3,
        unanswered: 15,
        quizSetId: sharedSetId,
      );
      final incomplete = _result(
        id: 'incomplete',
        sheetNumber: 2,
        correct: 1,
        wrong: 1,
        unanswered: 10,
        quizSetId: sharedSetId,
      );

      final partition = partitionStatisticsAttempts(
        rows: [complete, incomplete],
        answerCounts: {complete.id: complete.totalQuestions, incomplete.id: 5},
      );

      expect(partition.validResults.map((r) => r.id), ['complete']);
      expect(partition.ignoredIncompleteAttempts, 1);
    });
  });

  group('buildQuizStatisticsSummary', () {
    test('aggrega dati reali utente test', () {
      final results = testUserLessonResults();
      final summary = buildQuizStatisticsSummary(
        completeResults: results,
        ignoredIncompleteAttempts: 0,
        categoryId: LicenseCategoryId.motore,
      );

      expect(summary.completedSheetsCount, 6);
      expect(summary.totalQuestions, 120);
      expect(summary.correctCount, 3);
      expect(summary.wrongCount, 22);
      expect(summary.unansweredCount, 95);
      expect(summary.accuracyPercentage, closeTo(2.5, 0.01));
      expect(summary.errorPercentage, closeTo(97.5, 0.01));
      expect(summary.averageErrorsPerSheet, closeTo(22 / 6, 0.0001));
      expect(summary.ignoredIncompleteAttempts, 0);
      expect(summary.lastLessonNumber, 1);
      expect(summary.lastSheetNumber, 6);
      expect(summary.weakestLessonNumber, 1);
      expect(summary.strongestLessonNumber, 1);
    });

    test('lista vuota con ignored → summary zerata con ignored', () {
      final summary = buildQuizStatisticsSummary(
        completeResults: const [],
        ignoredIncompleteAttempts: 4,
        categoryId: LicenseCategoryId.motore,
      );

      expect(summary.completedSheetsCount, 0);
      expect(summary.ignoredIncompleteAttempts, 4);
      expect(summary.averageErrorsPerSheet, 0);
      expect(summary.accuracyPercentage, 0);
      expect(summary.errorPercentage, 0);
    });

    test('divisione per zero senza NaN', () {
      expect(
        averageWrongAnswersPerSheet(wrongCount: 10, completedSheetsCount: 0),
        0,
      );
    });
  });

  group('buildLessonPerformanceSnapshots', () {
    test('aggrega per lezione con titolo catalogo', () {
      final snapshots = buildLessonPerformanceSnapshots(
        completeResults: testUserLessonResults(),
        categoryId: LicenseCategoryId.motore,
      );

      expect(snapshots.length, 1);
      expect(snapshots.first.lessonNumber, 1);
      expect(snapshots.first.totalAttempts, 6);
      expect(snapshots.first.averageErrorPercentage, closeTo(97.5, 0.01));
      expect(snapshots.first.lessonTitle, contains('Teoria dello scafo'));
    });

    test('storico su più lezioni aggregato correttamente', () {
      final results = [
        ...testUserLessonResults(),
        _result(
          id: 'l2',
          sheetNumber: 1,
          lessonNumber: 2,
          correct: 10,
          wrong: 5,
          unanswered: 5,
        ),
      ];

      final snapshots = buildLessonPerformanceSnapshots(
        completeResults: results,
        categoryId: LicenseCategoryId.motore,
      );

      expect(snapshots.length, 2);
      expect(snapshots[0].lessonNumber, 1);
      expect(snapshots[1].lessonNumber, 2);
      expect(snapshots[1].totalAttempts, 1);
    });
  });

  group('compareQuizResultsByActivity', () {
    test('ordine deterministico a parità di timestamp', () {
      final sameTime = DateTime.utc(2026, 7, 10, 12);
      final rows = [
        _result(
          id: 'a',
          sheetNumber: 1,
          correct: 1,
          wrong: 1,
          unanswered: 18,
          completedAt: sameTime,
        ),
        _result(
          id: 'b',
          sheetNumber: 3,
          correct: 1,
          wrong: 1,
          unanswered: 18,
          completedAt: sameTime,
        ),
        _result(
          id: 'c',
          sheetNumber: 2,
          correct: 1,
          wrong: 1,
          unanswered: 18,
          completedAt: sameTime,
        ),
      ];

      final sorted = sortQuizResultsByActivity(rows);
      expect(sorted.map((r) => r.sheetNumber).toList(), [3, 2, 1]);
    });
  });

  group('buildRecentAttemptActivities', () {
    test('ordina per data decrescente e rispetta il limite', () {
      final results = testUserLessonResults();
      final recent = buildRecentAttemptActivities(
        completeResults: results,
        limit: 3,
      );

      expect(recent.length, 3);
      expect(recent.first.sheetNumber, 6);
      expect(recent.last.sheetNumber, 4);
    });
  });

  group('buildQuizCategoryStatistics', () {
    test('costruisce bundle completo', () {
      final stats = buildQuizCategoryStatistics(
        categoryId: LicenseCategoryId.motore,
        results: testUserLessonResults(),
        catalog: testLessonSheetCatalog(licenseCategory: 'A12'),
        ignoredIncompleteAttempts: 0,
      );

      expect(stats.hasData, isTrue);
      expect(stats.hasIgnoredAttempts, isFalse);
      expect(stats.categoryId, LicenseCategoryId.motore);
      expect(stats.lessonSnapshots.length, 1);
      expect(stats.recentAttempts.length, 6);
      expect(stats.summary.completedSheetsCount, 6);
    });

    test('tutti incoerenti → ignoredOnly', () {
      final stats = buildQuizCategoryStatistics(
        categoryId: LicenseCategoryId.motore,
        results: const [],
        catalog: testLessonSheetCatalog(licenseCategory: 'A12'),
        ignoredIncompleteAttempts: 3,
      );

      expect(stats.hasData, isFalse);
      expect(stats.hasIgnoredAttempts, isTrue);
      expect(stats.summary.ignoredIncompleteAttempts, 3);
    });
  });

  group('QuizResultRow.fromJson', () {
    test('parsa join quiz_sets annidato', () {
      final row = QuizResultRow.fromJson({
        'id': 'abc',
        'quiz_set_id': 'set-1',
        'total_questions': 20,
        'correct_count': 5,
        'wrong_count': 10,
        'unanswered_count': 5,
        'wrong_question_ids': ['q1', 'q2'],
        'completed_at': '2026-07-10T12:00:00Z',
        'quiz_sets': {
          'kind': 'lesson',
          'license_category': 'A12',
          'lesson_number': 1,
          'sheet_number': 3,
        },
      });

      expect(row.id, 'abc');
      expect(row.lessonNumber, 1);
      expect(row.sheetNumber, 3);
      expect(row.licenseCategory, 'A12');
      expect(row.wrongQuestionIds, ['q1', 'q2']);
      expect(isCompleteLessonQuizResult(row), isTrue);
    });
  });
}
