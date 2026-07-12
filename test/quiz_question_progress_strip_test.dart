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
            body: QuizQuestionProgressStrip(
              currentIndex: 0,
              total: 20,
              isAnswered: (_) => false,
            ),
          ),
        ),
      );

      expect(find.byType(QuizQuestionProgressStrip), findsOneWidget);
      expect(find.byType(AspectRatio), findsNWidgets(20));
      expect(find.text('1/20'), findsOneWidget);
    });

    testWidgets('quadratino risposto usa blu e non risposto beige', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuizQuestionProgressStrip(
              currentIndex: 1,
              total: 3,
              isAnswered: (index) => index == 0,
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
            body: QuizQuestionProgressStrip(
              currentIndex: 2,
              total: 5,
              isAnswered: (index) => index == 2,
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
