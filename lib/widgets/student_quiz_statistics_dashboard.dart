import 'package:flutter/material.dart';

import '../domain/student_quiz_statistics_models.dart';
import '../domain/student_stats_layout.dart';
import '../domain/student_stats_source.dart';
import '../theme/app_visual_tokens.dart';
import 'student_stats_exam_card.dart';
import 'student_stats_review_card.dart';
import 'student_stats_studio_card.dart';
import 'student_stats_topic_section.dart';

/// Corpo presentazionale condiviso StatisticsPage / staff panel.
///
/// Usa [layoutWidth] (larghezza contenuto), non MediaQuery screen.
class StudentQuizStatisticsDashboard extends StatelessWidget {
  const StudentQuizStatisticsDashboard({
    super.key,
    required this.statistics,
    required this.reviewSource,
    required this.topicSource,
    required this.onReviewSourceChanged,
    required this.onTopicSourceChanged,
    this.onRefresh,
    this.physics,
  });

  final StudentQuizStatistics statistics;
  final StudentStatsSource reviewSource;
  final StudentStatsSource topicSource;
  final ValueChanged<StudentStatsSource> onReviewSourceChanged;
  final ValueChanged<StudentStatsSource> onTopicSourceChanged;
  final Future<void> Function()? onRefresh;
  final ScrollPhysics? physics;

  static const Color _warningColor = Color(0xFFC75D3A);
  static const Color _textPrimaryColor = AppVisual.ink;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ignored =
        statistics.ignoredIncompleteLessonAttempts +
        statistics.ignoredIncompleteMultiAttempts +
        statistics.ignoredIncompleteExamAttempts;

    final list = LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final wide = width >= kStudentStatsTopCardsWideMinWidth;
        return ListView(
          physics:
              physics ??
              const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: wide
                  ? IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: StudentStatsStudioCard(
                              study: statistics.study,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: StudentStatsExamCard(exam: statistics.exam),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: StudentStatsReviewCard(
                              topics: statistics.reviewFor(reviewSource),
                              source: reviewSource,
                              onSourceChanged: onReviewSourceChanged,
                              layoutWidth: width,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        StudentStatsStudioCard(study: statistics.study),
                        const SizedBox(height: 12),
                        StudentStatsExamCard(exam: statistics.exam),
                        const SizedBox(height: 12),
                        StudentStatsReviewCard(
                          topics: statistics.reviewFor(reviewSource),
                          source: reviewSource,
                          onSourceChanged: onReviewSourceChanged,
                          layoutWidth: width,
                        ),
                      ],
                    ),
            ),
            if (ignored > 0) _ignoredNote(textTheme, ignored),
            StudentStatsTopicSection(
              topics: statistics.topicsFor(topicSource),
              source: topicSource,
              onSourceChanged: onTopicSourceChanged,
              layoutWidth: width,
            ),
          ],
        );
      },
    );

    final refresh = onRefresh;
    if (refresh == null) return list;
    return RefreshIndicator(
      color: AppVisual.logoBlue,
      onRefresh: refresh,
      child: list,
    );
  }

  Widget _ignoredNote(TextTheme textTheme, int ignoredCount) {
    final label = ignoredCount == 1
        ? '1 tentativo incompleto non incluso.'
        : '$ignoredCount tentativi incompleti non inclusi.';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _warningColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _warningColor.withValues(alpha: 0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, color: _warningColor, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Alcuni tentativi incompleti non sono stati inclusi. $label',
                style: textTheme.bodySmall?.copyWith(
                  color: _textPrimaryColor.withValues(alpha: 0.88),
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
