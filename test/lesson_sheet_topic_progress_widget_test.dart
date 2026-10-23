import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/student_quiz_statistics_models.dart';
import 'package:scuola_nautica_liana/domain/student_stats_source.dart';
import 'package:scuola_nautica_liana/widgets/student_stats_topic_section.dart';

TopicStatistics _colregs() {
  return TopicStatistics(
    lessonNumber: 2,
    title: 'COLREGs 2',
    counts: TopicAnswerCounts(
      correct: 320,
      wrong: 59,
      unanswered: 1,
      lastActivity: DateTime.utc(2026, 10, 23, 16),
    ),
    lessonSheetsCompleted: 2,
    lessonSheetsTotal: 15,
  );
}

Widget _section(StudentStatsSource source) {
  return MaterialApp(
    home: Scaffold(
      body: StudentStatsTopicSection(
        topics: [_colregs()],
        source: source,
        onSourceChanged: (_) {},
        layoutWidth: 684,
      ),
    ),
  );
}

void main() {
  testWidgets('Studio shows Schede lezione 2/15, 13%, precision and date', (
    tester,
  ) async {
    await tester.pumpWidget(_section(StudentStatsSource.study));
    expect(find.text('Schede lezione: 2 / 15'), findsOneWidget);
    expect(find.text('13%'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(
      find.textContaining('Precisione 84,2% · Ultima attività 23 ottobre 2026'),
      findsOneWidget,
    );
    expect(find.textContaining('380 domande'), findsOneWidget);
  });

  testWidgets('Tutto keeps the lesson-sheet label', (tester) async {
    await tester.pumpWidget(_section(StudentStatsSource.all));
    expect(find.text('Schede lezione: 2 / 15'), findsOneWidget);
  });

  testWidgets('Esame does not present lesson-sheet progress', (tester) async {
    await tester.pumpWidget(_section(StudentStatsSource.exam));
    expect(find.textContaining('Schede lezione'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.textContaining('Domande'), findsWidgets);
    expect(find.textContaining('380'), findsWidgets);
  });
}
