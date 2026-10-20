import 'package:flutter/material.dart';

import '../domain/student_quiz_statistics_models.dart';
import '../domain/student_stats_source.dart';
import '../theme/app_visual_tokens.dart';
import '../utils/guida_datetime_format.dart';
import 'statistics_summary_section.dart';
import 'student_stats_source_filter_bar.dart';

/// Layout mode for [StudentStatsTopicSection] (testable).
enum StudentStatsTopicLayoutMode {
  /// width < 1024 — card list.
  cards,

  /// 1024 <= width < 1600 — compact rows, no horizontal scroll.
  laptop,

  /// width >= 1600 — full DataTable.
  desktop,
}

StudentStatsTopicLayoutMode studentStatsTopicLayoutModeForWidth(double width) {
  if (width < 1024) return StudentStatsTopicLayoutMode.cards;
  if (width < 1600) return StudentStatsTopicLayoutMode.laptop;
  return StudentStatsTopicLayoutMode.desktop;
}

/// Sezione STATISTICHE PER ARGOMENTO.
class StudentStatsTopicSection extends StatelessWidget {
  const StudentStatsTopicSection({
    super.key,
    required this.topics,
    required this.source,
    required this.onSourceChanged,
  });

  final List<TopicStatistics> topics;
  final StudentStatsSource source;
  final ValueChanged<StudentStatsSource> onSourceChanged;

  static const Color _card = Color(0xFFFFFFFF);
  static const Color _border = AppVisual.chipFill;
  static const Color _primary = AppVisual.logoBlue;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final width = MediaQuery.sizeOf(context).width;
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
              StudentStatsTopicLayoutMode.laptop => _laptopTable(textTheme),
              StudentStatsTopicLayoutMode.desktop => _desktopTable(textTheme),
            },
        ],
      ),
    );
  }

  Widget _laptopTable(TextTheme textTheme) {
    return Column(
      key: const ValueKey('student-stats-topic-mode-laptop'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _laptopHeader(textTheme),
        const Divider(height: 1),
        for (final topic in topics) ...[
          _laptopRow(textTheme, topic),
          const Divider(height: 1),
        ],
      ],
    );
  }

  Widget _laptopHeader(TextTheme textTheme) {
    final style = textTheme.labelLarge?.copyWith(
      color: AppVisual.inkMuted,
      fontWeight: FontWeight.w700,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 5, child: Text('Argomento', style: style)),
          SizedBox(
            width: 64,
            child: Text('Domande', style: style, textAlign: TextAlign.end),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: Text('Risposte', style: style),
          ),
          SizedBox(
            width: 72,
            child: Text('Precisione', style: style, textAlign: TextAlign.end),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 108,
            child: Text('Ultima attività', style: style),
          ),
        ],
      ),
    );
  }

  Widget _laptopRow(TextTheme textTheme, TopicStatistics topic) {
    final body = textTheme.bodyMedium?.copyWith(
      color: AppVisual.ink,
      fontWeight: FontWeight.w600,
      height: 1.25,
    );
    final muted = textTheme.bodySmall?.copyWith(
      color: AppVisual.inkMuted,
      fontWeight: FontWeight.w600,
      height: 1.25,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              topic.title,
              softWrap: true,
              style: body?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(
            width: 64,
            child: Text(
              '${topic.questionsSeen}',
              textAlign: TextAlign.end,
              style: body,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: _responsesCell(textTheme, topic),
          ),
          SizedBox(
            width: 72,
            child: Text(
              StatisticsSummarySection.formatPercent(topic.accuracyPercentage),
              textAlign: TextAlign.end,
              style: body,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 108,
            child: Text(
              topic.lastActivity == null
                  ? '—'
                  : GuidaDateTimeFormat.formatDate(topic.lastActivity!),
              softWrap: true,
              style: muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _responsesCell(TextTheme textTheme, TopicStatistics topic) {
    final label =
        'Corrette ${topic.correct}, Errate ${topic.wrong}, '
        'Non risposte ${topic.unanswered}';
    final style = textTheme.bodySmall?.copyWith(
      color: AppVisual.ink,
      fontWeight: FontWeight.w600,
      height: 1.3,
    );
    return Semantics(
      label: label,
      child: Wrap(
        spacing: 8,
        runSpacing: 2,
        children: [
          Text('Corrette ${topic.correct}', style: style),
          Text('Errate ${topic.wrong}', style: style),
          Text('Non risposte ${topic.unanswered}', style: style),
        ],
      ),
    );
  }

  Widget _desktopTable(TextTheme textTheme) {
    return KeyedSubtree(
      key: const ValueKey('student-stats-topic-mode-desktop'),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return DataTable(
            columnSpacing: 20,
            horizontalMargin: 0,
            headingTextStyle: textTheme.labelLarge?.copyWith(
              color: AppVisual.inkMuted,
              fontWeight: FontWeight.w700,
            ),
            dataTextStyle: textTheme.bodyMedium?.copyWith(color: AppVisual.ink),
            columns: const [
              DataColumn(label: Text('Argomento')),
              DataColumn(label: Text('Domande'), numeric: true),
              DataColumn(label: Text('Corrette'), numeric: true),
              DataColumn(label: Text('Errate'), numeric: true),
              DataColumn(label: Text('Non risposte'), numeric: true),
              DataColumn(label: Text('Precisione'), numeric: true),
              DataColumn(label: Text('Ultima attività')),
            ],
            rows: [
              for (final topic in topics)
                DataRow(
                  cells: [
                    DataCell(
                      SizedBox(
                        width: constraints.maxWidth * 0.28,
                        child: Text(topic.title, softWrap: true),
                      ),
                    ),
                    DataCell(Text('${topic.questionsSeen}')),
                    DataCell(Text('${topic.correct}')),
                    DataCell(Text('${topic.wrong}')),
                    DataCell(Text('${topic.unanswered}')),
                    DataCell(
                      Text(
                        StatisticsSummarySection.formatPercent(
                          topic.accuracyPercentage,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        topic.lastActivity == null
                            ? '—'
                            : GuidaDateTimeFormat.formatDate(
                                topic.lastActivity!,
                              ),
                      ),
                    ),
                  ],
                ),
            ],
          );
        },
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
