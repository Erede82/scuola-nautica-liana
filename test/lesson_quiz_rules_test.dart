import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/lesson_quiz_rules.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';

void main() {
  group('lessonQuizRulesForCategory', () {
    test('A12: 20 domande, soglia 4, non risposte escluse', () {
      final rules = lessonQuizRulesForCategory(LicenseCategoryId.motore)!;
      expect(rules.questionsPerSheet, 20);
      expect(rules.maxErrors, 4);
      expect(rules.countUnansweredAsErrors, isFalse);
    });

    test('D1: 15 domande, soglia 3, non risposte incluse', () {
      final rules = lessonQuizRulesForCategory(LicenseCategoryId.d1)!;
      expect(rules.questionsPerSheet, 15);
      expect(rules.maxErrors, 3);
      expect(rules.countUnansweredAsErrors, isTrue);
    });

    test('vela non supportata', () {
      expect(lessonQuizRulesForCategory(LicenseCategoryId.vela), isNull);
    });
  });

  group('lessonQuizErrorCountForResult', () {
    test('A12 usa solo wrongCount', () {
      expect(
        lessonQuizErrorCountForResult(
          categoryId: LicenseCategoryId.motore,
          wrongCount: 4,
          unansweredCount: 14,
        ),
        4,
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

    test('wrong=4, unanswered=14 → 18 errori, fuori soglia', () {
      expect(
        lessonQuizErrorCountForResult(
          categoryId: LicenseCategoryId.d1,
          wrongCount: 4,
          unansweredCount: 14,
        ),
        18,
      );
      expect(
        lessonQuizWithinErrorThreshold(
          categoryId: LicenseCategoryId.d1,
          wrongCount: 4,
          unansweredCount: 14,
        ),
        isFalse,
      );
    });
  });

  group('lessonQuizWithinErrorThreshold A12', () {
    test('wrong=4 → entro soglia anche con unanswered', () {
      expect(
        lessonQuizWithinErrorThreshold(
          categoryId: LicenseCategoryId.motore,
          wrongCount: 4,
          unansweredCount: 16,
        ),
        isTrue,
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

    test('A12 promosso ignora non risposte', () {
      expect(
        lessonQuizOutcomeLabel(
          categoryId: LicenseCategoryId.motore,
          wrongCount: 4,
          unansweredCount: 14,
        ),
        'PROMOSSO',
      );
    });
  });
}
