import 'package:flutter/material.dart';

import '../domain/quiz_player_keyboard.dart';
import '../theme/quiz_player_visual_tokens.dart';

/// Wrapper focus + shortcuts tastiera per i player quiz studente.
///
/// Invoca solo callback UI già esistenti; non conosce scoring/persistenza.
class QuizPlayerKeyboardScope extends StatefulWidget {
  const QuizPlayerKeyboardScope({
    super.key,
    required this.child,
    required this.onSelectAnswerIndex,
    required this.onConfirmOrNext,
    this.onNext,
    this.onPrevious,
    this.enabled = true,
    this.showDesktopHelp = true,
    this.autofocus = true,
  });

  final Widget child;

  /// 0-based option index (0/1/2). Caller applica le stesse regole del tap.
  final ValueChanged<int> onSelectAnswerIndex;

  /// Stessa primary action del footer (conferma/avanti/concludi).
  final VoidCallback onConfirmOrNext;

  /// Avanti (chevron / Space). Null = disabled → no-op.
  final VoidCallback? onNext;

  /// Indietro. Null = disabled → no-op.
  final VoidCallback? onPrevious;

  /// Se false, i tasti vengono ignorati (es. summary/submitting).
  final bool enabled;

  /// Mostra icona ⌨ con tooltip su viewport non-compact.
  final bool showDesktopHelp;

  final bool autofocus;

  static const String helpTooltip =
      'Tastiera: 1–3 Seleziona · Invio Conferma / Avanti · '
      '← Indietro · → Avanti · Spazio Avanti';

  @override
  State<QuizPlayerKeyboardScope> createState() =>
      _QuizPlayerKeyboardScopeState();
}

class _QuizPlayerKeyboardScopeState extends State<QuizPlayerKeyboardScope> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'quiz_player_keyboard');
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    final result = handleQuizPlayerKeyboardEvent(
      event: event,
      enabled: widget.enabled,
      isTextEditing: quizPlayerKeyboardIsTextEditingFocus(
        FocusManager.instance.primaryFocus,
      ),
      significantModifier: quizPlayerKeyboardHasSignificantModifier(),
      dispatch: (action) {
        switch (action) {
          case QuizPlayerKeyboardAction.selectAnswer0:
          case QuizPlayerKeyboardAction.selectAnswer1:
          case QuizPlayerKeyboardAction.selectAnswer2:
            widget.onSelectAnswerIndex(action.answerIndex!);
          case QuizPlayerKeyboardAction.confirmOrNext:
            widget.onConfirmOrNext();
          case QuizPlayerKeyboardAction.next:
            widget.onNext?.call();
          case QuizPlayerKeyboardAction.previous:
            widget.onPrevious?.call();
        }
      },
    );
    return switch (result) {
      QuizPlayerKeyboardHandleResult.ignored => KeyEventResult.ignored,
      QuizPlayerKeyboardHandleResult.handled ||
      QuizPlayerKeyboardHandleResult.handledWithAction =>
        KeyEventResult.handled,
    };
  }

  @override
  Widget build(BuildContext context) {
    final help = widget.showDesktopHelp && !QuizPlayerVisual.isCompact(context)
        ? const QuizPlayerKeyboardHelpBadge()
        : null;

    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: _onKeyEvent,
      child: help == null
          ? widget.child
          : Stack(
              children: [
                widget.child,
                Positioned(
                  right: 10,
                  bottom: 72,
                  child: help,
                ),
              ],
            ),
    );
  }
}

/// Badge discreto desktop con tooltip scorciatoie.
class QuizPlayerKeyboardHelpBadge extends StatelessWidget {
  const QuizPlayerKeyboardHelpBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: QuizPlayerKeyboardScope.helpTooltip,
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 250),
      child: Material(
        key: const Key('quiz_player_keyboard_help'),
        color: QuizPlayerVisual.cardSurface.withValues(alpha: 0.92),
        elevation: 1,
        shape: const CircleBorder(),
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(
            Icons.keyboard_alt_outlined,
            size: 18,
            color: QuizPlayerVisual.ink,
          ),
        ),
      ),
    );
  }
}
