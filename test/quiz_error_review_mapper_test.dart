import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/data/supabase/dto/question_row.dart';
import 'package:scuola_nautica_liana/data/supabase/dto/quiz_result_row.dart';
import 'package:scuola_nautica_liana/data/supabase/dto/quiz_wrong_answer_history_row.dart';
import 'package:scuola_nautica_liana/data/supabase/mappers/quiz_error_review_mapper.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';
import 'package:scuola_nautica_liana/models/quiz_error_review_data.dart';

QuizResultRow _result({
  required String id,
  int lessonNumber = 1,
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
    lessonNumber: lessonNumber,
    sheetNumber: sheetNumber,
    licenseCategory: licenseCategory,
    kind: 'lesson',
    completedAt: DateTime.utc(2026, 7, 10, sheetNumber),
    createdAt: DateTime.utc(2026, 7, 9, sheetNumber),
  );
}

QuestionRow _question({
  String id = 'q1',
  String prompt = 'Domanda test',
  String correctOption = 'B',
  int lessonNumber = 1,
  String licenseCategory = 'A12',
  String? explanation,
  String? imagePath,
}) {
  return QuestionRow(
    id: id,
    prompt: prompt,
    optionA: 'A test',
    optionB: 'B test',
    optionC: 'C test',
    correctOption: correctOption,
    lessonNumber: lessonNumber,
    licenseCategory: licenseCategory,
    explanation: explanation,
    imagePath: imagePath,
  );
}

QuizWrongAnswerHistoryRow _wrongRow({
  required String id,
  required String questionId,
  required String selectedOption,
  String correctOption = 'B',
  required DateTime answeredAt,
  String quizResultId = 'r1',
  int lessonNumber = 1,
  int sheetNumber = 1,
  String licenseCategory = 'A12',
  String prompt = 'Domanda test',
  String? questionLicenseCategory,
}) {
  final result = _result(
    id: quizResultId,
    lessonNumber: lessonNumber,
    sheetNumber: sheetNumber,
    licenseCategory: licenseCategory,
  );
  return QuizWrongAnswerHistoryRow.fromParts(
    id: id,
    quizResultId: quizResultId,
    userId: 'user-1',
    questionId: questionId,
    selectedOption: selectedOption,
    correctOption: correctOption,
    answeredAt: answeredAt,
    result: result,
    question: _question(
      id: questionId,
      prompt: prompt,
      correctOption: correctOption,
      lessonNumber: lessonNumber,
      licenseCategory: questionLicenseCategory ?? licenseCategory,
    ),
  );
}

