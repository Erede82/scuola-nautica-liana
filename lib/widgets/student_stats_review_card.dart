import 'package:flutter/material.dart';

import '../domain/student_quiz_statistics_models.dart';
import '../domain/student_stats_layout.dart';
import '../domain/student_stats_source.dart';
import '../theme/app_visual_tokens.dart';
import 'statistics_summary_section.dart';
import 'student_stats_source_filter_bar.dart';

/// Card DA RIPASSARE — Top 3/5 argomenti critici (slice UI su ranked list).
class StudentStatsReviewCard extends StatelessWidget {
  const StudentStatsReviewCard({
    super.key,
    required this.topics,
    required this.source,
    required this.onSourceChanged,
    this.layoutWidth,
  });

  final List<ReviewTopic> topics;
  final StudentStatsSource source;
  final ValueChanged<StudentStatsSource> onSourceChanged;

  /// Larghezza pannello (preferita). Se null → MediaQuery screen.
  final double? layoutWidth;

  static const Color _card = Color(0xFFFFFFFF);
  static const Color _border = AppVisual.chipFill;
  static const Color _primary = AppVisual.logoBlue;
  static const Color _accent = Color(0xFFC75D3A);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final width = layoutWidth ?? MediaQuery.sizeOf(context).width;
    final visibleLimit = studentStatsReviewVisibleLimitForWidth(width);
    final visible = topics.take(visibleLimit).toList(growable: false);

    return Container(
      key: const ValueKey('student-stats-review-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
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
              Icon(Icons.replay_rounded, color: _primary, size: 22),
              const SizedBox(width: 8),
              Text(
                'Da ripassare',
                style: textTheme.titleMedium?.copyWith(
                  color: AppVisual.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Filtra il ripasso',
            style: textTheme.labelMedium?.copyWith(
              color: AppVisual.inkMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          StudentStatsSourceFilterBar(
            keyPrefix: 'student-stats-review-filter',
            value: source,
            onChanged: onSourceChanged,
          ),
          const SizedBox(height: 14),
          if (visible.isEmpty)
            Text(
              'Continua ad esercitarti per vedere gli argomenti da ripassare.',
              style: textTheme.bodyMedium?.copyWith(color: AppVisual.inkMuted),
            )
          else
            for (final item in visible) ...[
              _topicRow(textTheme, item),
              if (item != visible.last) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  Widget _topicRow(TextTheme textTheme, ReviewTopic item) {
    final topic = item.topic;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${item.rank}',
            style: textTheme.labelLarge?.copyWith(
              color: _accent,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                topic.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppVisual.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${StatisticsSummarySection.formatPercent(topic.accuracyPercentage)}'
                ' · ${topic.errors}/${topic.questionsSeen} errori',
                style: textTheme.bodySmall?.copyWith(
                  color: AppVisual.inkMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
