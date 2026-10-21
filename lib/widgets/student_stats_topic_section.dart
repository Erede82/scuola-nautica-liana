import 'package:flutter/material.dart';

import '../domain/student_quiz_statistics_models.dart';
import '../domain/student_stats_layout.dart';
import '../domain/student_stats_source.dart';
import '../theme/app_visual_tokens.dart';
import '../utils/guida_datetime_format.dart';
import 'statistics_summary_section.dart';
import 'student_stats_source_filter_bar.dart';

/// Layout mode for [StudentStatsTopicSection] (testable).
enum StudentStatsTopicLayoutMode {
  /// width < 1024 — card list.
  cards,

  /// 1024 <= width < 1200 — compact single column, no horizontal scroll.
  singleColumn,

  /// width >= 1200 — two columns of compact topic rows.
  twoColumns,
}

StudentStatsTopicLayoutMode studentStatsTopicLayoutModeForWidth(double width) {
  if (width < kStudentStatsTopCardsWideMinWidth) {
    return StudentStatsTopicLayoutMode.cards;
  }
  if (width < kStudentStatsTopicTwoColumnMinWidth) {
    return StudentStatsTopicLayoutMode.singleColumn;
  }
  return StudentStatsTopicLayoutMode.twoColumns;
}

/// Sezione STATISTICHE PER ARGOMENTO.
class StudentStatsTopicSection extends StatelessWidget {
  const StudentStatsTopicSection({
    super.key,
    required this.topics,
    required this.source,
    required this.onSourceChanged,
    this.layoutWidth,
  });

  final List<TopicStatistics> topics;
  final StudentStatsSource source;
  final ValueChanged<StudentStatsSource> onSourceChanged;

  /// Larghezza pannello (preferita). Se null → MediaQuery screen.
  final double? layoutWidth;

  static const Color _card = Color(0xFFFFFFFF);
  static const Color _border = AppVisual.chipFill;
  static const Color _primary = AppVisual.logoBlue;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final width = layoutWidth ?? MediaQuery.sizeOf(context).width;
    final mode = studentStatsTopicLayoutModeForWidth(width);

    return Container(
      key: const ValueKey('student-stats-topic-section'),
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
          Text(
            'Statistiche per argomento',
            style: textTheme.titleMedium?.copyWith(
              color: AppVisual.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Filtra le statistiche',
            style: textTheme.labelMedium?.copyWith(
              color: AppVisual.inkMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          StudentStatsSourceFilterBar(
            keyPrefix: 'student-stats-topic-filter',
            value: source,
            onChanged: onSourceChanged,
          ),
          const SizedBox(height: 14),
          if (topics.isEmpty)
            Text(
              key: const ValueKey('student-stats-topic-empty'),
              'Nessuna attività per argomento con i filtri selezionati.',
              style: textTheme.bodyMedium?.copyWith(color: AppVisual.inkMuted),
            )
          else
            switch (mode) {
              StudentStatsTopicLayoutMode.cards => Column(
                  key: const ValueKey('student-stats-topic-mode-cards'),
                  children: [
                    for (final topic in topics) ...[
                      _mobileCard(textTheme, topic),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              StudentStatsTopicLayoutMode.singleColumn =>
                _singleColumnList(textTheme),
              StudentStatsTopicLayoutMode.twoColumns =>
                _twoColumnGrid(textTheme),
            },
        ],
      ),
    );
  }

  Widget _singleColumnList(TextTheme textTheme) {
    return Column(
      key: const ValueKey('student-stats-topic-mode-single'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < topics.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _compactTopicRow(textTheme, topics[i]),
        ],
      ],
    );
  }

  Widget _twoColumnGrid(TextTheme textTheme) {
    final split = splitStudentStatsTopicsForTwoColumns(topics);
    return Row(
      key: const ValueKey('student-stats-topic-mode-two-columns'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            key: const ValueKey('student-stats-topic-col-left'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < split.left.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                _compactTopicRow(textTheme, split.left[i]),
              ],
            ],
          ),
        ),
        if (split.right.isNotEmpty) ...[
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              key: const ValueKey('student-stats-topic-col-right'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < split.right.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _compactTopicRow(textTheme, split.right[i]),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _compactTopicRow(TextTheme textTheme, TopicStatistics topic) {
    final titleStyle = textTheme.bodyMedium?.copyWith(
      color: AppVisual.ink,
      fontWeight: FontWeight.w700,
      height: 1.25,
    );
    final metaStyle = textTheme.bodySmall?.copyWith(
      color: AppVisual.inkMuted,
      fontWeight: FontWeight.w600,
      height: 1.3,
    );
    final activity = topic.lastActivity == null
        ? '—'
        : GuidaDateTimeFormat.formatDate(topic.lastActivity!);
    final precision = StatisticsSummarySection.formatPercent(
      topic.accuracyPercentage,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            topic.title,
            softWrap: true,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: titleStyle,
          ),
          const SizedBox(height: 4),
          Text(
            '${topic.questionsSeen} domande · ${topic.correct} corrette · '
            '${topic.wrong} errate · ${topic.unanswered} non risposte',
            softWrap: true,
            style: metaStyle,
          ),
          const SizedBox(height: 2),
          Text(
            '$precision · $activity',
            softWrap: true,
            style: metaStyle?.copyWith(
              color: AppVisual.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileCard(TextTheme textTheme, TopicStatistics topic) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            topic.title,
            softWrap: true,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyLarge?.copyWith(
              color: AppVisual.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _chip(textTheme, 'Domande', '${topic.questionsSeen}'),
              _chip(textTheme, 'Corrette', '${topic.correct}'),
              _chip(textTheme, 'Errate', '${topic.wrong}'),
              _chip(textTheme, 'Non risposte', '${topic.unanswered}'),
              _chip(
                textTheme,
                'Precisione',
                StatisticsSummarySection.formatPercent(
                  topic.accuracyPercentage,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            topic.lastActivity == null
                ? 'Ultima attività: —'
                : 'Ultima attività: '
                    '${GuidaDateTimeFormat.formatDate(topic.lastActivity!)}',
            style: textTheme.bodySmall?.copyWith(color: AppVisual.inkMuted),
          ),
        ],
      ),
    );
  }

  Widget _chip(TextTheme textTheme, String label, String value) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: textTheme.bodySmall?.copyWith(color: AppVisual.inkMuted),
          ),
          TextSpan(
            text: value,
            style: textTheme.bodySmall?.copyWith(
              color: AppVisual.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
