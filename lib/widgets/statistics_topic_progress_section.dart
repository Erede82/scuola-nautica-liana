import 'package:flutter/material.dart';

import '../models/lesson_quiz_progress.dart';
import '../theme/app_visual_tokens.dart';
import 'statistics_summary_section.dart';

/// Pannello avanzamento dettagliato argomenti 1–14.
class StatisticsTopicProgressSection extends StatelessWidget {
  const StatisticsTopicProgressSection({
    super.key,
    required this.lessonProgress,
  });

  final List<LessonQuizProgress> lessonProgress;

  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _neutralColor = AppVisual.chipFill;
  static const Color _textPrimaryColor = AppVisual.ink;
  static const Color _completeColor = Color(0xFF3D8B6E);
  static const Color _inProgressColor = Color(0xFF44BBCA);

  @override
  Widget build(BuildContext context) {
    if (lessonProgress.isEmpty) return const SizedBox.shrink();

    final textTheme = Theme.of(context).textTheme;
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 900 ? 2 : 1;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
                Icons.view_list_rounded,
                color: _primaryColor.withValues(alpha: 0.9),
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Avanzamento per argomento',
                  style: textTheme.titleMedium?.copyWith(
                    color: _textPrimaryColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              if (columns == 1) {
                return Column(
                  children: [
                    for (final lesson in lessonProgress)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _lessonCard(textTheme, lesson),
                      ),
                  ],
                );
              }

              final midpoint = (lessonProgress.length / 2).ceil();
              final left = lessonProgress.sublist(0, midpoint);
              final right = lessonProgress.sublist(midpoint);

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        for (final lesson in left)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _lessonCard(textTheme, lesson),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      children: [
                        for (final lesson in right)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _lessonCard(textTheme, lesson),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _lessonCard(TextTheme textTheme, LessonQuizProgress lesson) {
    final status = _statusLabel(lesson);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _statusColor(lesson).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _neutralColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (lesson.isComplete)
                const Padding(
                  padding: EdgeInsets.only(right: 6, top: 2),
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: _completeColor,
                  ),
                ),
              Expanded(
                child: Text(
                  lesson.lessonTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(
                    color: _textPrimaryColor,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                status,
                style: textTheme.labelSmall?.copyWith(
                  color: _textPrimaryColor.withValues(alpha: 0.78),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!lesson.isAvailable)
            Text(
              'Non disponibile',
              style: textTheme.bodySmall?.copyWith(
                color: _textPrimaryColor.withValues(alpha: 0.72),
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${lesson.completedUniqueSheetsCount} / '
                    '${lesson.availableSheetsCount} schede',
                    style: textTheme.bodySmall?.copyWith(
                      color: _textPrimaryColor.withValues(alpha: 0.82),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  StatisticsSummarySection.formatPercent(
                    lesson.completionPercentage,
                  ),
                  style: textTheme.labelLarge?.copyWith(
                    color: _primaryColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: lesson.completionPercentage / 100,
                minHeight: 6,
                backgroundColor: _neutralColor,
                color: _statusColor(lesson),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _statusLabel(LessonQuizProgress lesson) {
    if (!lesson.isAvailable) return 'Non disponibile';
    if (lesson.isComplete) return 'Completato';
    if (lesson.isInProgress) return 'In corso';
    return 'Da iniziare';
  }

  Color _statusColor(LessonQuizProgress lesson) {
    if (!lesson.isAvailable) {
      return _textPrimaryColor.withValues(alpha: 0.45);
    }
    if (lesson.isComplete) return _completeColor;
    if (lesson.isInProgress) return _inProgressColor;
    return _textPrimaryColor.withValues(alpha: 0.5);
  }
}
