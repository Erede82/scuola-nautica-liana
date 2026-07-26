import 'package:flutter/material.dart';

import '../domain/lesson_quiz_rules.dart';
import '../models/license_models.dart';
import '../models/quiz_attempt_activity.dart';
import '../theme/app_visual_tokens.dart';

/// Mini andamento errori sulle ultime schede (conteggio category-aware).
class StatisticsErrorTrend extends StatelessWidget {
  const StatisticsErrorTrend({
    super.key,
    required this.attempts,
    this.maxItems = 5,
    this.categoryId = LicenseCategoryId.motore,
    this.threshold,
  });

  final List<QuizAttemptActivity> attempts;
  final int maxItems;
  final LicenseCategoryId categoryId;

  /// Se null, usa [LessonQuizRules.maxErrors] della [categoryId].
  final double? threshold;

  static const Color _withinColor = Color(0xFF3D8B6E);
  static const Color _aboveColor = Color(0xFFC75D3A);
  static const Color _neutralColor = AppVisual.chipFill;
  static const Color _textPrimaryColor = AppVisual.ink;

  double get _effectiveThreshold =>
      threshold ??
      (lessonQuizRulesForCategory(categoryId)?.maxErrors ?? 4).toDouble();

  int _errorCount(QuizAttemptActivity attempt) {
    return lessonQuizErrorCountForResult(
      categoryId: categoryId,
      wrongCount: attempt.wrongCount,
      unansweredCount: attempt.unansweredCount,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final effectiveThreshold = _effectiveThreshold;
    final visible = attempts.take(maxItems).toList(growable: false).reversed;

    if (visible.isEmpty) {
      return Text(
        'Nessun andamento disponibile',
        style: textTheme.labelSmall?.copyWith(
          color: _textPrimaryColor.withValues(alpha: 0.7),
        ),
      );
    }

    final maxErrors = visible
        .map(_errorCount)
        .fold<int>(0, (a, b) => a > b ? a : b)
        .clamp(effectiveThreshold.ceil(), 20);

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
                    errorCount: _errorCount(attempt),
                    maxErrors: maxErrors,
                    sheetNumber: attempt.sheetNumber,
                    effectiveThreshold: effectiveThreshold,
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
              'Soglia ${effectiveThreshold.toInt()} errori',
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
    required int errorCount,
    required int maxErrors,
    required int sheetNumber,
    required double effectiveThreshold,
  }) {
    final ratio = maxErrors <= 0 ? 0.0 : errorCount / maxErrors;
    final color = errorCount <= effectiveThreshold ? _withinColor : _aboveColor;

    return Semantics(
      label: 'Scheda $sheetNumber: $errorCount errori',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '$errorCount',
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
