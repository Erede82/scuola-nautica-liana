import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/quiz_player_keyboard.dart';

KeyDownEvent _down(LogicalKeyboardKey key) => KeyDownEvent(
  physicalKey: PhysicalKeyboardKey.space,
  logicalKey: key,
  timeStamp: Duration.zero,
);

KeyRepeatEvent _repeat(LogicalKeyboardKey key) => KeyRepeatEvent(
  physicalKey: PhysicalKeyboardKey.space,
  logicalKey: key,
  timeStamp: Duration.zero,
);

KeyUpEvent _up(LogicalKeyboardKey key) => KeyUpEvent(
  physicalKey: PhysicalKeyboardKey.space,
  logicalKey: key,
  timeStamp: Duration.zero,
);

void main() {
  group('resolveQuizPlayerKeyboardAction', () {
    test('1/2/3 and numpad select only', () {
      expect(
        resolveQuizPlayerKeyboardAction(_down(LogicalKeyboardKey.digit1)),
        QuizPlayerKeyboardAction.selectAnswer0,
      );
      expect(
        resolveQuizPlayerKeyboardAction(_down(LogicalKeyboardKey.digit2)),
        QuizPlayerKeyboardAction.selectAnswer1,
      );
      expect(
        resolveQuizPlayerKeyboardAction(_down(LogicalKeyboardKey.digit3)),
        QuizPlayerKeyboardAction.selectAnswer2,
      );
      expect(
        resolveQuizPlayerKeyboardAction(_down(LogicalKeyboardKey.numpad1)),
        QuizPlayerKeyboardAction.selectAnswer0,
      );
      expect(
        resolveQuizPlayerKeyboardAction(_down(LogicalKeyboardKey.numpad2)),
        QuizPlayerKeyboardAction.selectAnswer1,
      );
      expect(
        resolveQuizPlayerKeyboardAction(_down(LogicalKeyboardKey.numpad3)),
        QuizPlayerKeyboardAction.selectAnswer2,
      );
    });

    test('Enter / NumpadEnter → confirmOrNext', () {
      expect(
        resolveQuizPlayerKeyboardAction(_down(LogicalKeyboardKey.enter)),
        QuizPlayerKeyboardAction.confirmOrNext,
      );
      expect(
        resolveQuizPlayerKeyboardAction(_down(LogicalKeyboardKey.numpadEnter)),
        QuizPlayerKeyboardAction.confirmOrNext,
      );
    });

    test('Right and Space → next; Left → previous', () {
      expect(
        resolveQuizPlayerKeyboardAction(_down(LogicalKeyboardKey.arrowRight)),
        QuizPlayerKeyboardAction.next,
      );
      expect(
        resolveQuizPlayerKeyboardAction(_down(LogicalKeyboardKey.space)),
        QuizPlayerKeyboardAction.next,
      );
      expect(
        resolveQuizPlayerKeyboardAction(_down(LogicalKeyboardKey.arrowLeft)),
        QuizPlayerKeyboardAction.previous,
      );
    });

    test('modifiers block shortcuts', () {
      expect(
        resolveQuizPlayerKeyboardAction(
          _down(LogicalKeyboardKey.digit1),
          significantModifier: true,
        ),
        isNull,
      );
      expect(
        resolveQuizPlayerKeyboardAction(
          _down(LogicalKeyboardKey.arrowRight),
          significantModifier: true,
        ),
        isNull,
      );
    });
  });

  group('handleQuizPlayerKeyboardEvent', () {
    test('KeyDown dispatches exactly one action', () {
      final actions = <QuizPlayerKeyboardAction>[];
      final result = handleQuizPlayerKeyboardEvent(
        event: _down(LogicalKeyboardKey.digit2),
        enabled: true,
        isTextEditing: false,
        dispatch: actions.add,
      );
      expect(result, QuizPlayerKeyboardHandleResult.handledWithAction);
      expect(actions, [QuizPlayerKeyboardAction.selectAnswer1]);
    });

    test('KeyRepeat consumes without dispatch (no multi-skip)', () {
      final actions = <QuizPlayerKeyboardAction>[];
      final result = handleQuizPlayerKeyboardEvent(
        event: _repeat(LogicalKeyboardKey.space),
        enabled: true,
        isTextEditing: false,
        dispatch: actions.add,
      );
      expect(result, QuizPlayerKeyboardHandleResult.handled);
      expect(actions, isEmpty);
    });

    test('KeyUp ignored', () {
      final actions = <QuizPlayerKeyboardAction>[];
      final result = handleQuizPlayerKeyboardEvent(
        event: _up(LogicalKeyboardKey.digit1),
        enabled: true,
        isTextEditing: false,
        dispatch: actions.add,
      );
      expect(result, QuizPlayerKeyboardHandleResult.ignored);
      expect(actions, isEmpty);
    });

    test('text editing exclusion', () {
      final actions = <QuizPlayerKeyboardAction>[];
      final result = handleQuizPlayerKeyboardEvent(
        event: _down(LogicalKeyboardKey.enter),
        enabled: true,
        isTextEditing: true,
        dispatch: actions.add,
      );
      expect(result, QuizPlayerKeyboardHandleResult.ignored);
      expect(actions, isEmpty);
    });

    test('disabled → ignored', () {
      final actions = <QuizPlayerKeyboardAction>[];
      final result = handleQuizPlayerKeyboardEvent(
        event: _down(LogicalKeyboardKey.arrowRight),
        enabled: false,
        isTextEditing: false,
        dispatch: actions.add,
      );
      expect(result, QuizPlayerKeyboardHandleResult.ignored);
      expect(actions, isEmpty);
    });

    test('Space KeyDown handled (prevent default scroll path)', () {
      final actions = <QuizPlayerKeyboardAction>[];
      final result = handleQuizPlayerKeyboardEvent(
        event: _down(LogicalKeyboardKey.space),
        enabled: true,
        isTextEditing: false,
        dispatch: actions.add,
      );
      expect(result, QuizPlayerKeyboardHandleResult.handledWithAction);
      expect(actions, [QuizPlayerKeyboardAction.next]);
    });
  });
}
