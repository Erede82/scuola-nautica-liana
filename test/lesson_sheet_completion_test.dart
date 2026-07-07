import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/quiz_sheet_exit_policy.dart';
import 'package:scuola_nautica_liana/models/lesson_sheet_completion_snapshot.dart';
import 'package:scuola_nautica_liana/models/quiz_question.dart';

void main() {
  group('completedSheetNumbers', () {
    test('marks sheets with saved quiz_results', () {
      final completed = completedSheetNumbers(
        quizSetIdBySheet: {1: 'set-1', 2: 'set-2', 3: 'set-3'},
        completedQuizSetIds: {'set-1', 'set-3'},
      );

      expect(completed, {1, 3});
    });

    test('empty when no quiz_results', () {
      final completed = completedSheetNumbers(
        quizSetIdBySheet: {1: 'set-1'},
        completedQuizSetIds: const {},
      );

      expect(completed, isEmpty);
    });
  });

  group('isLessonSheetPlayable', () {
    const snapshot = LessonSheetCompletionSnapshot(
      quizSetIdBySheet: {1: 'set-1'},
      completedSheetNumbers: {1},
    );

    test('completed sheet is not playable', () {
      expect(
        isLessonSheetPlayable(sheetNumber: 1, completion: snapshot),
        isFalse,
      );
    });

    test('todo sheet is playable', () {
      expect(
        isLessonSheetPlayable(sheetNumber: 2, completion: snapshot),
        isTrue,
      );
    });
  });

  group('shouldConfirmExitBeforeSummary', () {
    test('no answers → exit without confirm', () {
      expect(shouldConfirmExitBeforeSummary(const [null, null]), isFalse);
    });

    test('partial answers → confirm exit', () {
      expect(
        shouldConfirmExitBeforeSummary([QuizAnswerOption.a, null]),
        isTrue,
      );
    });
  });
}
