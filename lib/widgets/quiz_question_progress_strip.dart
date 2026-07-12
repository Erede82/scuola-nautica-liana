import 'package:flutter/material.dart';

import '../theme/app_visual_tokens.dart';

/// Indicatore a quadratini: una cella per domanda (tipicamente 20 in esame).
class QuizQuestionProgressStrip extends StatelessWidget {
  const QuizQuestionProgressStrip({
    super.key,
    required this.currentIndex,
    required this.total,
    required this.isAnswered,
    this.showCounter = true,
  });

  final int currentIndex;
  final int total;
  final bool Function(int index) isAnswered;
  final bool showCounter;

  static const Color _answeredColor = AppVisual.logoBlue;
  static const Color _unansweredColor = Color(0xFFF3E8D8);
  static const Color _currentRingColor = Color(0xFF0B4F78);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(
          child: Row(
            children: List.generate(total, (index) {
              final answered = isAnswered(index);
              final current = index == currentIndex;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: index == 0 ? 0 : 1.5,
                    right: index == total - 1 ? 0 : 1.5,
                  ),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: answered ? _answeredColor : _unansweredColor,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                          color: current
                              ? _currentRingColor
                              : Colors.transparent,
                          width: current ? 2 : 0,
                        ),
                        boxShadow: current
                            ? [
                                BoxShadow(
                                  color: _currentRingColor.withValues(
                                    alpha: 0.28,
                                  ),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        if (showCounter) ...[
          const SizedBox(width: 12),
          Text(
            '${currentIndex + 1}/$total',
            style: textTheme.titleSmall?.copyWith(
              color: AppVisual.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ],
    );
  }
}
