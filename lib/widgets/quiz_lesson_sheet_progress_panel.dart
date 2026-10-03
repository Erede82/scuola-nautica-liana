import 'package:flutter/material.dart';

import '../theme/quiz_player_visual_tokens.dart';
import 'quiz_question_progress_strip.dart';

/// Pannello progresso condiviso Schede lezione / Multischeda.
///
/// Allinea strip domande + chip Corrette/Errori/Non risposte.
class QuizLessonSheetProgressPanel extends StatelessWidget {
  const QuizLessonSheetProgressPanel({
    super.key,
    required this.currentIndex,
    required this.total,
    required this.isAnswered,
    required this.cellTone,
    required this.correctCount,
    required this.wrongCount,
    required this.unansweredCount,
    this.header,
  });

  final int currentIndex;
  final int total;
  final bool Function(int index) isAnswered;
  final QuizProgressCellTone Function(int index) cellTone;
  final int correctCount;
  final int wrongCount;
  final int unansweredCount;

  /// Opzionale (es. "Scheda 2 di 13" in Multischeda).
  final String? header;

  static const Color _neutralColor = QuizPlayerVisual.cardBorder;
  static const Color _correctColor = QuizPlayerVisual.correctBorder;
  static const Color _wrongColor = QuizPlayerVisual.wrongBorder;
  static const Color _unansweredColor = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      margin: QuizPlayerVisual.lessonSheetProgressPanelMargin,
      padding: QuizPlayerVisual.progressPanelPadding,
      decoration: BoxDecoration(
        color: QuizPlayerVisual.cardSurface,
        borderRadius: BorderRadius.circular(QuizPlayerVisual.cardRadius),
        border: Border.all(color: _neutralColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 6,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null) ...[
            Text(
              header!,
              style: textTheme.titleSmall?.copyWith(
                color: QuizPlayerVisual.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
          ],
          QuizQuestionProgressStrip(
            currentIndex: currentIndex,
            total: total,
            isAnswered: isAnswered,
            cellTone: cellTone,
            compact: true,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _StatChip(
                label: 'Corrette',
                value: '$correctCount',
                color: _correctColor,
                background: QuizPlayerVisual.correctFill,
              ),
              _StatChip(
                label: 'Errori',
                value: '$wrongCount',
                color: _wrongColor,
                background: QuizPlayerVisual.wrongFill,
              ),
              _StatChip(
                label: 'Non risposte',
                value: '$unansweredCount',
                color: _unansweredColor,
                background: const Color(0xFFF3F4F6),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    required this.background,
  });

  final String label;
  final String value;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        '$label: $value',
        style: textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
