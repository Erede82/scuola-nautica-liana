import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/lesson_quiz_rules.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';

void main() {
  group('lessonQuizRulesForCategory', () {
    test('A12: 20 domande, soglia 4, non risposte come errori', () {
      final rules = lessonQuizRulesForCategory(LicenseCategoryId.motore)!;
      expect(rules.questionsPerSheet, 20);
      expect(rules.maxErrors, 4);
      expect(rules.countUnansweredAsErrors, isTrue);
    });

    test('D1: 15 domande, soglia 3, non risposte come errori', () {
      final rules = lessonQuizRulesForCategory(LicenseCategoryId.d1)!;
      expect(rules.questionsPerSheet, 15);
      expect(rules.maxErrors, 3);
      expect(rules.countUnansweredAsErrors, isTrue);
    });

    test('vela non supportata', () {
      expect(lessonQuizRulesForCategory(LicenseCategoryId.vela), isNull);
    });
  });

  group('lessonQuizErrorCountForResult — STUDIO.QUIZ.UNANSWERED.1', () {
    test('A12: 0 wrong + 20 unanswered → 20 effective errors', () {
      expect(
        lessonQuizErrorCountForResult(
          categoryId: LicenseCategoryId.motore,
          wrongCount: 0,
          unansweredCount: 20,
        ),
        20,
      );
    });

    test('A12: 1 correct scenario → 0 wrong + 19 unanswered = 19', () {
      expect(
        lessonQuizErrorCountForResult(
          categoryId: LicenseCategoryId.motore,
          wrongCount: 0,
          unansweredCount: 19,
        ),
        19,
      );
    });

    test('A12: 1 wrong + 19 unanswered → 20', () {
      expect(
        lessonQuizErrorCountForResult(
          categoryId: LicenseCategoryId.motore,
          wrongCount: 1,
          unansweredCount: 19,
        ),
        20,
      );
    });

    test('A12: fully answered 4 wrong → 4', () {
      expect(
        lessonQuizErrorCountForResult(
          categoryId: LicenseCategoryId.motore,
          wrongCount: 4,
          unansweredCount: 0,
        ),
        4,
      );
    });

    test('D1: 0 wrong + 15 unanswered → 15', () {
      expect(
        lessonQuizErrorCountForResult(
          categoryId: LicenseCategoryId.d1,
          wrongCount: 0,
          unansweredCount: 15,
        ),
        15,
      );
    });

    test('D1 somma wrong + unanswered', () {
      expect(
        lessonQuizErrorCountForResult(
          categoryId: LicenseCategoryId.d1,
          wrongCount: 4,
          unansweredCount: 14,
        ),
        18,
      );
    });
  });

  group('lessonQuizWithinErrorThreshold D1', () {
    test('wrong=3, unanswered=0 → entro soglia', () {
      expect(
        lessonQuizWithinErrorThreshold(
          categoryId: LicenseCategoryId.d1,
          wrongCount: 3,
          unansweredCount: 0,
        ),
        isTrue,
      );
    });

    test('wrong=2, unanswered=1 → entro soglia', () {
      expect(
        lessonQuizWithinErrorThreshold(
          categoryId: LicenseCategoryId.d1,
          wrongCount: 2,
          unansweredCount: 1,
        ),
        isTrue,
      );
    });

    test('wrong=4, unanswered=0 → fuori soglia', () {
      expect(
        lessonQuizWithinErrorThreshold(
          categoryId: LicenseCategoryId.d1,
          wrongCount: 4,
          unansweredCount: 0,
        ),
        isFalse,
      );
    });

    test('wrong=0, unanswered=4 → fuori soglia', () {
      expect(
        lessonQuizWithinErrorThreshold(
          categoryId: LicenseCategoryId.d1,
          wrongCount: 0,
          unansweredCount: 4,
        ),
        isFalse,
      );
    });
  });

  group('lessonQuizWithinErrorThreshold A12', () {
    test('wrong=4, unanswered=0 → entro soglia', () {
      expect(
        lessonQuizWithinErrorThreshold(
          categoryId: LicenseCategoryId.motore,
          wrongCount: 4,
          unansweredCount: 0,
        ),
        isTrue,
      );
    });

    test('wrong=0, unanswered=19 → fuori soglia (non più promosso)', () {
      expect(
        lessonQuizWithinErrorThreshold(
          categoryId: LicenseCategoryId.motore,
          wrongCount: 0,
          unansweredCount: 19,
        ),
        isFalse,
      );
    });

    test('wrong=5 → fuori soglia', () {
      expect(
        lessonQuizWithinErrorThreshold(
          categoryId: LicenseCategoryId.motore,
          wrongCount: 5,
          unansweredCount: 0,
        ),
        isFalse,
      );
    });

    test('empty sheet 0+20 → fuori soglia (non PROMOSSO)', () {
      expect(
        lessonQuizOutcomeLabel(
          categoryId: LicenseCategoryId.motore,
          wrongCount: 0,
          unansweredCount: 20,
        ),
        'BOCCIATO',
      );
      expect(
        lessonQuizErrorCountForResult(
          categoryId: LicenseCategoryId.motore,
          wrongCount: 0,
          unansweredCount: 20,
        ),
        20,
      );
    });
  });

  group('lessonQuizOutcomeLabel / detail', () {
    test('D1 bocciato 1+11 → BOCCIATO e 12 errori', () {
      expect(
        lessonQuizOutcomeLabel(
          categoryId: LicenseCategoryId.d1,
          wrongCount: 1,
          unansweredCount: 11,
        ),
        'BOCCIATO',
      );
      expect(
        lessonQuizOutcomeDetail(
          categoryId: LicenseCategoryId.d1,
          wrongCount: 1,
          unansweredCount: 11,
        ),
        '12 errori conteggiati · massimo 3',
      );
    });

    test('singolare 1 errore conteggiato', () {
      expect(
        lessonQuizOutcomeDetail(
          categoryId: LicenseCategoryId.d1,
          wrongCount: 1,
          unansweredCount: 0,
        ),
        '1 errore conteggiato · massimo 3',
      );
    });

    test('A12: 4 wrong + 14 unanswered → BOCCIATO (18 errori)', () {
      expect(
        lessonQuizOutcomeLabel(
          categoryId: LicenseCategoryId.motore,
          wrongCount: 4,
          unansweredCount: 14,
        ),
        'BOCCIATO',
      );
      expect(
        lessonQuizOutcomeDetail(
          categoryId: LicenseCategoryId.motore,
          wrongCount: 4,
          unansweredCount: 14,
        ),
        '18 errori conteggiati · massimo 4',
      );
    });

    test('A12 fully answered 4 wrong → PROMOSSO', () {
      expect(
        lessonQuizOutcomeLabel(
          categoryId: LicenseCategoryId.motore,
          wrongCount: 4,
          unansweredCount: 0,
        ),
        'PROMOSSO',
      );
    });
  });
}