void main() {
  group('QuizWrongAnswerHistoryRow.fromAnswerJson', () {
    test('parsa join annidato questions', () {
      final result = _result(id: 'r1');
      final row = QuizWrongAnswerHistoryRow.fromAnswerJson({
        'id': 'a1',
        'quiz_result_id': 'r1',
        'user_id': 'user-1',
        'question_id': 'q1',
        'selected_option': 'A',
        'correct_option': 'B',
        'is_correct': false,
        'answered_at': '2026-07-10T10:00:00Z',
        'questions': {
          'id': 'q1',
          'prompt': 'Test prompt',
          'option_a': 'A1',
          'option_b': 'B1',
          'option_c': 'C1',
          'correct_option': 'B',
          'explanation': null,
          'image_path': null,
          'lesson_number': 1,
          'license_category': 'A12',
        },
      }, result: result);

      expect(row.prompt, 'Test prompt');
      expect(row.explanation, isNull);
      expect(row.imagePath, isNull);
      expect(row.lessonNumber, 1);
    });

    test('parsa questions come lista annidata', () {
      final result = _result(id: 'r1');
      final row = QuizWrongAnswerHistoryRow.fromAnswerJson({
        'id': 'a1',
        'quiz_result_id': 'r1',
        'question_id': 'q1',
        'selected_option': 'A',
        'correct_option': 'B',
        'is_correct': false,
        'questions': [
          {
            'prompt': 'Lista prompt',
            'option_a': 'A',
            'option_b': 'B',
            'option_c': 'C',
            'correct_option': 'B',
            'lesson_number': 2,
            'license_category': 'A12',
          },
        ],
      }, result: result);

      expect(row.prompt, 'Lista prompt');
      expect(row.questionLessonNumber, 2);
    });
  });

  group('isValidWrongAnswerHistoryRow', () {
    test('risposta errata valida', () {
      final row = _wrongRow(
        id: 'a1',
        questionId: 'q1',
        selectedOption: 'A',
        answeredAt: DateTime.utc(2026, 7, 10),
      );
      expect(
        isValidWrongAnswerHistoryRow(
          row,
          expectedCategoryId: LicenseCategoryId.motore,
        ),
        isTrue,
      );
    });

    test('non risposta esclusa', () {
      final row = _wrongRow(
        id: 'a1',
        questionId: 'q1',
        selectedOption: 'A',
        answeredAt: DateTime.utc(2026, 7, 10),
      );
      final unanswered = QuizWrongAnswerHistoryRow(
        id: row.id,
        quizResultId: row.quizResultId,
        userId: row.userId,
        questionId: row.questionId,
        selectedOption: null,
        correctOption: row.correctOption,
        isCorrect: false,
        answeredAt: row.answeredAt,
        quizSetId: row.quizSetId,
        completedAt: row.completedAt,
        resultCreatedAt: row.resultCreatedAt,
        kind: row.kind,
        licenseCategory: row.licenseCategory,
        lessonNumber: row.lessonNumber,
        sheetNumber: row.sheetNumber,
        prompt: row.prompt,
        optionA: row.optionA,
        optionB: row.optionB,
        optionC: row.optionC,
        questionCorrectOption: row.questionCorrectOption,
        questionLessonNumber: row.questionLessonNumber,
        questionLicenseCategory: row.questionLicenseCategory,
      );
      expect(
        isValidWrongAnswerHistoryRow(
          unanswered,
          expectedCategoryId: LicenseCategoryId.motore,
        ),
        isFalse,
      );
    });

    test('risposta corretta esclusa', () {
      final row = _wrongRow(
        id: 'a1',
        questionId: 'q1',
        selectedOption: 'A',
        answeredAt: DateTime.utc(2026, 7, 10),
      );
      final correct = QuizWrongAnswerHistoryRow(
        id: row.id,
        quizResultId: row.quizResultId,
        userId: row.userId,
        questionId: row.questionId,
        selectedOption: 'B',
        correctOption: 'B',
        isCorrect: true,
        answeredAt: row.answeredAt,
        quizSetId: row.quizSetId,
        completedAt: row.completedAt,
        resultCreatedAt: row.resultCreatedAt,
        kind: row.kind,
        licenseCategory: row.licenseCategory,
        lessonNumber: row.lessonNumber,
        sheetNumber: row.sheetNumber,
        prompt: row.prompt,
        optionA: row.optionA,
        optionB: row.optionB,
        optionC: row.optionC,
        questionCorrectOption: row.questionCorrectOption,
        questionLessonNumber: row.questionLessonNumber,
        questionLicenseCategory: row.questionLicenseCategory,
      );
      expect(
        isValidWrongAnswerHistoryRow(
          correct,
          expectedCategoryId: LicenseCategoryId.motore,
        ),
        isFalse,
      );
    });

    test(
      'selectedOption uguale a correctOption ma isCorrect false → malformata',
      () {
        final row = _wrongRow(
          id: 'a1',
          questionId: 'q1',
          selectedOption: 'B',
          correctOption: 'B',
          answeredAt: DateTime.utc(2026, 7, 10),
        );
        expect(
          isValidWrongAnswerHistoryRow(
            row,
            expectedCategoryId: LicenseCategoryId.motore,
          ),
          isFalse,
        );
      },
    );

    test('categoria DB sconosciuta ignorata', () {
      final row = _wrongRow(
        id: 'a1',
        questionId: 'q1',
        selectedOption: 'A',
        answeredAt: DateTime.utc(2026, 7, 10),
        licenseCategory: 'ZZZ',
      );
      expect(
        isValidWrongAnswerHistoryRow(
          row,
          expectedCategoryId: LicenseCategoryId.motore,
        ),
        isFalse,
      );
    });

    test('lessonNumber fuori range ignorato', () {
      final row = _wrongRow(
        id: 'a1',
        questionId: 'q1',
        selectedOption: 'A',
        answeredAt: DateTime.utc(2026, 7, 10),
        lessonNumber: 99,
      );
      expect(
        isValidWrongAnswerHistoryRow(
          row,
          expectedCategoryId: LicenseCategoryId.motore,
        ),
        isFalse,
      );
    });

    test('opzione selected sconosciuta ignorata', () {
      final row = _wrongRow(
        id: 'a1',
        questionId: 'q1',
        selectedOption: 'Z',
        answeredAt: DateTime.utc(2026, 7, 10),
      );
      expect(
        isValidWrongAnswerHistoryRow(
          row,
          expectedCategoryId: LicenseCategoryId.motore,
        ),
        isFalse,
      );
    });

    test('prompt vuoto ignorato', () {
      final row = _wrongRow(
        id: 'a1',
        questionId: 'q1',
        selectedOption: 'A',
        answeredAt: DateTime.utc(2026, 7, 10),
        prompt: '   ',
      );
      expect(
        isValidWrongAnswerHistoryRow(
          row,
          expectedCategoryId: LicenseCategoryId.motore,
        ),
        isFalse,
      );
    });
  });

  group('buildQuizErrorReviewData', () {
    test('storico vuoto', () {
      final data = buildQuizErrorReviewData(
        categoryId: LicenseCategoryId.motore,
        rows: const [],
      );
      expect(data.isEmpty, isTrue);
      expect(data.totalUniqueQuestions, 0);
      expect(data.totalWrongOccurrences, 0);
    });

    test('una risposta errata valida', () {
      final data = buildQuizErrorReviewData(
        categoryId: LicenseCategoryId.motore,
        rows: [
          _wrongRow(
            id: 'a1',
            questionId: 'q1',
            selectedOption: 'A',
            answeredAt: DateTime.utc(2026, 7, 10, 12),
          ),
        ],
      );

      expect(data.hasData, isTrue);
      expect(data.entries.single.questionId, 'q1');
      expect(data.entries.single.errorCount, 1);
      expect(data.totalUniqueQuestions, 1);
      expect(data.totalWrongOccurrences, 1);
    });

    test('stessa questionId errata più volte → una entry', () {
      final data = buildQuizErrorReviewData(
        categoryId: LicenseCategoryId.motore,
        rows: [
          _wrongRow(
            id: 'a1',
            questionId: 'q1',
            selectedOption: 'A',
            answeredAt: DateTime.utc(2026, 7, 8),
            quizResultId: 'r1',
            sheetNumber: 1,
          ),
          _wrongRow(
            id: 'a2',
            questionId: 'q1',
            selectedOption: 'C',
            answeredAt: DateTime.utc(2026, 7, 12),
            quizResultId: 'r2',
            sheetNumber: 2,
          ),
        ],
      );

      expect(data.entries.length, 1);
      expect(data.entries.single.errorCount, 2);
      expect(data.entries.single.latestSelectedOption.name, 'c');
      expect(data.entries.single.sheetNumbers, [1, 2]);
    });

    test('firstWrongAt e lastWrongAt', () {
      final first = DateTime.utc(2026, 7, 1);
      final last = DateTime.utc(2026, 7, 15);
      final data = buildQuizErrorReviewData(
        categoryId: LicenseCategoryId.motore,
        rows: [
          _wrongRow(
            id: 'a1',
            questionId: 'q1',
            selectedOption: 'A',
            answeredAt: first,
          ),
          _wrongRow(
            id: 'a2',
            questionId: 'q1',
            selectedOption: 'C',
            answeredAt: last,
            quizResultId: 'r2',
          ),
        ],
      );

      expect(data.entries.single.firstWrongAt, first);
      expect(data.entries.single.lastWrongAt, last);
      expect(data.lastWrongAt, last);
    });

    test('ordinamento per recenza', () {
      final data = buildQuizErrorReviewData(
        categoryId: LicenseCategoryId.motore,
        rows: [
          _wrongRow(
            id: 'a1',
            questionId: 'q-old',
            selectedOption: 'A',
            answeredAt: DateTime.utc(2026, 7, 1),
          ),
          _wrongRow(
            id: 'a2',
            questionId: 'q-new',
            selectedOption: 'A',
            answeredAt: DateTime.utc(2026, 7, 20),
          ),
        ],
        sort: QuizErrorReviewSort.recent,
      );

      expect(data.entries.first.questionId, 'q-new');
      expect(data.entries.last.questionId, 'q-old');
    });

    test('ordinamento per frequenza', () {
      final data = buildQuizErrorReviewData(
        categoryId: LicenseCategoryId.motore,
        rows: [
          _wrongRow(
            id: 'a1',
            questionId: 'q-freq',
            selectedOption: 'A',
            answeredAt: DateTime.utc(2026, 7, 1),
          ),
          _wrongRow(
            id: 'a2',
            questionId: 'q-freq',
            selectedOption: 'C',
            answeredAt: DateTime.utc(2026, 7, 2),
            quizResultId: 'r2',
          ),
          _wrongRow(
            id: 'a3',
            questionId: 'q-rare',
            selectedOption: 'A',
            answeredAt: DateTime.utc(2026, 7, 20),
            quizResultId: 'r3',
          ),
        ],
        sort: QuizErrorReviewSort.mostFrequent,
      );

      expect(data.entries.first.questionId, 'q-freq');
      expect(data.entries.first.errorCount, 2);
    });

    test('tie-break deterministico a parità di timestamp', () {
      final sameTime = DateTime.utc(2026, 7, 10);
      final data = buildQuizErrorReviewData(
        categoryId: LicenseCategoryId.motore,
        rows: [
          _wrongRow(
            id: 'a1',
            questionId: 'q-b',
            selectedOption: 'A',
            answeredAt: sameTime,
            lessonNumber: 2,
          ),
          _wrongRow(
            id: 'a2',
            questionId: 'q-a',
            selectedOption: 'A',
            answeredAt: sameTime,
            lessonNumber: 1,
            quizResultId: 'r2',
          ),
        ],
        sort: QuizErrorReviewSort.recent,
      );

      expect(data.entries.first.questionId, 'q-a');
      expect(data.entries.last.questionId, 'q-b');
    });

    test('filtro lessonNumber', () {
      final data = buildQuizErrorReviewData(
        categoryId: LicenseCategoryId.motore,
        rows: [
          _wrongRow(
            id: 'a1',
            questionId: 'q1',
            selectedOption: 'A',
            answeredAt: DateTime.utc(2026, 7, 10),
            lessonNumber: 1,
          ),
          _wrongRow(
            id: 'a2',
            questionId: 'q2',
            selectedOption: 'A',
            answeredAt: DateTime.utc(2026, 7, 10),
            lessonNumber: 2,
            quizResultId: 'r2',
          ),
        ],
        lessonNumber: 2,
      );

      expect(data.entries.length, 1);
      expect(data.entries.single.lessonNumber, 2);
    });

    test('limite dopo deduplica', () {
      final data = buildQuizErrorReviewData(
        categoryId: LicenseCategoryId.motore,
        rows: [
          _wrongRow(
            id: 'a1',
            questionId: 'q1',
            selectedOption: 'A',
            answeredAt: DateTime.utc(2026, 7, 10),
          ),
          _wrongRow(
            id: 'a2',
            questionId: 'q2',
            selectedOption: 'A',
            answeredAt: DateTime.utc(2026, 7, 9),
            quizResultId: 'r2',
          ),
        ],
        limit: 1,
      );

      expect(data.entries.length, 1);
    });

    test('correctOption incoerente nello stesso gruppo → ignorato', () {
      final data = buildQuizErrorReviewData(
        categoryId: LicenseCategoryId.motore,
        rows: [
          _wrongRow(
            id: 'a1',
            questionId: 'q1',
            selectedOption: 'A',
            correctOption: 'B',
            answeredAt: DateTime.utc(2026, 7, 10),
          ),
          _wrongRow(
            id: 'a2',
            questionId: 'q1',
            selectedOption: 'A',
            correctOption: 'C',
            answeredAt: DateTime.utc(2026, 7, 11),
            quizResultId: 'r2',
          ),
        ],
      );

      expect(data.isEmpty, isTrue);
      expect(data.ignoredMalformedRows, 2);
    });

    test('ignoredMalformedRows corretto con righe miste', () {
      final data = buildQuizErrorReviewData(
        categoryId: LicenseCategoryId.motore,
        rows: [
          _wrongRow(
            id: 'a1',
            questionId: 'q1',
            selectedOption: 'A',
            answeredAt: DateTime.utc(2026, 7, 10),
          ),
          _wrongRow(
            id: 'a2',
            questionId: 'q2',
            selectedOption: 'Z',
            answeredAt: DateTime.utc(2026, 7, 10),
            quizResultId: 'r2',
          ),
        ],
      );

      expect(data.entries.length, 1);
      expect(data.ignoredMalformedRows, 1);
    });

    test('conteggio per lezione', () {
      final data = buildQuizErrorReviewData(
        categoryId: LicenseCategoryId.motore,
        rows: [
          _wrongRow(
            id: 'a1',
            questionId: 'q1',
            selectedOption: 'A',
            answeredAt: DateTime.utc(2026, 7, 10),
            lessonNumber: 1,
          ),
          _wrongRow(
            id: 'a2',
            questionId: 'q2',
            selectedOption: 'A',
            answeredAt: DateTime.utc(2026, 7, 10),
            lessonNumber: 2,
            quizResultId: 'r2',
          ),
          _wrongRow(
            id: 'a3',
            questionId: 'q3',
            selectedOption: 'A',
            answeredAt: DateTime.utc(2026, 7, 10),
            lessonNumber: 2,
            quizResultId: 'r3',
          ),
        ],
      );

      expect(data.lessonCounts[1], 1);
      expect(data.lessonCounts[2], 2);
    });

    test('categoria D1', () {
      final data = buildQuizErrorReviewData(
        categoryId: LicenseCategoryId.d1,
        rows: [
          _wrongRow(
            id: 'a1',
            questionId: 'q1',
            selectedOption: 'A',
            answeredAt: DateTime.utc(2026, 7, 10),
            licenseCategory: 'D1',
            questionLicenseCategory: 'D1',
          ),
        ],
      );

      expect(data.hasData, isTrue);
      expect(data.entries.single.licenseCategoryId, LicenseCategoryId.d1);
    });

    test('resolveWrongAnswerTimestamp fallback completedAt', () {
      final result = _result(id: 'r1');
      final row = QuizWrongAnswerHistoryRow(
        id: 'a1',
        quizResultId: 'r1',
        userId: 'u1',
        questionId: 'q1',
        selectedOption: 'A',
        correctOption: 'B',
        isCorrect: false,
        answeredAt: null,
        quizSetId: result.quizSetId,
        completedAt: DateTime.utc(2026, 8, 1),
        resultCreatedAt: DateTime.utc(2026, 7, 1),
        kind: 'lesson',
        licenseCategory: 'A12',
        lessonNumber: 1,
        sheetNumber: 1,
        prompt: 'P',
        optionA: 'A',
        optionB: 'B',
        optionC: 'C',
        questionCorrectOption: 'B',
        questionLessonNumber: 1,
        questionLicenseCategory: 'A12',
      );

      expect(resolveWrongAnswerTimestamp(row), DateTime.utc(2026, 8, 1));
    });
  });
}
