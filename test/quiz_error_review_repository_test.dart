import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/data/supabase/dto/question_row.dart';
import 'package:scuola_nautica_liana/data/supabase/dto/quiz_result_row.dart';
import 'package:scuola_nautica_liana/data/supabase/dto/quiz_wrong_answer_history_row.dart';
import 'package:scuola_nautica_liana/data/supabase/quiz_attempt_history_data_source.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';
import 'package:scuola_nautica_liana/models/quiz_error_review_data.dart';
import 'package:scuola_nautica_liana/repositories/quiz_error_review_repository.dart';

QuizResultRow _result({
  required String id,
  int sheetNumber = 1,
  String licenseCategory = 'A12',
}) {
  return QuizResultRow(
    id: id,
    quizSetId: 'set-$sheetNumber',
    totalQuestions: 20,
    correctCount: 10,
    wrongCount: 5,
    unansweredCount: 5,
    lessonNumber: 1,
    sheetNumber: sheetNumber,
    licenseCategory: licenseCategory,
    kind: 'lesson',
    completedAt: DateTime.utc(2026, 7, 10, sheetNumber),
  );
}

QuizWrongAnswerHistoryRow _wrong({
  required String id,
  required String questionId,
  String selectedOption = 'A',
  String correctOption = 'B',
  DateTime? answeredAt,
  String quizResultId = 'r1',
  String licenseCategory = 'A12',
  String prompt = 'Domanda',
}) {
  return QuizWrongAnswerHistoryRow.fromParts(
    id: id,
    quizResultId: quizResultId,
    userId: 'user-test',
    questionId: questionId,
    selectedOption: selectedOption,
    correctOption: correctOption,
    answeredAt: answeredAt ?? DateTime.utc(2026, 7, 10),
    result: _result(id: quizResultId, licenseCategory: licenseCategory),
    question: QuestionRow(
      id: questionId,
      prompt: prompt,
      optionA: 'A1',
      optionB: 'B1',
      optionC: 'C1',
      correctOption: correctOption,
      lessonNumber: 1,
      licenseCategory: licenseCategory,
    ),
  );
}

void main() {
  group('QuizErrorReviewRepositoryImpl', () {
    test('passa userId e categoria al data source', () async {
      final dataSource = QuizAttemptHistoryDataSourceInMemory(
        wrongAnswers: [_wrong(id: 'a1', questionId: 'q1')],
      );

      final repository = QuizErrorReviewRepositoryImpl(
        dataSource: dataSource,
        resolveUserId: () async => 'user-test',
      );

      await repository.fetchCurrentUserErrors(
        categoryId: LicenseCategoryId.motore,
      );

      expect(dataSource.lastUserIdForWrongAnswers, 'user-test');
      expect(dataSource.lastLicenseCategoryForWrongAnswers, 'A12');
    });

    test('restituisce errori deduplicati', () async {
      final dataSource = QuizAttemptHistoryDataSourceInMemory(
        wrongAnswers: [
          _wrong(id: 'a1', questionId: 'q1'),
          _wrong(
            id: 'a2',
            questionId: 'q1',
            quizResultId: 'r2',
            answeredAt: DateTime.utc(2026, 7, 12),
            selectedOption: 'C',
          ),
        ],
      );

      final repository = QuizErrorReviewRepositoryImpl(
        dataSource: dataSource,
        resolveUserId: () async => 'user-test',
      );

      final data = await repository.fetchCurrentUserErrors(
        categoryId: LicenseCategoryId.motore,
      );

      expect(data.hasData, isTrue);
      expect(data.entries.length, 1);
      expect(data.entries.single.errorCount, 2);
      expect(data.totalWrongOccurrences, 2);
    });

    test('storico vuoto', () async {
      final repository = QuizErrorReviewRepositoryImpl(
        dataSource: QuizAttemptHistoryDataSourceInMemory(),
        resolveUserId: () async => 'user-test',
      );

      final data = await repository.fetchCurrentUserErrors(
        categoryId: LicenseCategoryId.motore,
      );

      expect(data.isEmpty, isTrue);
    });

    test('utente non autenticato → eccezione', () async {
      final repository = QuizErrorReviewRepositoryImpl(
        dataSource: QuizAttemptHistoryDataSourceInMemory(),
        resolveUserId: () async => null,
      );

      expect(
        () => repository.fetchCurrentUserErrors(
          categoryId: LicenseCategoryId.motore,
        ),
        throwsA(isA<QuizErrorReviewUnauthenticatedException>()),
      );
    });

    test('vela senza fallback A12', () async {
      final dataSource = QuizAttemptHistoryDataSourceInMemory(
        wrongAnswers: [_wrong(id: 'a1', questionId: 'q1')],
      );
      final repository = QuizErrorReviewRepositoryImpl(
        dataSource: dataSource,
        resolveUserId: () async => 'user-test',
      );

      final data = await repository.fetchCurrentUserErrors(
        categoryId: LicenseCategoryId.vela,
      );

      expect(data.isEmpty, isTrue);
      expect(dataSource.lastUserIdForWrongAnswers, isNull);
    });

    test('categoria D1', () async {
      final dataSource = QuizAttemptHistoryDataSourceInMemory(
        wrongAnswers: [
          _wrong(id: 'a1', questionId: 'q1', licenseCategory: 'D1'),
        ],
      );
      final repository = QuizErrorReviewRepositoryImpl(
        dataSource: dataSource,
        resolveUserId: () async => 'user-test',
      );

      final data = await repository.fetchCurrentUserErrors(
        categoryId: LicenseCategoryId.d1,
      );

      expect(data.hasData, isTrue);
      expect(dataSource.lastLicenseCategoryForWrongAnswers, 'D1');
    });

    test('filtro lessonNumber e sort', () async {
      final dataSource = QuizAttemptHistoryDataSourceInMemory(
        wrongAnswers: [
          _wrong(id: 'a1', questionId: 'q1'),
          _wrong(
            id: 'a2',
            questionId: 'q2',
            quizResultId: 'r2',
            answeredAt: DateTime.utc(2026, 6, 1),
          ),
        ],
      );
      final repository = QuizErrorReviewRepositoryImpl(
        dataSource: dataSource,
        resolveUserId: () async => 'user-test',
      );

      final data = await repository.fetchCurrentUserErrors(
        categoryId: LicenseCategoryId.motore,
        lessonNumber: 1,
        sort: QuizErrorReviewSort.mostFrequent,
        limit: 1,
      );

      expect(data.entries.length, 1);
    });

    test('errore data source propagato', () async {
      final dataSource = QuizAttemptHistoryDataSourceInMemory(
        throwOnWrongAnswersFetch: true,
      );
      final repository = QuizErrorReviewRepositoryImpl(
        dataSource: dataSource,
        resolveUserId: () async => 'user-test',
      );

      expect(
        () => repository.fetchCurrentUserErrors(
          categoryId: LicenseCategoryId.motore,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('QuizAttemptHistoryDataSourceSupabase query filters', () {
    test(
      'fetch wrong answers applica filtri user_id, is_correct, selected_option',
      () {
        final source = File(
          'lib/data/supabase/quiz_attempt_history_data_source.dart',
        ).readAsStringSync();

        expect(source, contains(".eq('user_id', userId)"));
        expect(source, contains(".eq('is_correct', false)"));
        expect(source, contains(".not('selected_option', 'is', null)"));
        expect(source, contains(".eq('quiz_sets.kind', 'lesson')"));
        expect(source, contains('fetchWrongLessonAnswersForUser'));
      },
    );
  });
}
