import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/models/quiz_question.dart';
import 'package:scuola_nautica_liana/repositories/quiz_attempt_repository.dart';

QuizQuestion _q(String id, {QuizAnswerOption correct = QuizAnswerOption.a}) =>
    QuizQuestion(
      id: id,
      prompt: 'Prompt $id',
      optionA: 'A',
      optionB: 'B',
      optionC: 'C',
      correctOption: correct,
      lessonNumber: 1,
      licenseCategory: 'A12',
    );

void main() {
  group('buildQuizAttemptPayload', () {
    final startedAt = DateTime.utc(2026, 7, 7, 10);
    final completedAt = DateTime.utc(2026, 7, 7, 10, 5, 30);

    test('counts correct, wrong and unanswered', () {
      final questions = [
        _q('q1'),
        _q('q2', correct: QuizAnswerOption.b),
        _q('q3'),
      ];
      final answers = <QuizAnswerOption?>[
        QuizAnswerOption.a,
        QuizAnswerOption.a,
        null,
      ];

      final payload = buildQuizAttemptPayload(
        questions: questions,
        answers: answers,
        startedAt: startedAt,
        completedAt: completedAt,
      );

      expect(payload.totalQuestions, 3);
      expect(payload.correctCount, 1);
      expect(payload.wrongCount, 1);
      expect(payload.unansweredCount, 1);
      expect(payload.wrongQuestionIds, ['q2']);
      expect(payload.durationSeconds, 330);
      expect(payload.answerRows.length, 3);

      expect(payload.answerRows[0].selectedOption, 'A');
      expect(payload.answerRows[0].isCorrect, isTrue);

      expect(payload.answerRows[1].selectedOption, 'A');
      expect(payload.answerRows[1].isCorrect, isFalse);
      expect(payload.answerRows[1].correctOption, 'B');

      expect(payload.answerRows[2].selectedOption, isNull);
      expect(payload.answerRows[2].isCorrect, isFalse);
      expect(payload.answerRows[2].correctOption, 'A');
    });

    test('wrong_question_ids excludes unanswered', () {
      final questions = [_q('q1'), _q('q2')];
      final answers = <QuizAnswerOption?>[null, QuizAnswerOption.b];

      final payload = buildQuizAttemptPayload(
        questions: questions,
        answers: answers,
        startedAt: startedAt,
        completedAt: completedAt,
      );

      expect(payload.wrongQuestionIds, ['q2']);
      expect(payload.unansweredCount, 1);
    });
  });

  group('shouldCreateQuizResultForSubmit', () {
    test('true when no partial id', () {
      expect(shouldCreateQuizResultForSubmit(null), isTrue);
      expect(shouldCreateQuizResultForSubmit(''), isTrue);
    });

    test('false when partial id exists', () {
      expect(shouldCreateQuizResultForSubmit('result-abc'), isFalse);
    });
  });

  group('runQuizAttemptSubmit', () {
    test('partial failure keeps quizResultId for retry', () async {
      var createCalls = 0;
      var insertCalls = 0;

      await expectLater(
        runQuizAttemptSubmit(
          existingQuizResultId: null,
          createQuizResult: () async {
            createCalls++;
            return 'result-1';
          },
          insertAnswers: (_) async {
            insertCalls++;
            throw Exception('network');
          },
        ),
        throwsA(
          isA<QuizAttemptAnswersPartialFailure>().having(
            (e) => e.quizResultId,
            'quizResultId',
            'result-1',
          ),
        ),
      );

      expect(createCalls, 1);
      expect(insertCalls, 1);
    });

    test(
      'retry reuses quizResultId and does not create second result',
      () async {
        var createCalls = 0;
        var insertCalls = 0;
        String? insertedForResultId;

        final result = await runQuizAttemptSubmit(
          existingQuizResultId: 'result-1',
          createQuizResult: () async {
            createCalls++;
            return 'result-new';
          },
          insertAnswers: (quizResultId) async {
            insertCalls++;
            insertedForResultId = quizResultId;
          },
        );

        expect(createCalls, 0);
        expect(insertCalls, 1);
        expect(insertedForResultId, 'result-1');
        expect(result.quizResultId, 'result-1');
      },
    );

    test('retry after partial failure can complete answers', () async {
      var createCalls = 0;
      var insertCalls = 0;
      const partialId = 'result-partial';

      await expectLater(
        runQuizAttemptSubmit(
          existingQuizResultId: null,
          createQuizResult: () async {
            createCalls++;
            return partialId;
          },
          insertAnswers: (_) async {
            insertCalls++;
            throw Exception('fail first');
          },
        ),
        throwsA(isA<QuizAttemptAnswersPartialFailure>()),
      );

      final result = await runQuizAttemptSubmit(
        existingQuizResultId: partialId,
        createQuizResult: () async {
          createCalls++;
          return 'result-new';
        },
        insertAnswers: (_) async {
          insertCalls++;
        },
      );

      expect(createCalls, 1);
      expect(insertCalls, 2);
      expect(result.quizResultId, partialId);
    });
  });
}
