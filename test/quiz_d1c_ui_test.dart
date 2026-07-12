import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/exam_error_review.dart';
import 'package:scuola_nautica_liana/domain/quiz_sheet_player_navigation.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';
import 'package:scuola_nautica_liana/models/quiz_question.dart';
import 'package:scuola_nautica_liana/pages/quiz_exam_error_review_page.dart';
import 'package:scuola_nautica_liana/pages/quiz_exam_player_page.dart';
import 'package:scuola_nautica_liana/widgets/nautical_answer_marker.dart';
import 'package:scuola_nautica_liana/widgets/quiz_question_progress_strip.dart';
import 'package:scuola_nautica_liana/widgets/quiz_question_prompt_panel.dart';

QuizQuestion _question(int n) => QuizQuestion(
  id: 'q$n',
  prompt: 'Domanda $n',
  optionA: 'Risposta A$n',
  optionB: 'Risposta B$n',
  optionC: 'Risposta C$n',
  correctOption: QuizAnswerOption.b,
  lessonNumber: 1,
  licenseCategory: 'A12',
);

Future<void> _pumpExamPlayer(
  WidgetTester tester, {
  int questionCount = 2,
}) async {
  final questions = List.generate(questionCount, _question);
  await tester.pumpWidget(
    MaterialApp(
      home: QuizExamPlayerPage(
        categoryId: LicenseCategoryId.motore,
        questions: questions,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('QuizSheetPlayerNavigation D1C', () {
    test(
      'examPrimaryButtonLabel mostra Vedi riepilogo sull’ultima domanda',
      () {
        expect(
          QuizSheetPlayerNavigation.examPrimaryButtonLabel(
            currentIndex: 19,
            questionCount: 20,
          ),
          'Vedi riepilogo',
        );
      },
    );

    test('isQuestionAnswered distingue risposte e gap', () {
      final answers = <QuizAnswerOption?>[QuizAnswerOption.a, null];
      expect(QuizSheetPlayerNavigation.isQuestionAnswered(answers, 0), isTrue);
      expect(QuizSheetPlayerNavigation.isQuestionAnswered(answers, 1), isFalse);
    });
  });

  group('QuizQuestionPromptPanel layout figura', () {
    testWidgets('contiene la figura in box ad altezza fissa', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: const Scaffold(
              body: QuizQuestionPromptPanel(
                questionNumber: 1,
                prompt: 'Testo domanda con figura',
                imagePath: 'figures/sample.png',
              ),
            ),
          ),
        ),
      );

      final expectedHeight = QuizQuestionPromptPanel.stackedImageBoxHeight(
        tester.element(find.byType(QuizQuestionPromptPanel)),
      );
      final imageBoxes = tester
          .widgetList<SizedBox>(
            find.descendant(
              of: find.byType(QuizQuestionPromptPanel),
              matching: find.byType(SizedBox),
            ),
          )
          .where((box) => box.height == expectedHeight && box.width != null)
          .toList();

      expect(imageBoxes, isNotEmpty);
      expect(imageBoxes.first.width, double.infinity);
    });
  });

  group('QuizExamPlayerPage D1C', () {
    testWidgets('mostra strip a quadratini nel player esame', (tester) async {
      await _pumpExamPlayer(tester, questionCount: 20);

      expect(find.byType(QuizQuestionProgressStrip), findsOneWidget);
      expect(find.byType(AspectRatio), findsNWidgets(20));
    });

    testWidgets('freccia destra disabilitata sull’ultima domanda', (
      tester,
    ) async {
      await _pumpExamPlayer(tester, questionCount: 2);

      await tester.tap(find.byIcon(Icons.chevron_right_rounded));
      await tester.pumpAndSettle();

      final forwardButtons = tester
          .widgetList<IconButton>(find.byType(IconButton))
          .where((button) => button.tooltip == 'Domanda successiva');
      expect(forwardButtons, hasLength(1));
      expect(forwardButtons.first.onPressed, isNull);
      expect(find.text('Vedi riepilogo'), findsOneWidget);
      expect(find.text('Riepilogo esame'), findsNothing);
    });

    testWidgets('ultimo pulsante apre dialog se mancano risposte', (
      tester,
    ) async {
      await _pumpExamPlayer(tester, questionCount: 2);

      await tester.tap(find.byTooltip('Domanda successiva'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vedi riepilogo'));
      await tester.pumpAndSettle();

      expect(find.text('Domande non completate'), findsOneWidget);
      expect(find.text('Ricontrolla'), findsOneWidget);
      expect(find.text('Vedi riepilogo'), findsWidgets);
    });

    testWidgets('Ricontrolla nel dialog non chiude la simulazione', (
      tester,
    ) async {
      await _pumpExamPlayer(tester, questionCount: 2);

      await tester.tap(find.byTooltip('Domanda successiva'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vedi riepilogo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ricontrolla'));
      await tester.pumpAndSettle();

      expect(find.text('Simulazione esame'), findsOneWidget);
      expect(find.text('Domande non completate'), findsNothing);
      expect(find.text('Riepilogo esame'), findsNothing);
    });

    testWidgets('Vedi riepilogo nel dialog apre il riepilogo finale', (
      tester,
    ) async {
      await _pumpExamPlayer(tester, questionCount: 2);

      await tester.tap(find.byTooltip('Domanda successiva'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vedi riepilogo'));
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.text('Vedi riepilogo'),
            )
            .last,
      );
      await tester.pumpAndSettle();

      expect(find.text('Riepilogo esame'), findsOneWidget);
    });

    testWidgets('selezionare risposta evidenzia solo il marker in esame', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(900, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpExamPlayer(tester, questionCount: 1);

      await tester.ensureVisible(find.text('Risposta A0'));
      await tester.tap(find.text('Risposta A0'));
      await tester.pumpAndSettle();

      final markers = tester.widgetList<NauticalAnswerMarker>(
        find.byType(NauticalAnswerMarker),
      );
      expect(markers.length, 3);
      expect(
        markers.where((m) => m.state == NauticalAnswerMarkerState.selected),
        hasLength(1),
      );
      expect(
        markers
            .singleWhere((m) => m.state == NauticalAnswerMarkerState.selected)
            .answerNumber,
        1,
      );
      expect(
        markers.where(
          (m) =>
              m.state == NauticalAnswerMarkerState.correct ||
              m.state == NauticalAnswerMarkerState.wrong,
        ),
        isEmpty,
      );
    });
  });

  group('QuizExamErrorReviewPage marker', () {
    testWidgets('review mostra marker 1 2 3 sulle opzioni', (tester) async {
      final entry = ExamErrorReviewEntry(
        questionNumber: 1,
        question: _question(0),
        userAnswer: QuizAnswerOption.a,
      );

      await tester.pumpWidget(
        MaterialApp(home: QuizExamErrorReviewPage(entries: [entry])),
      );

      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      final markers = tester.widgetList<NauticalAnswerMarker>(
        find.byType(NauticalAnswerMarker),
      );
      expect(
        markers.singleWhere((m) => m.answerNumber == 2).state,
        NauticalAnswerMarkerState.correct,
      );
      expect(
        markers.singleWhere((m) => m.answerNumber == 1).state,
        NauticalAnswerMarkerState.wrong,
      );
    });
  });

  group('Lesson marker feedback pattern', () {
    testWidgets('prima del reveal solo il marker selezionato è evidenziato', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: const [
                NauticalAnswerMarker(
                  answerNumber: 1,
                  state: NauticalAnswerMarkerState.selected,
                ),
                NauticalAnswerMarker(answerNumber: 2),
                NauticalAnswerMarker(answerNumber: 3),
              ],
            ),
          ),
        ),
      );

      final markers = tester.widgetList<NauticalAnswerMarker>(
        find.byType(NauticalAnswerMarker),
      );
      expect(
        markers.singleWhere((m) => m.answerNumber == 1).state,
        NauticalAnswerMarkerState.selected,
      );
      expect(
        markers.where((m) => m.state == NauticalAnswerMarkerState.neutral),
        hasLength(2),
      );
    });

    testWidgets('dopo reveal marker e stati corretto/errato restano visibili', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: const [
                NauticalAnswerMarker(
                  answerNumber: 1,
                  state: NauticalAnswerMarkerState.wrong,
                ),
                NauticalAnswerMarker(
                  answerNumber: 2,
                  state: NauticalAnswerMarkerState.correct,
                ),
                NauticalAnswerMarker(answerNumber: 3),
              ],
            ),
          ),
        ),
      );

      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });
  });
}
