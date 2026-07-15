import 'package:flutter/material.dart';

import '../models/lesson_quiz_progress.dart';
import '../models/quiz_attempt_activity.dart';
import '../models/quiz_statistics_summary.dart';
import '../theme/app_visual_tokens.dart';
import '../utils/guida_datetime_format.dart';
import 'statistics_error_trend.dart';

/// Cruscotto KPI statistiche quiz (schede lezione).
class StatisticsSummarySection extends StatelessWidget {
  const StatisticsSummarySection({
    super.key,
    required this.summary,
    required this.progress,
    required this.recentAttempts,
  });

  final QuizStatisticsSummary summary;
  final CategoryQuizProgress progress;
  final List<QuizAttemptActivity> recentAttempts;

  static const double averageErrorThreshold = 4.0;

  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _accentColor = Color(0xFF44BBCA);
  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _neutralColor = AppVisual.chipFill;
  static const Color _textPrimaryColor = AppVisual.ink;
  static const Color _withinColor = Color(0xFF3D8B6E);
  static const Color _aboveColor = Color(0xFFC75D3A);

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

  bool get _hasAttempts => summary.completedSheetsCount > 0;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 960 ? 3 : (width >= 640 ? 2 : 1);

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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tileWidth =
              (constraints.maxWidth - (columns - 1) * 10) / columns;

