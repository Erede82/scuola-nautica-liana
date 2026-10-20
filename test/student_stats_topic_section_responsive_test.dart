import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/student_quiz_statistics_models.dart';
import 'package:scuola_nautica_liana/domain/student_stats_source.dart';
import 'package:scuola_nautica_liana/widgets/student_stats_topic_section.dart';

const _longTitle =
    '3. Sicurezza 1: Alcool e droga - Dotazioni di sicurezza e '
    'procedure di emergenza a bordo';

TopicStatistics _topic({
  String title = '1. Teoria dello scafo',
  int correct = 82,
  int wrong = 12,
  int unanswered = 3,
}) {
  return TopicStatistics(
    lessonNumber: 1,
    title: title,
    counts: TopicAnswerCounts(
      correct: correct,
      wrong: wrong,
      unanswered: unanswered,
      lastActivity: DateTime.utc(2026, 10, 10, 12),
    ),
  );
}

Future<void> _pumpSection(
  WidgetTester tester, {
  required Size size,
  required List<TopicStatistics> topics,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScale),
      ),
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StudentStatsTopicSection(
              topics: topics,
              source: StudentStatsSource.all,
              onSourceChanged: (_) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

bool _hasHorizontalScrollInTopicSection(WidgetTester tester) {
  final section = find.byKey(const ValueKey('student-stats-topic-section'));
  final anyHorizontal = find.descendant(
    of: section,
    matching: find.byWidgetPredicate((w) {
      if (w is! Scrollable) return false;
      return axisDirectionToAxis(w.axisDirection) == Axis.horizontal;
    }),
  );
  return anyHorizontal.evaluate().isNotEmpty;
}

void main() {
  group('studentStatsTopicLayoutModeForWidth', () {
    test('breakpoints', () {
      expect(
        studentStatsTopicLayoutModeForWidth(390),
        StudentStatsTopicLayoutMode.cards,
      );
      expect(
        studentStatsTopicLayoutModeForWidth(768),
        StudentStatsTopicLayoutMode.cards,
      );
      expect(
        studentStatsTopicLayoutModeForWidth(1023),
        StudentStatsTopicLayoutMode.cards,
      );
      expect(
        studentStatsTopicLayoutModeForWidth(1024),
        StudentStatsTopicLayoutMode.laptop,
      );
      expect(
        studentStatsTopicLayoutModeForWidth(1366),
        StudentStatsTopicLayoutMode.laptop,
      );
      expect(
        studentStatsTopicLayoutModeForWidth(1440),
        StudentStatsTopicLayoutMode.laptop,
      );
      expect(
        studentStatsTopicLayoutModeForWidth(1599),
        StudentStatsTopicLayoutMode.laptop,
      );
      expect(
        studentStatsTopicLayoutModeForWidth(1600),
        StudentStatsTopicLayoutMode.desktop,
      );
      expect(
        studentStatsTopicLayoutModeForWidth(1920),
        StudentStatsTopicLayoutMode.desktop,
      );
    });
  });

  group('StudentStatsTopicSection responsive', () {
    testWidgets('390 cards mode', (tester) async {
      await _pumpSection(
        tester,
        size: const Size(390, 844),
        topics: [_topic()],
      );
      expect(find.byKey(const ValueKey('student-stats-topic-mode-cards')), findsOneWidget);
      expect(find.byKey(const ValueKey('student-stats-topic-mode-laptop')), findsNothing);
      expect(_hasHorizontalScrollInTopicSection(tester), isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('768 cards mode', (tester) async {
      await _pumpSection(
        tester,
        size: const Size(768, 1024),
        topics: [_topic()],
      );
      expect(find.byKey(const ValueKey('student-stats-topic-mode-cards')), findsOneWidget);
      expect(_hasHorizontalScrollInTopicSection(tester), isFalse);
    });

    for (final size in [
      const Size(1024, 768),
      const Size(1366, 768),
      const Size(1440, 900),
    ]) {
      testWidgets(
        '${size.width.toInt()} laptop compact, no horizontal scroll, long title',
        (tester) async {
          await _pumpSection(
            tester,
            size: size,
            topics: [
              _topic(title: _longTitle, correct: 100, wrong: 20, unanswered: 3),
            ],
          );

          expect(
            find.byKey(const ValueKey('student-stats-topic-mode-laptop')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('student-stats-topic-mode-desktop')),
            findsNothing,
          );
          expect(_hasHorizontalScrollInTopicSection(tester), isFalse);
          expect(find.textContaining('Sicurezza 1'), findsOneWidget);
          expect(find.text('Domande'), findsOneWidget);
          expect(find.text('Risposte'), findsOneWidget);
          expect(find.textContaining('Corrette 100'), findsOneWidget);
          expect(find.textContaining('Errate 20'), findsOneWidget);
          expect(find.textContaining('Non risposte 3'), findsOneWidget);
          expect(find.text('Precisione'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('1920 desktop full table', (tester) async {
      await _pumpSection(
        tester,
        size: const Size(1920, 1080),
        topics: [_topic(title: _longTitle)],
      );
      expect(
        find.byKey(const ValueKey('student-stats-topic-mode-desktop')),
        findsOneWidget,
      );
      expect(find.byType(DataTable), findsOneWidget);
      expect(find.textContaining('Sicurezza 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('filter caption present', (tester) async {
      await _pumpSection(
        tester,
        size: const Size(1366, 768),
        topics: [_topic()],
      );
      expect(find.text('Filtra le statistiche'), findsOneWidget);
    });

    for (final scale in [1.0, 1.3, 1.5]) {
      for (final size in [
        const Size(390, 844),
        const Size(1366, 768),
        const Size(1440, 900),
      ]) {
        testWidgets(
          'textScale $scale @ ${size.width.toInt()} no overflow',
          (tester) async {
            await _pumpSection(
              tester,
              size: size,
              textScale: scale,
              topics: [
                _topic(
                  title: _longTitle,
                  correct: 100,
                  wrong: 20,
                  unanswered: 3,
                ),
              ],
            );
            expect(tester.takeException(), isNull);
            if (size.width >= 1024 && size.width < 1600) {
              expect(_hasHorizontalScrollInTopicSection(tester), isFalse);
            }
          },
        );
      }
    }
  });
}
