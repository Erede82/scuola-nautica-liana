import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/data/supabase/dto/quiz_result_row.dart';
import 'package:scuola_nautica_liana/data/supabase/quiz_attempt_history_data_source.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';
import 'package:scuola_nautica_liana/repositories/quiz_statistics_repository.dart';

List<QuizResultRow> _testUserLessonResults() {
  QuizResultRow result({
    required String id,
    required int sheetNumber,
    required int correct,
    required int wrong,
    required int unanswered,
    String quizSetId = '',
    int lessonNumber = 1,
  }) {
    return QuizResultRow(
      id: id,
      quizSetId: quizSetId.isEmpty ? 'set-$sheetNumber' : quizSetId,
      totalQuestions: correct + wrong + unanswered,
      correctCount: correct,
      wrongCount: wrong,
      unansweredCount: unanswered,
      lessonNumber: lessonNumber,
      sheetNumber: sheetNumber,
      licenseCategory: 'A12',
      kind: 'lesson',
      completedAt: DateTime.utc(2026, 7, 10, sheetNumber),
    );
  }

  return [
    result(id: 'r1', sheetNumber: 1, correct: 1, wrong: 4, unanswered: 15),
    result(id: 'r2', sheetNumber: 2, correct: 1, wrong: 4, unanswered: 15),
    result(id: 'r3', sheetNumber: 3, correct: 0, wrong: 4, unanswered: 16),
    result(id: 'r4', sheetNumber: 4, correct: 1, wrong: 3, unanswered: 16),
    result(id: 'r5', sheetNumber: 5, correct: 0, wrong: 4, unanswered: 16),
    result(id: 'r6', sheetNumber: 6, correct: 0, wrong: 3, unanswered: 17),
  ];
}

