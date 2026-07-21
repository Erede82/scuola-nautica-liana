import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/exam_quiz_attempt_result.dart';
import 'package:scuola_nautica_liana/domain/exam_quiz_rules.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';
import 'package:scuola_nautica_liana/models/quiz_question.dart';

QuizQuestion _question(
  int index, {
  QuizAnswerOption correct = QuizAnswerOption.a,
  String? imagePath,
}) {
  return QuizQuestion(
    id: 'q-$index',
    prompt: 'Domanda $index?',
    optionA: 'A$index',
    optionB: 'B$index',
    optionC: 'C$index',
    correctOption: correct,
    imagePath: imagePath,
    lessonNumber: 1,
    licenseCategory: 'A12',
  );
}

void main() {
  group('buildExamQuizAttemptAnswerSnapshots', () {
    test('preserva l\'ordine e distingue errata da non risposta', () {
      final questions = [
        _question(0, correct: QuizAnswerOption.a),
        _question(1, correct: QuizAnswerOption.b),
        _question(2, correct: QuizAnswerOption.c),
      ];
      final answers = <QuizAnswerOption?>[
        QuizAnswerOption.a, // corretta
        QuizAnswerOption.c, // errata
        null, // non risposta
      ];

      final snapshots = buildExamQuizAttemptAnswerSnapshots(
        questions: questions,
        userAnswers: answers,
      );

      expect(snapshots.length, 3);
      expect(snapshots[0].position, 1);
      expect(snapshots[1].position, 2);
      expect(snapshots[2].position, 3);

      expect(snapshots[0].isCorrect, isTrue);
      expect(snapshots[0].isUnanswered, isFalse);

      // Errata: risposta presente ma diversa dalla corretta.
      expect(snapshots[1].isCorrect, isFalse);
      expect(snapshots[1].isUnanswered, isFalse);
      expect(snapshots[1].selectedOption, QuizAnswerOption.c);

      // Non risposta: selezione nulla.
      expect(snapshots[2].isCorrect, isFalse);
      expect(snapshots[2].isUnanswered, isTrue);
      expect(snapshots[2].selectedOption, isNull);
    });

    test('contiene i dati sufficienti a ricostruire la review', () {
      final questions = [
        _question(0, correct: QuizAnswerOption.b, imagePath: 'img/0.png'),
      ];
      final snapshots = buildExamQuizAttemptAnswerSnapshots(
        questions: questions,
        userAnswers: const [QuizAnswerOption.a],
      );

      final snap = snapshots.single;
      expect(snap.questionId, 'q-0');
      expect(snap.prompt, 'Domanda 0?');
      expect(snap.optionA, 'A0');
      expect(snap.optionB, 'B0');
      expect(snap.optionC, 'C0');
      expect(snap.imagePath, 'img/0.png');
      expect(snap.selectedOption, QuizAnswerOption.a);
      expect(snap.correctOption, QuizAnswerOption.b);
      expect(snap.textForOption(QuizAnswerOption.c), 'C0');
    });

    test('lo snapshot conserva la risposta corretta storica, '
        'indipendente da una query a questions', () {
      final questions = [_question(0, correct: QuizAnswerOption.c)];
      final snapshots = buildExamQuizAttemptAnswerSnapshots(
        questions: questions,
        userAnswers: const [null],
      );

      // La corretta è cristallizzata nello snapshot, non riletta altrove.
      expect(snapshots.single.correctOption, QuizAnswerOption.c);
    });
  });

  group('ExamQuizAttemptResult', () {
    ExamQuizAttemptResult buildResult() {
      final questions = [
        _question(0, correct: QuizAnswerOption.a),
        _question(1, correct: QuizAnswerOption.b),
      ];
      final answers = <QuizAnswerOption?>[QuizAnswerOption.a, null];
      final summary = examQuizSummaryFromAnswers(
        questions: questions,
        userAnswers: answers,
      );
      return ExamQuizAttemptResult(
        id: 'attempt-1',
        licenseCategory: LicenseCategoryId.motore,
        completedAt: DateTime.utc(2026, 7, 21, 10, 30),
        duration: const Duration(minutes: 9),
        timeExpired: false,
        totalQuestions: summary.totalQuestions,
        correctCount: summary.correctCount,
        wrongCount: summary.wrongCount,
        unansweredCount: summary.unansweredCount,
        outcome: summary.outcome,
        answers: buildExamQuizAttemptAnswerSnapshots(
          questions: questions,
          userAnswers: answers,
        ),
      );
    }

    test('espone esito e conteggi coerenti', () {
      final result = buildResult();
      expect(result.totalQuestions, 2);
      expect(result.correctCount, 1);
      expect(result.wrongCount, 0);
      expect(result.unansweredCount, 1);
      expect(result.errorCount, 1);
      expect(result.passed, result.outcome == ExamQuizOutcome.passed);
      expect(result.answers.length, 2);
      expect(result.answers.first.position, 1);
    });

    test('value equality su risultato e snapshot', () {
      expect(buildResult(), equals(buildResult()));
      expect(buildResult().hashCode, buildResult().hashCode);
    });
  });
}
