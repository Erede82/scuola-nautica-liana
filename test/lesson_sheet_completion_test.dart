import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/quiz_sheet_exit_policy.dart';
import 'package:scuola_nautica_liana/models/lesson_sheet_completion_snapshot.dart';
import 'package:scuola_nautica_liana/models/quiz_question.dart';

void main() {
  group('isLessonQuizResultComplete', () {
    test('no answers → not complete', () {
      expect(
        isLessonQuizResultComplete(answerCount: 0, totalQuestions: 20),
        isFalse,
      );
    });

    test('partial answers → not complete', () {
      expect(
        isLessonQuizResultComplete(answerCount: 5, totalQuestions: 20),
        isFalse,
      );
    });

    test('answers equal total_questions → complete', () {
      expect(
        isLessonQuizResultComplete(answerCount: 20, totalQuestions: 20),
        isTrue,
      );
    });

    test('total_questions zero → not complete', () {
      expect(
        isLessonQuizResultComplete(answerCount: 0, totalQuestions: 0),
        isFalse,
      );
    });
  });

  group('completedQuizSetIdsFromAttempts', () {
    const setA = 'set-a';

    test('no quiz_results → empty', () {
      expect(
        completedQuizSetIdsFromAttempts(
          results: const [],
          answerCountByResultId: const {},
        ),
        isEmpty,
      );
    });

    test('quiz_results without answers → not completed', () {
      final completed = completedQuizSetIdsFromAttempts(
        results: const [
          LessonQuizResultAttempt(
            id: 'r1',
            quizSetId: setA,
            totalQuestions: 20,
          ),
        ],
        answerCountByResultId: const {},
      );

      expect(completed, isEmpty);
    });

    test('fewer answers than total_questions → not completed', () {
      final completed = completedQuizSetIdsFromAttempts(
        results: const [
          LessonQuizResultAttempt(
            id: 'r1',
            quizSetId: setA,
            totalQuestions: 20,
          ),
        ],
        answerCountByResultId: const {'r1': 5},
      );

      expect(completed, isEmpty);
    });

    test('answers equal total_questions → completed', () {
      final completed = completedQuizSetIdsFromAttempts(
        results: const [
          LessonQuizResultAttempt(
            id: 'r1',
            quizSetId: setA,
            totalQuestions: 20,
          ),
        ],
        answerCountByResultId: const {'r1': 20},
      );

      expect(completed, {setA});
    });

    test('one partial and one complete → completed', () {
      final completed = completedQuizSetIdsFromAttempts(
        results: const [
          LessonQuizResultAttempt(
            id: 'partial',
            quizSetId: setA,
            totalQuestions: 20,
          ),
          LessonQuizResultAttempt(
            id: 'complete',
            quizSetId: setA,
            totalQuestions: 20,
          ),
        ],
        answerCountByResultId: const {'partial': 3, 'complete': 20},
      );

      expect(completed, {setA});
    });

    test('all attempts partial → not completed', () {
      final completed = completedQuizSetIdsFromAttempts(
        results: const [
          LessonQuizResultAttempt(
            id: 'r1',
            quizSetId: setA,
            totalQuestions: 20,
          ),
          LessonQuizResultAttempt(
            id: 'r2',
            quizSetId: setA,
            totalQuestions: 20,
          ),
        ],
        answerCountByResultId: const {'r1': 2, 'r2': 10},
      );

      expect(completed, isEmpty);
    });
  });

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

    test('all answers → confirm exit', () {
      expect(
        shouldConfirmExitBeforeSummary([
          QuizAnswerOption.a,
          QuizAnswerOption.b,
        ]),
        isTrue,
      );
    });
  });

  group('allowsImmediateQuizSheetExit', () {
    test('no answers → immediate pop allowed', () {
      expect(allowsImmediateQuizSheetExit(const [null, null]), isTrue);
    });

    test('partial answers → must confirm before pop', () {
      expect(allowsImmediateQuizSheetExit([QuizAnswerOption.a, null]), isFalse);
    });
  });
}
