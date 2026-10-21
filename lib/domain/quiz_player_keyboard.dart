import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Azioni tastiera del player quiz (solo UI; nessuna business logic).
enum QuizPlayerKeyboardAction {
  /// Digits 1 / numpad 1 → prima opzione (index 0).
  selectAnswer0,

  /// Digits 2 / numpad 2 → seconda opzione (index 1).
  selectAnswer1,

  /// Digits 3 / numpad 3 → terza opzione (index 2).
  selectAnswer2,

  /// Enter / Numpad Enter → primary action (conferma/avanti/concludi).
  confirmOrNext,

  /// ArrowRight / Space → avanti.
  next,

  /// ArrowLeft → indietro.
  previous,
}

extension QuizPlayerKeyboardActionX on QuizPlayerKeyboardAction {
  /// Index risposta 0..2, oppure null se non è una selezione.
  int? get answerIndex => switch (this) {
    QuizPlayerKeyboardAction.selectAnswer0 => 0,
    QuizPlayerKeyboardAction.selectAnswer1 => 1,
    QuizPlayerKeyboardAction.selectAnswer2 => 2,
    QuizPlayerKeyboardAction.confirmOrNext ||
    QuizPlayerKeyboardAction.next ||
    QuizPlayerKeyboardAction.previous => null,
  };
}

/// True se Ctrl / Meta / Alt sono premuti (shortcut di sistema: non intercettare).
bool quizPlayerKeyboardHasSignificantModifier([HardwareKeyboard? keyboard]) {
  final hw = keyboard ?? HardwareKeyboard.instance;
  return hw.isControlPressed || hw.isMetaPressed || hw.isAltPressed;
}

/// Mappa un [KeyEvent] a un'azione quiz, o null se non gestita.
///
/// Non filtra KeyDown vs KeyRepeat: il caller decide (repeat → consume no-op).
/// [significantModifier] true → non intercettare (Ctrl/Cmd/Alt).
QuizPlayerKeyboardAction? resolveQuizPlayerKeyboardAction(
  KeyEvent event, {
  bool significantModifier = false,
}) {
  if (significantModifier) return null;

  final key = event.logicalKey;
  if (key == LogicalKeyboardKey.digit1 || key == LogicalKeyboardKey.numpad1) {
    return QuizPlayerKeyboardAction.selectAnswer0;
  }
  if (key == LogicalKeyboardKey.digit2 || key == LogicalKeyboardKey.numpad2) {
    return QuizPlayerKeyboardAction.selectAnswer1;
  }
  if (key == LogicalKeyboardKey.digit3 || key == LogicalKeyboardKey.numpad3) {
    return QuizPlayerKeyboardAction.selectAnswer2;
  }
  if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
    return QuizPlayerKeyboardAction.confirmOrNext;
  }
  if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.space) {
    return QuizPlayerKeyboardAction.next;
  }
  if (key == LogicalKeyboardKey.arrowLeft) {
    return QuizPlayerKeyboardAction.previous;
  }
  return null;
}

/// True se il focus primario è su input testuale (non controllare il quiz).
bool quizPlayerKeyboardIsTextEditingFocus(FocusNode? primaryFocus) {
  final context = primaryFocus?.context;
  if (context == null) return false;
  if (context.widget is EditableText) return true;
  return context.findAncestorWidgetOfExactType<EditableText>() != null;
}

/// Esito gestione tasto: [handled] se consumato (anche no-op su repeat).
enum QuizPlayerKeyboardHandleResult {
  ignored,
  handled,
  handledWithAction,
}

/// Logica condivisa KeyDown / KeyRepeat (testabile senza widget tree).
QuizPlayerKeyboardHandleResult handleQuizPlayerKeyboardEvent({
  required KeyEvent event,
  required bool enabled,
  required bool isTextEditing,
  required void Function(QuizPlayerKeyboardAction action) dispatch,
  bool significantModifier = false,
}) {
  if (!enabled || isTextEditing) {
    return QuizPlayerKeyboardHandleResult.ignored;
  }

  final action = resolveQuizPlayerKeyboardAction(
    event,
    significantModifier: significantModifier,
  );
  if (action == null) return QuizPlayerKeyboardHandleResult.ignored;

  if (event is KeyRepeatEvent) {
    return QuizPlayerKeyboardHandleResult.handled;
  }
  if (event is! KeyDownEvent) {
    return QuizPlayerKeyboardHandleResult.ignored;
  }

  dispatch(action);
  return QuizPlayerKeyboardHandleResult.handledWithAction;
}
