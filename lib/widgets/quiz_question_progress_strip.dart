import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_visual_tokens.dart';

/// Stato visivo di una cella nella barra indicatori domanda.
enum QuizProgressCellTone { unanswered, correct, wrong, answered }

/// Indicatore a quadratini: una cella per domanda (A12=20, D1=15, esame=20).
///
/// La larghezza è adattiva allo spazio disponibile (una sola riga, senza overflow).
class QuizQuestionProgressStrip extends StatelessWidget {
  const QuizQuestionProgressStrip({
    super.key,
    required this.currentIndex,
    required this.total,
    required this.isAnswered,
    this.cellTone,
    this.showCounter = true,
    this.compact = false,
  });

  final int currentIndex;
  final int total;
  final bool Function(int index) isAnswered;

  /// Se valorizzato, consente verde/rosso per corretto/errato.
  /// Altrimenti le domande risposte usano il blu generico.
  final QuizProgressCellTone Function(int index)? cellTone;

  final bool showCounter;

  /// Cella più bassa (player schede lezione).
  final bool compact;

  static const Color _answeredColor = AppVisual.logoBlue;
  static const Color _unansweredColor = Color(0xFFF3E8D8);
  static const Color _correctColor = Color(0xFF15803D);
  static const Color _wrongColor = Color(0xFFD32F2F);
  static const Color _currentRingColor = Color(0xFF0B4F78);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final maxCell = compact ? 16.0 : 22.0;
    final minCell = compact ? 8.0 : 10.0;
    final gap = compact ? 2.0 : 3.0;
    final counterGap = showCounter ? (compact ? 8.0 : 12.0) : 0.0;
    final counterReserve = showCounter ? (compact ? 44.0 : 52.0) : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableForCells = math.max(
          0.0,
          constraints.maxWidth - counterReserve - counterGap,
        );
        final rawSlot = total > 0 ? availableForCells / total : 0.0;
        final cellSize = math
            .min(maxCell, rawSlot)
            .clamp(0.0, maxCell)
            .toDouble();
        // Se c’è spazio, non scendere sotto il minimo; se non c’è, resta rawSlot.
        final resolved = rawSlot >= minCell
            ? math.max(minCell, cellSize)
            : cellSize;
        // Floor visivo: mai <= 0 (viewport strettissime), senza forzare
        // un minimo che faccia overflow con molte celle in Expanded.
        const visualFloor = 2.0;
        final uncapped = math.min(resolved, rawSlot);
        final size = uncapped > 0 ? uncapped : visualFloor;
        final rowHeight = math.max(visualFloor, size);

        return Row(
          children: [
            Expanded(
              child: SizedBox(
                height: rowHeight,
                child: Row(
                  children: List.generate(total, (index) {
                    final answered = isAnswered(index);
                    final current = index == currentIndex;
                    final tone =
                        cellTone?.call(index) ??
                        (answered
                            ? QuizProgressCellTone.answered
                            : QuizProgressCellTone.unanswered);
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: index == 0 || index == total - 1
                              ? 0
                              : gap / 2,
                        ),
                        child: Center(
                          child: SizedBox(
                            key: ValueKey<String>('quiz-progress-cell-$index'),
                            width: size,
                            height: size,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: _fillForTone(tone),
                                borderRadius: BorderRadius.circular(
                                  compact ? 2.5 : 3,
                                ),
                                border: Border.all(
                                  color: current
                                      ? _currentRingColor
                                      : Colors.transparent,
                                  width: current ? (compact ? 1.6 : 2) : 0,
                                ),
                                boxShadow: current
                                    ? [
                                        BoxShadow(
                                          color: _currentRingColor.withValues(
                                            alpha: 0.28,
                                          ),
                                          blurRadius: compact ? 3 : 4,
                                          offset: const Offset(0, 1),
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
            if (showCounter) ...[
              SizedBox(width: counterGap),
              SizedBox(
                width: counterReserve,
                child: Text(
                  '${currentIndex + 1}/$total',
                  textAlign: TextAlign.end,
                  style: (compact ? textTheme.labelLarge : textTheme.titleSmall)
                      ?.copyWith(
                        color: AppVisual.ink,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Color _fillForTone(QuizProgressCellTone tone) {
    switch (tone) {
      case QuizProgressCellTone.unanswered:
        return _unansweredColor;
      case QuizProgressCellTone.correct:
        return _correctColor;
      case QuizProgressCellTone.wrong:
        return _wrongColor;
      case QuizProgressCellTone.answered:
        return _answeredColor;
    }
  }
}
