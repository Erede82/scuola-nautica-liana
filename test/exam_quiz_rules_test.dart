import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/exam_quiz_rules.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';

void main() {
  group('buildExamQuizSummary', () {
    test('0 errori → superato', () {
      final summary = buildExamQuizSummary(
        totalQuestions: 20,
        correctCount: 20,
        wrongCount: 0,
        unansweredCount: 0,
        maxErrorsToPass: 4,
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
        maxErrorsToPass: 4,
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
        maxErrorsToPass: 4,
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
        maxErrorsToPass: 4,
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
        maxErrorsToPass: 4,
      );

      expect(summary.errorCount, 4);
      expect(summary.outcome, ExamQuizOutcome.passed);
    });

    test('D1: 3 errori → superato', () {
      final summary = buildExamQuizSummary(
        totalQuestions: 15,
        correctCount: 12,
        wrongCount: 3,
        unansweredCount: 0,
        maxErrorsToPass: 3,
      );

      expect(summary.errorCount, 3);
      expect(summary.outcome, ExamQuizOutcome.passed);
    });

    test('D1: 4 errori → non superato', () {
      final summary = buildExamQuizSummary(
        totalQuestions: 15,
        correctCount: 11,
        wrongCount: 4,
        unansweredCount: 0,
        maxErrorsToPass: 3,
      );

      expect(summary.errorCount, 4);
      expect(summary.outcome, ExamQuizOutcome.failed);
    });
  });

  group('examQuizRulesForCategory', () {
    test('A12 invariata', () {
      final rules = examQuizRulesForCategory(LicenseCategoryId.motore)!;
      expect(rules.totalQuestions, 20);
      expect(rules.maxErrorsToPass, 4);
      expect(rules.durationSeconds, 1800);
      expect(rules.topicQuotas, ExamQuizRules.a12TopicQuotas);
      expect(
        rules.topicQuotas.values.fold<int>(0, (a, b) => a + b),
        rules.totalQuestions,
      );
    });

    test('D1 ha 15 domande e 3 errori massimi', () {
      final rules = examQuizRulesForCategory(LicenseCategoryId.d1)!;
      expect(rules.totalQuestions, 15);
      expect(rules.maxErrorsToPass, 3);
      expect(rules.durationSeconds, 1800);
      expect(rules.topicQuotas, ExamQuizRules.d1TopicQuotas);
      expect(rules.topicQuotas.length, 8);
      expect(rules.topicQuotas.values.fold<int>(0, (a, b) => a + b), 15);
    });

    test('vela non supportata', () {
      expect(examQuizRulesForCategory(LicenseCategoryId.vela), isNull);
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
