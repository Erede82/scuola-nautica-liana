import 'package:flutter/material.dart';

import '../models/quiz_attempt_activity.dart';
import '../theme/app_visual_tokens.dart';
import '../utils/guida_datetime_format.dart';
import 'statistics_summary_section.dart';

/// Timeline compatta delle ultime schede lezione completate.
class StatisticsRecentAttemptsSection extends StatelessWidget {
  const StatisticsRecentAttemptsSection({
    super.key,
    required this.attempts,
    this.maxItems = 5,
  });

  final List<QuizAttemptActivity> attempts;
  final int maxItems;

  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _neutralColor = AppVisual.chipFill;
  static const Color _textPrimaryColor = AppVisual.ink;
  static const Color _accentColor = Color(0xFF44BBCA);

  @override
  Widget build(BuildContext context) {
    if (attempts.isEmpty) return const SizedBox.shrink();

    final textTheme = Theme.of(context).textTheme;
    final visible = attempts.take(maxItems).toList(growable: false);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _neutralColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.history_rounded,
                color: _primaryColor.withValues(alpha: 0.9),
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ultime schede svolte',
                  style: textTheme.titleMedium?.copyWith(
                    color: _textPrimaryColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...visible.map((a) => _attemptRow(textTheme, a)),
        ],
      ),
    );
  }

  Widget _attemptRow(TextTheme textTheme, QuizAttemptActivity attempt) {
    final accuracy = attempt.totalQuestions == 0
        ? 0.0
        : attempt.correctCount / attempt.totalQuestions * 100;
    final date = GuidaDateTimeFormat.formatDate(attempt.completedAt);
    final time = GuidaDateTimeFormat.formatTime(attempt.completedAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _accentColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _neutralColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Lezione ${attempt.lessonNumber} · Scheda ${attempt.sheetNumber}',
                    style: textTheme.titleSmall?.copyWith(
                      color: _textPrimaryColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  StatisticsSummarySection.formatPercent(accuracy),
                  style: textTheme.labelLarge?.copyWith(
                    color: _primaryColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '$date · $time',
              style: textTheme.bodySmall?.copyWith(
                color: _textPrimaryColor.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Corrette ${attempt.correctCount} · '
              'Errate ${attempt.wrongCount} · '
              'Non risposte ${attempt.unansweredCount}',
              style: textTheme.bodySmall?.copyWith(
                color: _textPrimaryColor.withValues(alpha: 0.82),
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
