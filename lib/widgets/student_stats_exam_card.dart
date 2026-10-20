import 'package:flutter/material.dart';

import '../domain/student_quiz_statistics_models.dart';
import '../theme/app_visual_tokens.dart';
import '../utils/guida_datetime_format.dart';
import 'statistics_summary_section.dart';

/// Card SIMULAZIONI D'ESAME.
class StudentStatsExamCard extends StatelessWidget {
  const StudentStatsExamCard({super.key, required this.exam});

  final ExamStatistics exam;

  static const Color _card = Color(0xFFFFFFFF);
  static const Color _border = AppVisual.chipFill;
  static const Color _primary = AppVisual.logoBlue;
  static const Color _pass = Color(0xFF15803D);
  static const Color _fail = Color(0xFFC75D3A);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      key: const ValueKey('student-stats-exam-card'),
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
              Icon(Icons.school_rounded, color: _primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Simulazioni d\'esame',
                  style: textTheme.titleMedium?.copyWith(
                    color: AppVisual.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!exam.hasActivity) ...[
            Text(
              'Nessuna simulazione completata.',
              style: textTheme.bodyMedium?.copyWith(color: AppVisual.inkMuted),
            ),
          ] else ...[
            _metric(
              textTheme,
              label: 'Simulazioni svolte',
              value: '${exam.simulationsCount}',
            ),
            const SizedBox(height: 10),
            _metric(
              textTheme,
              label: '% promosse',
              value: StatisticsSummarySection.formatPercent(
                exam.passRatePercentage,
              ),
            ),
            const SizedBox(height: 10),
            _metric(
              textTheme,
              label: 'Media errori',
              value: StatisticsSummarySection.formatDecimal(exam.averageErrors),
            ),
            if (exam.recentResults.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'Ultime simulazioni',
                style: textTheme.labelLarge?.copyWith(
                  color: AppVisual.inkMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              for (final recent in exam.recentResults)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: (recent.passed ? _pass : _fail)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          recent.passed ? 'PASS' : 'FAIL',
                          style: textTheme.labelSmall?.copyWith(
                            color: recent.passed ? _pass : _fail,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${GuidaDateTimeFormat.formatDate(recent.completedAt)}'
                          ' · ${GuidaDateTimeFormat.formatTime(recent.completedAt)}',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppVisual.ink,
                          ),
                        ),
                      ),
                      Text(
                        '${recent.errorCount} err.',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppVisual.inkMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _metric(
    TextTheme textTheme, {
    required String label,
    required String value,
  }) {
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
