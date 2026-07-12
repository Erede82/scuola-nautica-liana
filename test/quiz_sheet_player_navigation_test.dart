import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/quiz_sheet_player_navigation.dart';

void main() {
  group('QuizSheetPlayerNavigation', () {
    test('canGoForward false sull’ultima domanda', () {
      expect(
        QuizSheetPlayerNavigation.canGoForward(
          currentIndex: 19,
          questionCount: 20,
        ),
        isFalse,
      );
    });

    test('canGoForward true prima dell’ultima domanda', () {
      expect(
        QuizSheetPlayerNavigation.canGoForward(
          currentIndex: 18,
          questionCount: 20,
        ),
        isTrue,
      );
    });

    test('primaryButtonLabel mostra Chiudi scheda sull’ultima domanda', () {
      expect(
        QuizSheetPlayerNavigation.primaryButtonLabel(
          currentIndex: 19,
          questionCount: 20,
        ),
        'Chiudi scheda',
      );
    });

    test('primaryButtonLabel mostra Avanti sulle domande intermedie', () {
      expect(
        QuizSheetPlayerNavigation.primaryButtonLabel(
          currentIndex: 3,
          questionCount: 20,
        ),
        'Avanti',
      );
    });

    test('firstUnansweredIndex individua il primo gap', () {
      expect(
        QuizSheetPlayerNavigation.firstUnansweredIndex(['a', null, 'c', null]),
        1,
      );
    });

    test(
      'examPrimaryButtonLabel mostra Vedi riepilogo sull’ultima domanda',
      () {
        expect(
          QuizSheetPlayerNavigation.examPrimaryButtonLabel(
            currentIndex: 19,
            questionCount: 20,
          ),
          'Vedi riepilogo',
        );
      },
    );

    test('examPrimaryButtonLabel mostra Avanti sulle domande intermedie', () {
      expect(
        QuizSheetPlayerNavigation.examPrimaryButtonLabel(
          currentIndex: 5,
          questionCount: 20,
        ),
        'Avanti',
      );
    });

    test('isQuestionAnswered distingue risposte da gap', () {
      final answers = <String?>[null, 'b', null];
      expect(QuizSheetPlayerNavigation.isQuestionAnswered(answers, 0), isFalse);
      expect(QuizSheetPlayerNavigation.isQuestionAnswered(answers, 1), isTrue);
      expect(QuizSheetPlayerNavigation.isQuestionAnswered(answers, 2), isFalse);
    });
  });

  group('isExamQuizUiAccessible', () {
    test('preview bypassa gate bloccato', () {
      expect(
        isExamQuizUiAccessible(isStaffPreview: true, gateLocked: true),
        isTrue,
      );
    });

    test('allievo normale rispetta gate bloccato', () {
      expect(
        isExamQuizUiAccessible(isStaffPreview: false, gateLocked: true),
        isFalse,
      );
    });

    test('allievo normale con gate sbloccato', () {
      expect(
        isExamQuizUiAccessible(isStaffPreview: false, gateLocked: false),
        isTrue,
      );
    });
  });
}