void main() {
  group('QuizStatisticsRepositoryImpl', () {
    test('passa userId al data source', () async {
      final results = _testUserLessonResults();
      final dataSource = QuizAttemptHistoryDataSourceInMemory(
        results: results,
        answerCountsByResultId: {
          for (final row in results) row.id: row.totalQuestions,
        },
      );

      final repository = QuizStatisticsRepositoryImpl(
        dataSource: dataSource,
        resolveUserId: () async => 'user-test',
      );

      await repository.fetchCategoryStatistics(
        categoryId: LicenseCategoryId.motore,
      );

      expect(dataSource.lastUserIdForResults, 'user-test');
      expect(dataSource.lastUserIdForAnswerCounts, 'user-test');
      expect(
        dataSource.lastAnswerCountResultIds,
        results.map((r) => r.id).toList(),
      );
    });

    test('restituisce statistiche da data source in-memory', () async {
      final results = _testUserLessonResults();
      final dataSource = QuizAttemptHistoryDataSourceInMemory(
        results: results,
        answerCountsByResultId: {
          for (final row in results) row.id: row.totalQuestions,
        },
      );

      final repository = QuizStatisticsRepositoryImpl(
        dataSource: dataSource,
        resolveUserId: () async => 'user-test',
      );

      final stats = await repository.fetchCategoryStatistics(
        categoryId: LicenseCategoryId.motore,
      );

      expect(stats.hasData, isTrue);
      expect(stats.summary.completedSheetsCount, 6);
      expect(stats.summary.correctCount, 3);
      expect(stats.summary.wrongCount, 22);
      expect(stats.summary.unansweredCount, 95);
      expect(stats.summary.averageErrorsPerSheet, closeTo(22 / 6, 0.0001));
      expect(stats.summary.ignoredIncompleteAttempts, 0);
      expect(stats.lessonSnapshots.single.lessonNumber, 1);
      expect(stats.recentAttempts.first.sheetNumber, 6);
    });

    test('utente non autenticato → eccezione esplicita', () async {
      final repository = QuizStatisticsRepositoryImpl(
        dataSource: QuizAttemptHistoryDataSourceInMemory(
          results: _testUserLessonResults(),
        ),
        resolveUserId: () async => null,
      );

      await expectLater(
        repository.fetchCategoryStatistics(
          categoryId: LicenseCategoryId.motore,
        ),
        throwsA(isA<QuizStatisticsUnauthenticatedException>()),
      );
    });

    test('utente autenticato con storico vuoto → empty valido', () async {
      final repository = QuizStatisticsRepositoryImpl(
        dataSource: QuizAttemptHistoryDataSourceInMemory(),
        resolveUserId: () async => 'user-test',
      );

      final stats = await repository.fetchCategoryStatistics(
        categoryId: LicenseCategoryId.motore,
      );

      expect(stats.hasData, isFalse);
      expect(stats.hasIgnoredAttempts, isFalse);
      expect(stats.summary.ignoredIncompleteAttempts, 0);
    });

    test('categoria vela non supportata → empty', () async {
      final repository = QuizStatisticsRepositoryImpl(
        dataSource: QuizAttemptHistoryDataSourceInMemory(
          results: _testUserLessonResults(),
        ),
        resolveUserId: () async => 'user-test',
      );

      final stats = await repository.fetchCategoryStatistics(
        categoryId: LicenseCategoryId.vela,
      );

      expect(stats.hasData, isFalse);
    });

    test('answerCounts vuoto con risultati → tutti ignorati', () async {
      final results = _testUserLessonResults();
      final repository = QuizStatisticsRepositoryImpl(
        dataSource: QuizAttemptHistoryDataSourceInMemory(results: results),
        resolveUserId: () async => 'user-test',
      );

      final stats = await repository.fetchCategoryStatistics(
        categoryId: LicenseCategoryId.motore,
      );

      expect(stats.hasData, isFalse);
      expect(stats.hasIgnoredAttempts, isTrue);
      expect(stats.summary.ignoredIncompleteAttempts, 6);
    });

    test(
      'answerCount inferiore a totalQuestions → tentativo ignorato',
      () async {
        final results = _testUserLessonResults();
        final repository = QuizStatisticsRepositoryImpl(
          dataSource: QuizAttemptHistoryDataSourceInMemory(
            results: results,
            answerCountsByResultId: {
              results.first.id: results.first.totalQuestions - 1,
              for (final row in results.skip(1)) row.id: row.totalQuestions,
            },
          ),
          resolveUserId: () async => 'user-test',
        );

        final stats = await repository.fetchCategoryStatistics(
          categoryId: LicenseCategoryId.motore,
        );

        expect(stats.summary.completedSheetsCount, 5);
        expect(stats.summary.ignoredIncompleteAttempts, 1);
      },
    );

    test(
      'answerCount superiore a totalQuestions → tentativo ignorato',
      () async {
        final row = _testUserLessonResults().first;
        final repository = QuizStatisticsRepositoryImpl(
          dataSource: QuizAttemptHistoryDataSourceInMemory(
            results: [row],
            answerCountsByResultId: {row.id: row.totalQuestions + 1},
          ),
          resolveUserId: () async => 'user-test',
        );

        final stats = await repository.fetchCategoryStatistics(
          categoryId: LicenseCategoryId.motore,
        );

        expect(stats.hasData, isFalse);
        expect(stats.summary.ignoredIncompleteAttempts, 1);
      },
    );

    test('stesso quizSetId: passa solo result.id completo', () async {
      const sharedSetId = 'set-shared';
      final complete = QuizResultRow(
        id: 'complete',
        quizSetId: sharedSetId,
        totalQuestions: 20,
        correctCount: 2,
        wrongCount: 3,
        unansweredCount: 15,
        lessonNumber: 1,
        sheetNumber: 1,
        licenseCategory: 'A12',
        kind: 'lesson',
        completedAt: DateTime.utc(2026, 7, 10),
      );
      final incomplete = QuizResultRow(
        id: 'incomplete',
        quizSetId: sharedSetId,
        totalQuestions: 20,
        correctCount: 2,
        wrongCount: 3,
        unansweredCount: 15,
        lessonNumber: 1,
        sheetNumber: 2,
        licenseCategory: 'A12',
        kind: 'lesson',
        completedAt: DateTime.utc(2026, 7, 9),
      );

      final repository = QuizStatisticsRepositoryImpl(
        dataSource: QuizAttemptHistoryDataSourceInMemory(
          results: [complete, incomplete],
          answerCountsByResultId: {
            complete.id: complete.totalQuestions,
            incomplete.id: 10,
          },
        ),
        resolveUserId: () async => 'user-test',
      );

      final stats = await repository.fetchCategoryStatistics(
        categoryId: LicenseCategoryId.motore,
      );

      expect(stats.summary.completedSheetsCount, 1);
      expect(stats.summary.ignoredIncompleteAttempts, 1);
      expect(stats.recentAttempts.single.quizResultId, 'complete');
    });

    test('metadati incoerenti → ignorato', () async {
      final bad = QuizResultRow(
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
      );
      final good = _testUserLessonResults().first;

      final repository = QuizStatisticsRepositoryImpl(
        dataSource: QuizAttemptHistoryDataSourceInMemory(
          results: [bad, good],
          answerCountsByResultId: {bad.id: 20, good.id: good.totalQuestions},
        ),
        resolveUserId: () async => 'user-test',
      );

      final stats = await repository.fetchCategoryStatistics(
        categoryId: LicenseCategoryId.motore,
      );

      expect(stats.summary.completedSheetsCount, 1);
      expect(stats.summary.ignoredIncompleteAttempts, 1);
    });

    test('errore data source propagato', () async {
      final repository = QuizStatisticsRepositoryImpl(
        dataSource: QuizAttemptHistoryDataSourceInMemory(
          results: _testUserLessonResults(),
          throwOnFetch: true,
        ),
        resolveUserId: () async => 'user-test',
      );

      await expectLater(
        repository.fetchCategoryStatistics(
          categoryId: LicenseCategoryId.motore,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('QuizStatisticsRepositoryEmpty restituisce empty', () async {
      const repository = QuizStatisticsRepositoryEmpty();
      final stats = await repository.fetchCategoryStatistics(
        categoryId: LicenseCategoryId.motore,
      );
      expect(stats.hasData, isFalse);
    });
  });

  group('QuizAttemptHistoryDataSourceSupabase', () {
    test('query risultati e answer count applicano filtro user_id', () {
      final source = File(
        'lib/data/supabase/quiz_attempt_history_data_source.dart',
      ).readAsStringSync();

      expect(source, contains(".eq('user_id', userId)"));
      expect(QuizAttemptHistoryDataSourceSupabase.answerCountInChunkSize, 100);
    });
  });
}
