import 'package:flutter/material.dart';

import '../models/quiz_statistics_summary.dart';
import '../theme/app_visual_tokens.dart';
import '../utils/guida_datetime_format.dart';

/// KPI riepilogativi statistiche quiz (schede lezione).
class StatisticsSummarySection extends StatelessWidget {
  const StatisticsSummarySection({super.key, required this.summary});

  final QuizStatisticsSummary summary;

  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _accentColor = Color(0xFF44BBCA);
  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _neutralColor = AppVisual.chipFill;
  static const Color _textPrimaryColor = AppVisual.ink;
  static const Color _warningColor = Color(0xFFC75D3A);

  static String formatPercent(double value) {
    if (value == 0) return '0%';
    final rounded = (value * 10).round() / 10;
    if (rounded == rounded.roundToDouble()) {
      return '${rounded.toInt()}%';
    }
    return '${rounded.toStringAsFixed(1).replaceAll('.', ',')}%';
  }

  static String formatDecimal(double value) {
    if (value == 0) return '0';
    final rounded = (value * 10).round() / 10;
    if (rounded == rounded.roundToDouble()) {
      return rounded.toInt().toString();
    }
    return rounded.toStringAsFixed(1).replaceAll('.', ',');
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width >= 720 ? 3 : 2;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
                Icons.analytics_outlined,
                color: _primaryColor.withValues(alpha: 0.9),
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Riepilogo',
                  style: textTheme.titleMedium?.copyWith(
                    color: _textPrimaryColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: crossAxisCount,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: width >= 720 ? 2.2 : 1.85,
            children: [
              _kpiTile(
                textTheme,
                label: 'Schede completate',
                value: '${summary.completedSheetsCount}',
                icon: Icons.fact_check_outlined,
                accent: _primaryColor,
              ),
              _kpiTile(
                textTheme,
                label: 'Precisione',
                value: formatPercent(summary.accuracyPercentage),
                icon: Icons.track_changes_rounded,
                accent: _accentColor,
              ),
              _kpiTile(
                textTheme,
                label: 'Risposte errate',
                value: '${summary.wrongCount}',
                icon: Icons.close_rounded,
                accent: _warningColor,
              ),
              _kpiTile(
                textTheme,
                label: 'Non risposte',
                value: '${summary.unansweredCount}',
                icon: Icons.help_outline_rounded,
                accent: _textPrimaryColor.withValues(alpha: 0.65),
              ),
              _kpiTile(
                textTheme,
                label: 'Media errori per scheda',
                value: formatDecimal(summary.averageErrorsPerSheet),
                icon: Icons.functions_rounded,
                accent: _primaryColor,
              ),
              _kpiTile(
                textTheme,
                label: 'Ultima attività',
                value: _lastActivityValue(),
                icon: Icons.schedule_rounded,
                accent: _accentColor,
                compactValue: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _lastActivityValue() {
    final at = summary.lastActivityAt;
    if (at == null) return '—';
    final date = GuidaDateTimeFormat.formatDate(at);
    final time = GuidaDateTimeFormat.formatTime(at);
    final lesson = summary.lastLessonNumber;
    final sheet = summary.lastSheetNumber;
    if (lesson != null && sheet != null) {
      return '$date · $time\nLez. $lesson · Scheda $sheet';
    }
    return '$date · $time';
  }

  Widget _kpiTile(
    TextTheme textTheme, {
    required String label,
    required String value,
    required IconData icon,
    required Color accent,
    bool compactValue = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _neutralColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelSmall?.copyWith(
                    color: _textPrimaryColor.withValues(alpha: 0.78),
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            maxLines: compactValue ? 3 : 1,
            overflow: TextOverflow.ellipsis,
            style: (compactValue ? textTheme.titleSmall : textTheme.titleLarge)
                ?.copyWith(
                  color: _textPrimaryColor,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
          ),
        ],
      ),
    );
  }
}
