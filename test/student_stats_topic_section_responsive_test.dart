import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/student_quiz_statistics_models.dart';
import 'package:scuola_nautica_liana/domain/student_stats_source.dart';
import 'package:scuola_nautica_liana/widgets/student_stats_topic_section.dart';

const _longTitle =
    '3. Sicurezza 1: Alcool e droga - Dotazioni di sicurezza e '
    'procedure di emergenza a bordo';

TopicStatistics _topic({
  int lesson = 1,
  String? title,
  int correct = 82,
  int wrong = 12,
  int unanswered = 3,
}) {
  return TopicStatistics(
    lessonNumber: lesson,
    title: title ?? '$lesson. Teoria dello scafo',
    counts: TopicAnswerCounts(
      correct: correct,
      wrong: wrong,
      unanswered: unanswered,
      lastActivity: DateTime.utc(2026, 10, 10, 12),
    ),
  );
}

List<TopicStatistics> _topics(int count) => [
      for (var i = 1; i <= count; i++) _topic(lesson: i, title: '$i. Argomento $i'),
    ];

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
        StudentStatsTopicLayoutMode.singleColumn,
      );
      expect(
        studentStatsTopicLayoutModeForWidth(1199),
        StudentStatsTopicLayoutMode.singleColumn,
      );
      expect(
        studentStatsTopicLayoutModeForWidth(1200),
        StudentStatsTopicLayoutMode.twoColumns,
      );
      expect(
        studentStatsTopicLayoutModeForWidth(1366),
        StudentStatsTopicLayoutMode.twoColumns,
      );
      expect(
        studentStatsTopicLayoutModeForWidth(1440),
        StudentStatsTopicLayoutMode.twoColumns,
      );
      expect(
        studentStatsTopicLayoutModeForWidth(1920),
        StudentStatsTopicLayoutMode.twoColumns,
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
      expect(
        find.byKey(const ValueKey('student-stats-topic-mode-cards')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('student-stats-topic-mode-two-columns')),
        findsNothing,
      );
      expect(_hasHorizontalScrollInTopicSection(tester), isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('768 cards mode', (tester) async {
      await _pumpSection(
        tester,
        size: const Size(768, 1024),
        topics: [_topic()],
      );
      expect(
        find.byKey(const ValueKey('student-stats-topic-mode-cards')),
        findsOneWidget,
      );
      expect(_hasHorizontalScrollInTopicSection(tester), isFalse);
    });

    testWidgets('1024 single column compact', (tester) async {
      await _pumpSection(
        tester,
        size: const Size(1024, 768),
        topics: [
          _topic(title: _longTitle, correct: 100, wrong: 20, unanswered: 3),
        ],
      );
      expect(
        find.byKey(const ValueKey('student-stats-topic-mode-single')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('student-stats-topic-mode-two-columns')),
        findsNothing,
      );
      expect(_hasHorizontalScrollInTopicSection(tester), isFalse);
      expect(find.textContaining('Sicurezza 1'), findsOneWidget);
      expect(find.textContaining('123 domande'), findsOneWidget);
      expect(find.textContaining('100 corrette'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final size in [
      const Size(1366, 768),
      const Size(1440, 900),
      const Size(1920, 1080),
    ]) {
      testWidgets(
        '${size.width.toInt()} two columns, 14 topics → 7+7, no H-scroll',
        (tester) async {
          await _pumpSection(
            tester,
            size: size,
            topics: _topics(14),
          );

          expect(
            find.byKey(const ValueKey('student-stats-topic-mode-two-columns')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('student-stats-topic-col-left')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('student-stats-topic-col-right')),
            findsOneWidget,
          );
          expect(find.text('1. Argomento 1'), findsOneWidget);
          expect(find.text('8. Argomento 8'), findsOneWidget);
          expect(find.text('14. Argomento 14'), findsOneWidget);
          expect(_hasHorizontalScrollInTopicSection(tester), isFalse);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('two columns 10 topics D1 → 5+5', (tester) async {
      await _pumpSection(
        tester,
        size: const Size(1440, 900),
        topics: _topics(10),
      );
      expect(find.text('5. Argomento 5'), findsOneWidget);
      expect(find.text('6. Argomento 6'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('student-stats-topic-col-right')),
        findsOneWidget,
      );
    });

    testWidgets('1 topic → left only, no empty right column', (tester) async {
      await _pumpSection(
        tester,
        size: const Size(1440, 900),
        topics: [_topic()],
      );
      expect(
        find.byKey(const ValueKey('student-stats-topic-col-left')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('student-stats-topic-col-right')),
        findsNothing,
      );
    });

    testWidgets('empty filter state once', (tester) async {
      await _pumpSection(
        tester,
        size: const Size(1440, 900),
        topics: const [],
      );
      expect(
        find.byKey(const ValueKey('student-stats-topic-empty')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('student-stats-topic-mode-two-columns')),
        findsNothing,
      );
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
                ..._topics(5).skip(1),
              ],
            );
            expect(tester.takeException(), isNull);
            expect(_hasHorizontalScrollInTopicSection(tester), isFalse);
          },
        );
      }
    }
  });
}