          return Column(
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
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: tileWidth,
                    height: 160,
                    child: _completedSheetsTile(textTheme),
                  ),
                  SizedBox(
                    width: tileWidth,
                    height: 160,
                    child: _topicsProgressTile(textTheme),
                  ),
                  SizedBox(
                    width: tileWidth,
                    height: 160,
                    child: _examSimulationsTile(textTheme),
                  ),
                  SizedBox(
                    width: tileWidth,
                    height: 160,
                    child: _accuracyTile(textTheme),
                  ),
                  SizedBox(
                    width: tileWidth,
                    height: 160,
                    child: _averageErrorsTile(textTheme),
                  ),
                  SizedBox(
                    width: tileWidth,
                    height: 160,
                    child: _lastActivityTile(textTheme),
                  ),
                ],
              ),
              if (_hasAttempts && recentAttempts.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  'Andamento errori ultime schede',
                  style: textTheme.labelLarge?.copyWith(
                    color: _textPrimaryColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                StatisticsErrorTrend(attempts: recentAttempts),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _completedSheetsTile(TextTheme textTheme) {
    final hasCatalog = progress.hasCatalog;
    final completed = progress.totalCompletedUniqueSheets;
    final total = progress.totalAvailableSheets;
    final percent = progress.overallCompletionPercentage;

    return _kpiTile(
      textTheme,
      label: 'Schede completate',
      icon: Icons.fact_check_outlined,
      accent: _primaryColor,
      child: hasCatalog
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$completed su $total',
                  style: textTheme.titleLarge?.copyWith(
                    color: _textPrimaryColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatPercent(percent)} completato',
                  style: textTheme.bodySmall?.copyWith(
                    color: _textPrimaryColor.withValues(alpha: 0.78),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percent / 100,
                    minHeight: 6,
                    backgroundColor: _neutralColor,
                    color: _primaryColor,
                  ),
                ),
              ],
            )
          : Text(
              'Non disponibile',
              style: textTheme.titleMedium?.copyWith(
                color: _textPrimaryColor,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }

  Widget _topicsProgressTile(TextTheme textTheme) {
    final hasCatalog = progress.hasCatalog;
    final completed = progress.completedLessonsCount;
    final available = progress.availableLessonsCount;
    final inProgress = progress.inProgressLessonsCount;

    return _kpiTile(
      textTheme,
      label: 'Progresso argomenti',
      icon: Icons.menu_book_rounded,
      accent: _accentColor,
      child: hasCatalog
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$completed su $available completati',
                  style: textTheme.titleLarge?.copyWith(
                    color: _textPrimaryColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  inProgress > 0
                      ? '$inProgress in corso'
                      : 'Nessun argomento in corso',
                  style: textTheme.bodySmall?.copyWith(
                    color: _textPrimaryColor.withValues(alpha: 0.78),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          : Text(
              'Non disponibile',
              style: textTheme.titleMedium?.copyWith(
                color: _textPrimaryColor,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }

  Widget _examSimulationsTile(TextTheme textTheme) {
    return _kpiTile(
      textTheme,
      label: 'Simulazioni esame',
      icon: Icons.school_outlined,
      accent: _textPrimaryColor.withValues(alpha: 0.55),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Storico non ancora disponibile',
            style: textTheme.titleSmall?.copyWith(
              color: _textPrimaryColor,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Le simulazioni saranno mostrate quando verrà attivato il '
            'salvataggio dei risultati.',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              color: _textPrimaryColor.withValues(alpha: 0.75),
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _accuracyTile(TextTheme textTheme) {
    final hasAttempts = _hasAttempts;
    final percent = summary.accuracyPercentage;

    return _kpiTile(
      textTheme,
      label: 'Precisione',
      icon: Icons.track_changes_rounded,
      accent: _accentColor,
      child: hasAttempts
          ? Row(
              children: [
                SizedBox(
                  width: 52,
                  height: 52,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: percent / 100,
                        strokeWidth: 5,
                        backgroundColor: _neutralColor,
                        color: _accentColor,
                      ),
                      Center(
                        child: Text(
                          formatPercent(percent),
                          style: textTheme.labelSmall?.copyWith(
                            color: _textPrimaryColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Corrette / totale risposte considerate',
                    style: textTheme.bodySmall?.copyWith(
                      color: _textPrimaryColor.withValues(alpha: 0.78),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            )
          : Text(
              'Nessuna scheda',
              style: textTheme.titleMedium?.copyWith(
                color: _textPrimaryColor.withValues(alpha: 0.72),
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }

  Widget _averageErrorsTile(TextTheme textTheme) {
    final hasAttempts = _hasAttempts;
    final average = summary.averageErrorsPerSheet;
    final withinThreshold = average <= averageErrorThreshold;
    final statusColor = !hasAttempts
        ? _textPrimaryColor.withValues(alpha: 0.55)
        : (withinThreshold ? _withinColor : _aboveColor);
    final statusLabel = !hasAttempts
        ? 'Nessuna scheda'
        : (withinThreshold ? 'Entro la soglia' : 'Sopra la soglia');

    return _kpiTile(
      textTheme,
      label: 'Media errori per scheda',
      icon: Icons.functions_rounded,
      accent: statusColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                hasAttempts ? formatDecimal(average) : '—',
                style: textTheme.titleLarge?.copyWith(
                  color: _textPrimaryColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusLabel,
                  style: textTheme.labelMedium?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _lastActivityTile(TextTheme textTheme) {
    final at = summary.lastActivityAt;
    if (at == null || !_hasAttempts) {
      return _kpiTile(
        textTheme,
        label: 'Ultima attività',
        icon: Icons.schedule_rounded,
        accent: _accentColor,
        child: Text(
          'Nessuna scheda completata',
          style: textTheme.titleSmall?.copyWith(
            color: _textPrimaryColor.withValues(alpha: 0.78),
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
        ),
      );
    }

    final date = GuidaDateTimeFormat.formatDate(at);
    final time = GuidaDateTimeFormat.formatTime(at);
    final lesson = summary.lastLessonNumber;
    final sheet = summary.lastSheetNumber;

    return _kpiTile(
      textTheme,
      label: 'Ultima attività',
      icon: Icons.schedule_rounded,
      accent: _accentColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$date · $time',
            style: textTheme.titleSmall?.copyWith(
              color: _textPrimaryColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (lesson != null && sheet != null) ...[
            const SizedBox(height: 4),
            Text(
              'Lezione $lesson · Scheda $sheet',
              style: textTheme.bodySmall?.copyWith(
                color: _textPrimaryColor.withValues(alpha: 0.82),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (recentAttempts.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Corrette ${recentAttempts.first.correctCount} · '
              'Errate ${recentAttempts.first.wrongCount} · '
              'Non risposte ${recentAttempts.first.unansweredCount}',
              style: textTheme.bodySmall?.copyWith(
                color: _textPrimaryColor.withValues(alpha: 0.78),
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kpiTile(
    TextTheme textTheme, {
    required String label,
    required IconData icon,
    required Color accent,
    required Widget child,
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
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
