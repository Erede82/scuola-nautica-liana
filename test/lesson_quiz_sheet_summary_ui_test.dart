import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';
import 'package:scuola_nautica_liana/widgets/lesson_quiz_sheet_summary_body.dart';

Future<void> _pumpSummary(
  WidgetTester tester, {
  required LicenseCategoryId categoryId,
  required int total,
  required int correct,
  required int wrong,
  required int unanswered,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: LessonQuizSheetSummaryBody(
            categoryId: categoryId,
            totalQuestions: total,
            correctCount: correct,
            wrongCount: wrong,
            unansweredCount: unanswered,
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('LessonQuizSheetSummaryBody D1', () {
    testWidgets('caso reale bocciato 4+14 stile 1+11', (tester) async {
      await _pumpSummary(
        tester,
        categoryId: LicenseCategoryId.d1,
        total: 15,
        correct: 3,
        wrong: 1,
        unanswered: 11,
      );

      expect(find.text('Risposte errate'), findsOneWidget);
      expect(find.text('Percentuale'), findsNothing);
      expect(find.text('BOCCIATO'), findsOneWidget);
      expect(find.textContaining('12 errori conteggiati'), findsOneWidget);
      expect(find.textContaining('massimo 3'), findsOneWidget);
    });

    testWidgets('promosso con 3 errori', (tester) async {
      await _pumpSummary(
        tester,
        categoryId: LicenseCategoryId.d1,
        total: 15,
        correct: 12,
        wrong: 3,
        unanswered: 0,
      );

      expect(find.text('PROMOSSO'), findsOneWidget);
      expect(find.text('3 errori conteggiati · massimo 3'), findsOneWidget);
      expect(find.text('Percentuale'), findsNothing);
    });

    testWidgets('bocciato per non risposta (3+1)', (tester) async {
      await _pumpSummary(
        tester,
        categoryId: LicenseCategoryId.d1,
        total: 15,
        correct: 11,
        wrong: 3,
        unanswered: 1,
      );

      expect(find.text('BOCCIATO'), findsOneWidget);
      expect(find.text('4 errori conteggiati · massimo 3'), findsOneWidget);
    });
  });

  group('LessonQuizSheetSummaryBody A12', () {
    testWidgets('promosso con 4 errori', (tester) async {
      await _pumpSummary(
        tester,
        categoryId: LicenseCategoryId.motore,
        total: 20,
        correct: 16,
        wrong: 4,
        unanswered: 0,
      );

      expect(find.text('PROMOSSO'), findsOneWidget);
      expect(find.text('4 errori conteggiati · massimo 4'), findsOneWidget);
    });

    testWidgets('bocciato con 5 errori', (tester) async {
      await _pumpSummary(
        tester,
        categoryId: LicenseCategoryId.motore,
        total: 20,
        correct: 15,
        wrong: 5,
        unanswered: 0,
      );

      expect(find.text('BOCCIATO'), findsOneWidget);
      expect(find.text('5 errori conteggiati · massimo 4'), findsOneWidget);
    });

    testWidgets('non risposte non contano nella soglia', (tester) async {
      await _pumpSummary(
        tester,
        categoryId: LicenseCategoryId.motore,
        total: 20,
        correct: 2,
        wrong: 4,
        unanswered: 14,
      );

      expect(find.text('PROMOSSO'), findsOneWidget);
      expect(find.text('4 errori conteggiati · massimo 4'), findsOneWidget);
      expect(find.text('Percentuale'), findsNothing);
    });
  });
}
