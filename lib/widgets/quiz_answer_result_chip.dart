import 'package:flutter/material.dart';

import '../theme/quiz_player_visual_tokens.dart';

/// Feedback compatto dopo selezione risposta (schede lezione + review storico).
///
/// Tre stati: corretta / errata / non risposta.
class QuizAnswerResultChip extends StatelessWidget {
  const QuizAnswerResultChip({
    super.key,
    required this.isCorrect,
    this.unanswered = false,
    this.correctLetter,
    this.explanation,
    this.dense = false,
  });

  /// True se la risposta selezionata è corretta (ignorato se [unanswered]).
  final bool isCorrect;

  /// True se la domanda non è stata risposta (`selected_option == null`).
  final bool unanswered;

  final String? correctLetter;
  final String? explanation;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final Color color;
    final Color fill;
    final String label;
    final IconData icon;

    if (unanswered) {
      color = const Color(0xFF6B7280);
      fill = const Color(0xFFF3F4F6);
      label = 'Non risposta';
      icon = Icons.radio_button_unchecked_rounded;
    } else if (isCorrect) {
      color = QuizPlayerVisual.correctBorder;
      fill = QuizPlayerVisual.correctFill;
      label = 'Risposta corretta';
      icon = Icons.check_circle_rounded;
    } else {
      color = QuizPlayerVisual.wrongBorder;
      fill = QuizPlayerVisual.wrongFill;
      label = 'Risposta errata';
      icon = Icons.cancel_rounded;
    }

    final showCorrectHint =
        !isCorrect && correctLetter != null && correctLetter!.isNotEmpty;

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
                Icon(icon, size: dense ? 18 : 20, color: color),
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
            if (showCorrectHint) ...[
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
