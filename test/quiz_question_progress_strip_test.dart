import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/theme/app_visual_tokens.dart';
import 'package:scuola_nautica_liana/widgets/quiz_question_progress_strip.dart';

void main() {
  group('QuizQuestionProgressStrip', () {
    testWidgets('mostra un quadratino per ogni domanda', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              child: QuizQuestionProgressStrip(
                currentIndex: 0,
                total: 20,
                isAnswered: (_) => false,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(QuizQuestionProgressStrip), findsOneWidget);
      expect(find.text('1/20'), findsOneWidget);
      final cells = tester.widgetList<DecoratedBox>(
        find.descendant(
          of: find.byType(QuizQuestionProgressStrip),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect(cells.length, 20);
    });

    testWidgets('15 e 20 indicatori restano su una sola riga desktop', (
      tester,
    ) async {
      Future<void> pumpTotal(int total) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(size: Size(1366, 768)),
              child: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 900,
                    child: QuizQuestionProgressStrip(
                      currentIndex: 0,
                      total: total,
                      isAnswered: (_) => false,
                      compact: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
      }

      await pumpTotal(15);
      expect(find.text('1/15'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await pumpTotal(20);
      expect(find.text('1/20'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final cellFinder = find.descendant(
        of: find.byType(QuizQuestionProgressStrip),
        matching: find.byType(DecoratedBox),
      );
      expect(cellFinder, findsNWidgets(20));
      final firstTop = tester.getTopLeft(cellFinder.at(0)).dy;
      for (var i = 0; i < 20; i++) {
        expect(tester.getTopLeft(cellFinder.at(i)).dy, closeTo(firstTop, 0.5));
      }
      expect(tester.getSize(cellFinder.at(0)).height, lessThanOrEqualTo(16.5));
    });

    testWidgets('viewport 360: 15 e 20 celle positive senza overflow', (
      tester,
    ) async {
      Future<void> pumpTotal(int total) async {
        await tester.binding.setSurfaceSize(const Size(360, 800));
        addTearDown(() async {
          await tester.binding.setSurfaceSize(null);
        });
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(size: Size(360, 800)),
              child: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: QuizQuestionProgressStrip(
                    currentIndex: 0,
                    total: total,
                    isAnswered: (_) => false,
                    compact: true,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
      }

      await pumpTotal(15);
      expect(find.text('1/15'), findsOneWidget);
      final cells15 = find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'quiz-progress-cell-',
            ),
      );
      expect(cells15, findsNWidgets(15));
      for (var i = 0; i < 15; i++) {
        final size = tester.getSize(cells15.at(i));
        expect(size.width, greaterThan(0));
        expect(size.height, greaterThan(0));
      }
      expect(tester.takeException(), isNull);

      await pumpTotal(20);
      expect(find.text('1/20'), findsOneWidget);
      final cells20 = find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'quiz-progress-cell-',
            ),
      );
      expect(cells20, findsNWidgets(20));
      for (var i = 0; i < 20; i++) {
        final size = tester.getSize(cells20.at(i));
        expect(size.width, greaterThan(0));
        expect(size.height, greaterThan(0));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('quadratino risposto usa blu e non risposto beige', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: QuizQuestionProgressStrip(
                currentIndex: 1,
                total: 3,
                isAnswered: (index) => index == 0,
              ),
            ),
          ),
        ),
      );

      final cells = tester.widgetList<DecoratedBox>(
        find.descendant(
          of: find.byType(QuizQuestionProgressStrip),
          matching: find.byType(DecoratedBox),
        ),
      );

      expect(cells.length, 3);
      final first = cells.elementAt(0).decoration as BoxDecoration;
      final second = cells.elementAt(1).decoration as BoxDecoration;
      expect(first.color, AppVisual.logoBlue);
      expect(second.color, const Color(0xFFF3E8D8));
    });

    testWidgets('domanda corrente ha bordo evidenziato', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: QuizQuestionProgressStrip(
                currentIndex: 2,
                total: 5,
                isAnswered: (index) => index == 2,
              ),
            ),
          ),
        ),
      );

      final cells = tester.widgetList<DecoratedBox>(
        find.descendant(
          of: find.byType(QuizQuestionProgressStrip),
          matching: find.byType(DecoratedBox),
        ),
      );

      final current = cells.elementAt(2).decoration as BoxDecoration;
      final other = cells.elementAt(0).decoration as BoxDecoration;
      final currentBorder = current.border as Border;
      final otherBorder = other.border as Border;

      expect(currentBorder.top.width, greaterThan(0));
      expect(otherBorder.top.width, 0);
      expect(current.color, AppVisual.logoBlue);
    });
  });
}
