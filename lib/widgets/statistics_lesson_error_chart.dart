import 'package:flutter/material.dart';

import '../data/lesson_quiz_performance_mock.dart';
import '../models/lesson_quiz_performance_snapshot.dart';
import '../models/license_models.dart';
import '../theme/app_visual_tokens.dart';

/// Grafico a barre orizzontali: tutte le lezioni/topic con **evidenza** sulle 3 maggiori % errori.
class StatisticsLessonErrorChart extends StatelessWidget {
  const StatisticsLessonErrorChart({
    super.key,
    required this.categoryId,
  });

  final LicenseCategoryId categoryId;

  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _accentColor = Color(0xFF44BBCA);
  static const Color _textPrimaryColor = AppVisual.ink;
  static const Color _neutralColor = AppVisual.chipFill;
  static const Color _topIssueColor = Color(0xFFC75D3A);
  static const Color _topIssueBg = Color(0xFFFFF4F0);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final raw = LessonQuizPerformanceMock.snapshotsFor(categoryId);
    if (raw.isEmpty) {
      return const SizedBox.shrink();
    }

    final byLesson = List<LessonQuizPerformanceSnapshot>.from(raw)
      ..sort((a, b) => a.lessonNumber.compareTo(b.lessonNumber));

    final worstFirst = List<LessonQuizPerformanceSnapshot>.from(raw)
      ..sort(
        (a, b) =>
            b.averageErrorPercentage.compareTo(a.averageErrorPercentage),
      );
    final top3LessonNumbers = worstFirst
        .take(3)
        .map((e) => e.lessonNumber)
        .toSet();

    final maxErr = byLesson
        .map((e) => e.averageErrorPercentage)
        .reduce((a, b) => a > b ? a : b)
        .clamp(1.0, 100.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.insights_rounded,
              color: _primaryColor.withOpacity(0.9),
              size: 24,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Errori per lezione',
                    style: textTheme.titleMedium?.copyWith(
                      color: _textPrimaryColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Confronto su tutte le lezioni del programma. '
                    'Le tre barre evidenziate sono gli argomenti con il maggior tasso di errori — '
                    'utili per priorità di ripasso (anche in sezione Quiz).',
                    style: textTheme.bodySmall?.copyWith(
                      color: _textPrimaryColor.withOpacity(0.8),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...byLesson.map((s) {
          final isTop = top3LessonNumbers.contains(s.lessonNumber);
          final frac = (s.averageErrorPercentage / maxErr).clamp(0.0, 1.0);
          final shortTitle = s.lessonTitle.replaceFirst(RegExp(r'^\d+\.\s*'), '');
          final label = 'Lez. ${s.lessonNumber} · $shortTitle';

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: isTop ? _topIssueBg : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isTop
                      ? _topIssueColor.withOpacity(0.35)
                      : _neutralColor,
                  width: isTop ? 1.2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: _textPrimaryColor,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                      ),
                      if (isTop) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _topIssueColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Priorità',
                            style: textTheme.labelSmall?.copyWith(
                              color: _topIssueColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Text(
                        '${s.averageErrorPercentage.round()}%',
                        style: textTheme.titleSmall?.copyWith(
                          color: isTop ? _topIssueColor : _primaryColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: frac,
                      minHeight: 8,
                      backgroundColor: _neutralColor.withOpacity(0.65),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isTop ? _topIssueColor : _accentColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
