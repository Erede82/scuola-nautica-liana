import 'package:flutter/material.dart';

import '../models/quiz_attempt_activity.dart';
import '../theme/app_visual_tokens.dart';

/// Mini andamento errori sulle ultime schede (solo `wrongCount`).
class StatisticsErrorTrend extends StatelessWidget {
  const StatisticsErrorTrend({
    super.key,
    required this.attempts,
    this.maxItems = 5,
    this.threshold = 4,
  });

  final List<QuizAttemptActivity> attempts;
  final int maxItems;
  final double threshold;

  static const Color _withinColor = Color(0xFF3D8B6E);
  static const Color _aboveColor = Color(0xFFC75D3A);
  static const Color _neutralColor = AppVisual.chipFill;
  static const Color _textPrimaryColor = AppVisual.ink;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final visible = attempts.take(maxItems).toList(growable: false).reversed;

    if (visible.isEmpty) {
      return Text(
        'Nessun andamento disponibile',
        style: textTheme.labelSmall?.copyWith(
          color: _textPrimaryColor.withValues(alpha: 0.7),
        ),
      );
    }

    final maxWrong = visible
        .map((a) => a.wrongCount)
        .fold<int>(0, (a, b) => a > b ? a : b)
        .clamp(threshold.ceil(), 20);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 56,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final attempt in visible) ...[
                Expanded(
                  child: _bar(
                    wrongCount: attempt.wrongCount,
                    maxWrong: maxWrong,
                    sheetNumber: attempt.sheetNumber,
                  ),
                ),
                if (attempt != visible.last) const SizedBox(width: 4),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Container(
              width: 10,
              height: 2,
              color: _textPrimaryColor.withValues(alpha: 0.35),
            ),
            const SizedBox(width: 4),
            Text(
              'Soglia ${threshold.toInt()} errori',
              style: textTheme.labelSmall?.copyWith(
                color: _textPrimaryColor.withValues(alpha: 0.68),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _bar({
    required int wrongCount,
    required int maxWrong,
    required int sheetNumber,
  }) {
    final ratio = maxWrong <= 0 ? 0.0 : wrongCount / maxWrong;
    final color = wrongCount <= threshold ? _withinColor : _aboveColor;

    return Semantics(
      label: 'Scheda $sheetNumber: $wrongCount errori',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '$wrongCount',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _textPrimaryColor,
            ),
          ),
          const SizedBox(height: 2),
          Container(
            height: 36 * ratio.clamp(0.08, 1.0),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _neutralColor),
            ),
          ),
        ],
      ),
    );
  }
}
