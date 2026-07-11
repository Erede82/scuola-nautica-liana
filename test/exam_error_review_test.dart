import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/exam_error_review.dart';
import 'package:scuola_nautica_liana/models/quiz_question.dart';

QuizQuestion _q(String id, {QuizAnswerOption correct = QuizAnswerOption.b}) {
  return QuizQuestion(
    id: id,
    prompt: 'Prompt $id',
    optionA: 'A$id',
    optionB: 'B$id',
    optionC: 'C$id',
    correctOption: correct,
    lessonNumber: 1,
    licenseCategory: 'A12',
  );
}

void main() {
  group('buildExamErrorReviewEntries', () {
    test('include wrong and unanswered only', () {
      final questions = [_q('1'), _q('2'), _q('3')];
      final answers = <QuizAnswerOption?>[
        QuizAnswerOption.b,
        QuizAnswerOption.a,
        null,
      ];

      final entries = buildExamErrorReviewEntries(
        questions: questions,
        userAnswers: answers,
      );

      expect(entries.length, 2);
      expect(entries[0].questionNumber, 2);
      expect(entries[0].userAnswer, QuizAnswerOption.a);
      expect(entries[1].questionNumber, 3);
      expect(entries[1].isUnanswered, isTrue);
    });

    test('all correct → empty', () {
      final questions = [_q('1'), _q('2', correct: QuizAnswerOption.a)];
      final answers = <QuizAnswerOption?>[
        QuizAnswerOption.b,
        QuizAnswerOption.a,
      ];

      final entries = buildExamErrorReviewEntries(
        questions: questions,
        userAnswers: answers,
      );

      expect(entries, isEmpty);
    });
  });
}
