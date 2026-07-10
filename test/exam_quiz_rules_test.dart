import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/exam_quiz_rules.dart';

void main() {
  group('buildExamQuizSummary', () {
    test('0 errori → superato', () {
      final summary = buildExamQuizSummary(
        totalQuestions: 20,
        correctCount: 20,
        wrongCount: 0,
        unansweredCount: 0,
      );

      expect(summary.errorCount, 0);
      expect(summary.outcome, ExamQuizOutcome.passed);
    });

    test('4 errori (solo sbagliate) → superato', () {
      final summary = buildExamQuizSummary(
        totalQuestions: 20,
        correctCount: 16,
        wrongCount: 4,
        unansweredCount: 0,
      );

      expect(summary.errorCount, 4);
      expect(summary.outcome, ExamQuizOutcome.passed);
    });

    test('5 errori → non superato', () {
      final summary = buildExamQuizSummary(
        totalQuestions: 20,
        correctCount: 15,
        wrongCount: 5,
        unansweredCount: 0,
      );

      expect(summary.errorCount, 5);
      expect(summary.outcome, ExamQuizOutcome.failed);
    });

    test('non risposte contano come errore', () {
      final summary = buildExamQuizSummary(
        totalQuestions: 20,
        correctCount: 15,
        wrongCount: 0,
        unansweredCount: 5,
      );

      expect(summary.errorCount, 5);
      expect(summary.outcome, ExamQuizOutcome.failed);
    });

    test('mix errori e non risposte → somma errori', () {
      final summary = buildExamQuizSummary(
        totalQuestions: 20,
        correctCount: 16,
        wrongCount: 2,
        unansweredCount: 2,
      );

      expect(summary.errorCount, 4);
      expect(summary.outcome, ExamQuizOutcome.passed);
    });
  });

  group('formatExamDurationMmSs', () {
    test('formats mm:ss', () {
      expect(formatExamDurationMmSs(const Duration(minutes: 30)), '30:00');
      expect(
        formatExamDurationMmSs(const Duration(minutes: 1, seconds: 5)),
        '01:05',
      );
    });
  });
}
