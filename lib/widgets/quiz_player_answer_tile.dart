import 'package:flutter/material.dart';

import '../theme/quiz_player_density.dart';
import '../theme/quiz_player_visual_tokens.dart';
import 'nautical_answer_marker.dart';

/// Opzione di risposta condivisa da Quiz Esame e Schede lezione.
class QuizPlayerAnswerTile extends StatelessWidget {
  const QuizPlayerAnswerTile({
    super.key,
    required this.answerNumber,
    required this.text,
    required this.onTap,
    required this.markerState,
    this.backgroundColor = QuizPlayerVisual.cardSurface,
    this.borderColor = QuizPlayerVisual.cardBorder,
    this.borderWidth = 1.2,
    this.density = QuizPlayerContentDensity.standard,
  });

  final int answerNumber;
  final String text;
  final VoidCallback? onTap;
  final NauticalAnswerMarkerState markerState;
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;
  final QuizPlayerContentDensity density;

  /// Padding effettivo della tile.
  EdgeInsets get contentPadding => QuizPlayerDensity.answerPadding(density);

  /// Altezza minima effettiva della tile.
  double get minHeight => QuizPlayerDensity.answerMinHeight(density);

  /// Border radius effettivo della tile.
  double get cardRadius => QuizPlayerVisual.cardRadius;

  @override
  Widget build(BuildContext context) {
    final compact = QuizPlayerVisual.isCompact(context);
    final answerStyle = QuizPlayerVisual.answerStyle(context);
    final padding = QuizPlayerDensity.answerPadding(density);
    final minH = QuizPlayerDensity.answerMinHeight(density);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(QuizPlayerVisual.cardRadius),
        child: Ink(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(QuizPlayerVisual.cardRadius),
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minH),
            child: Padding(
              padding: padding,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text(text, style: answerStyle)),
                  const SizedBox(width: 10),
                  NauticalAnswerMarker(
                    answerNumber: answerNumber,
                    state: markerState,
                    compact: compact,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
