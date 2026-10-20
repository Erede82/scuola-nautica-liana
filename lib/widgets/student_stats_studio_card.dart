import 'package:flutter/material.dart';

import '../domain/student_quiz_statistics_models.dart';
import '../theme/app_visual_tokens.dart';
import 'statistics_summary_section.dart';

/// Card STUDIO — schede normali + Multischeda.
class StudentStatsStudioCard extends StatelessWidget {
  const StudentStatsStudioCard({super.key, required this.study});

  final StudyStatistics study;

  static const Color _card = Color(0xFFFFFFFF);
  static const Color _border = AppVisual.chipFill;
  static const Color _primary = AppVisual.logoBlue;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final topicsLabel = study.topicsTotal > 0
        ? '${study.topicsStudied} / ${study.topicsTotal}'
        : '${study.topicsStudied}';

    return Container(
      key: const ValueKey('student-stats-studio-card'),
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
              Icon(Icons.menu_book_rounded, color: _primary, size: 22),
              const SizedBox(width: 8),
              Text(
                'Studio',
                style: textTheme.titleMedium?.copyWith(
                  color: AppVisual.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _metric(
            textTheme,
            label: 'Schede svolte',
            value: '${study.sheetsCompleted}',
          ),
          const SizedBox(height: 10),
          _metric(
            textTheme,
            label: 'Precisione',
            value: study.questionsSeen == 0
                ? '—'
                : StatisticsSummarySection.formatPercent(
                    study.accuracyPercentage,
                  ),
          ),
          const SizedBox(height: 10),
          _metric(
            textTheme,
            label: 'Argomenti studiati',
            value: topicsLabel,
          ),
        ],
      ),
    );
  }

  Widget _metric(TextTheme textTheme, {required String label, required String value}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              color: AppVisual.inkMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: textTheme.titleMedium?.copyWith(
            color: AppVisual.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
