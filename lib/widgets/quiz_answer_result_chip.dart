import 'package:flutter/material.dart';

import '../theme/quiz_player_visual_tokens.dart';

/// Feedback compatto dopo selezione risposta (schede lezione).
class QuizAnswerResultChip extends StatelessWidget {
  const QuizAnswerResultChip({
    super.key,
    required this.isCorrect,
    this.correctLetter,
    this.explanation,
    this.dense = false,
  });

  final bool isCorrect;
  final String? correctLetter;
  final String? explanation;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color = isCorrect
        ? QuizPlayerVisual.correctBorder
        : QuizPlayerVisual.wrongBorder;
    final fill = isCorrect
        ? QuizPlayerVisual.correctFill
        : QuizPlayerVisual.wrongFill;
    final label = isCorrect ? 'Risposta corretta' : 'Risposta errata';

    return Semantics(
      liveRegion: true,
      label: label,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: dense ? 10 : 12,
          vertical: dense ? 6 : 8,
        ),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(QuizPlayerVisual.cardRadius),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  size: dense ? 18 : 20,
                  color: color,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: textTheme.titleSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: dense ? 14.5 : 15.5,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            if (!isCorrect && correctLetter != null) ...[
              SizedBox(height: dense ? 4 : 6),
              Text(
                'La risposta corretta è $correctLetter.',
                style: textTheme.bodyMedium?.copyWith(
                  color: QuizPlayerVisual.ink,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
            ],
            if (explanation != null && explanation!.isNotEmpty) ...[
              SizedBox(height: dense ? 4 : 6),
              Text(
                explanation!,
                style: textTheme.bodyMedium?.copyWith(
                  color: QuizPlayerVisual.ink.withValues(alpha: 0.9),
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
