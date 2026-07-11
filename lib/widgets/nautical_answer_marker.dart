import 'package:flutter/material.dart';

import '../theme/app_visual_tokens.dart';

/// Stato visivo dell'indicatore risposta (stile scheda esame nautico).
enum NauticalAnswerMarkerState { neutral, selected, correct, wrong }

/// Indicatore compatto a destra della risposta: riquadro numerato 1/2/3.
class NauticalAnswerMarker extends StatelessWidget {
  const NauticalAnswerMarker({
    super.key,
    required this.answerNumber,
    this.state = NauticalAnswerMarkerState.neutral,
    this.compact = false,
    this.visible = true,
  }) : assert(answerNumber >= 1 && answerNumber <= 3);

  final int answerNumber;
  final NauticalAnswerMarkerState state;
  final bool compact;

  /// Se false, mantiene lo spazio riservato senza mostrare il riquadro.
  final bool visible;

  static const double _minColumnWidth = 40;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final boxSize = compact ? 30.0 : 34.0;

    final accent = _accentColor();
    final boxFill = _boxFillColor();
    final borderWidth = state == NauticalAnswerMarkerState.neutral ? 1.4 : 2.0;

    return SizedBox(
      width: _minColumnWidth,
      child: visible
          ? Center(
              child: Container(
                width: boxSize,
                height: boxSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: boxFill,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: accent, width: borderWidth),
                ),
                child: Text(
                  '$answerNumber',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: accent,
                    height: 1,
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Color _accentColor() {
    switch (state) {
      case NauticalAnswerMarkerState.neutral:
        return AppVisual.logoBlue.withValues(alpha: 0.75);
      case NauticalAnswerMarkerState.selected:
        return AppVisual.logoBlue;
      case NauticalAnswerMarkerState.correct:
        return AppVisual.success;
      case NauticalAnswerMarkerState.wrong:
        return AppVisual.error;
    }
  }

  Color _boxFillColor() {
    switch (state) {
      case NauticalAnswerMarkerState.neutral:
        return Colors.white;
      case NauticalAnswerMarkerState.selected:
        return const Color(0xFFE8F4FA);
      case NauticalAnswerMarkerState.correct:
        return const Color(0xFFE8F7EE);
      case NauticalAnswerMarkerState.wrong:
        return const Color(0xFFFDECEC);
    }
  }
}
