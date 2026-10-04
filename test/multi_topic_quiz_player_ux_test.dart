import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/multi_topic_quiz_attempt_result.dart';
import 'package:scuola_nautica_liana/domain/multi_topic_quiz_session.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';
import 'package:scuola_nautica_liana/models/quiz_question.dart';
import 'package:scuola_nautica_liana/pages/multi_topic_quiz_player_page.dart';
import 'package:scuola_nautica_liana/repositories/multi_topic_quiz_attempt_repository.dart';
import 'package:scuola_nautica_liana/theme/quiz_player_visual_tokens.dart';
import 'package:scuola_nautica_liana/widgets/lesson_style_quiz_player_shell.dart';
import 'package:scuola_nautica_liana/widgets/quiz_lesson_sheet_progress_panel.dart';
import 'package:scuola_nautica_liana/widgets/quiz_question_progress_strip.dart';

QuizQuestion _q(int n, {required int lesson, String? imagePath}) =>
    QuizQuestion(
      id: 'mt-q$n-l$lesson',
      prompt: 'Domanda Multischeda $n lezione $lesson',
      optionA: 'Opzione A della domanda $n',
      optionB: 'Opzione B della domanda $n',
      optionC: 'Opzione C della domanda $n',
      correctOption: QuizAnswerOption.a,
      lessonNumber: lesson,
      licenseCategory: 'A12',
      imagePath: imagePath,
    );

MultiTopicQuizSession _session({
  required int totalSheets,
  bool withImage = false,
}) {
  final lesson1 = List.generate(
    30,
    (i) => _q(
      i + 1,
      lesson: 1,
      imagePath: withImage && i == 0
          ? 'assets/images/welcome/welcome_boat.jpg'
          : null,
    ),
  );
  final lesson2 = List.generate(30, (i) => _q(i + 31, lesson: 2));
  return MultiTopicQuizSession(
    sessionId: 'session-ui',
    licenseCategory: LicenseCategoryId.motore,
    selectedLessonNumbers: const [1, 2],
    totalSheets: totalSheets,
    poolByLesson: {1: lesson1, 2: lesson2},
  );
}

Future<MultiTopicQuizAttemptRepositoryFake> _pumpPlayer(
  WidgetTester tester, {
  required Size viewport,
  int totalSheets = 13,
  bool withImage = false,
}) async {
  final repo = MultiTopicQuizAttemptRepositoryFake(
    submitResult: MultiTopicQuizAttemptResult(
      attemptId: 'att-1',
      sessionId: 'session-ui',
      sheetIndex: 1,
      totalSheets: totalSheets,
      licenseCategory: LicenseCategoryId.motore,
      lessonNumbers: const [1, 2],
      completedAt: DateTime.utc(2026, 10, 2),
      durationSeconds: 10,
      totalQuestions: 20,
      correctCount: 0,
      wrongCount: 0,
      unansweredCount: 20,
      idempotent: false,
    ),
  );
  await tester.binding.setSurfaceSize(viewport);
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: viewport),
      child: MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              appBar: AppBar(title: const Text('Hub multi')),
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => MultiTopicQuizPlayerPage(
                          session: _session(
                            totalSheets: totalSheets,
                            withImage: withImage,
                          ),
                          attemptRepositoryOverride: repo,
                        ),
                      ),
                    );
                  },
                  child: const Text('Apri multi'),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Apri multi'));
  await tester.pumpAndSettle();
  return repo;
}

double? _lessonShellWidth(WidgetTester tester) {
  final boxes = tester.widgetList<ConstrainedBox>(find.byType(ConstrainedBox));
  for (final box in boxes) {
    if (box.constraints.maxWidth ==
        QuizPlayerVisual.lessonSheetContentMaxWidth) {
      final elements = find
          .byWidgetPredicate((w) => identical(w, box))
          .evaluate();
      if (elements.isEmpty) continue;
      final render = elements.first.renderObject as RenderBox?;
      return render?.size.width;
    }
  }
  return null;
}

Future<void> _goToLastQuestion(WidgetTester tester) async {
  for (var i = 0; i < 19; i++) {
    await tester.ensureVisible(find.text('Avanti'));
    await tester.tap(find.text('Avanti'));
    await tester.pumpAndSettle();
  }
  expect(find.text('Chiudi scheda'), findsOneWidget);
}

ConstrainedBox? _lessonSheetWidthBox(WidgetTester tester) {
  final boxes = tester.widgetList<ConstrainedBox>(find.byType(ConstrainedBox));
  for (final box in boxes) {
    if (box.constraints.maxWidth ==
        QuizPlayerVisual.lessonSheetContentMaxWidth) {
      return box;
    }
  }
  return null;
}

void main() {
  group('STUDIO.SCHEDE.UX.2 — Multischeda empty / layout', () {
    testWidgets('0 risposte: dialog 2 azioni; Torna resta; 0 save', (
      tester,
    ) async {
      final repo = await _pumpPlayer(tester, viewport: const Size(1100, 1400));
      await _goToLastQuestion(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Chiudi scheda'));
      await tester.pumpAndSettle();

      expect(find.text('Scheda non compilata'), findsOneWidget);
      expect(find.text('Torna alla scheda'), findsOneWidget);
      expect(find.text('Esci dalla scheda'), findsOneWidget);

      await tester.tap(find.text('Torna alla scheda'));
      await tester.pumpAndSettle();

      expect(repo.submitCalls, isEmpty);
      expect(find.text('Scheda non compilata'), findsNothing);
      expect(find.text('Scheda 1 di 13'), findsWidgets);
      expect(find.text('Hub multi'), findsNothing);
    });

    testWidgets('0 risposte: Esci dalla scheda → pop senza save', (
      tester,
    ) async {
      final repo = await _pumpPlayer(tester, viewport: const Size(1100, 1400));
      await _goToLastQuestion(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Chiudi scheda'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Esci dalla scheda'));
      await tester.pumpAndSettle();

      expect(repo.submitCalls, isEmpty);
      expect(find.text('Hub multi'), findsOneWidget);
      expect(find.text('Scheda 1 di 13'), findsNothing);
    });

    testWidgets('UI allineata alle Schede: progress panel + layout ampio', (
      tester,
    ) async {
      await _pumpPlayer(tester, viewport: const Size(1440, 900));

      expect(find.byType(LessonStyleQuizPlayerShell), findsOneWidget);
      expect(find.byType(QuizLessonSheetProgressPanel), findsOneWidget);
      expect(find.byType(QuizQuestionProgressStrip), findsOneWidget);
      expect(find.text('Scheda 1 di 13'), findsWidgets);
      expect(find.textContaining('Corrette:'), findsOneWidget);
      expect(find.textContaining('Errori:'), findsOneWidget);
      expect(find.textContaining('Non risposte:'), findsOneWidget);
      expect(_lessonSheetWidthBox(tester), isNotNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('mobile 390 senza overflow', (tester) async {
      await _pumpPlayer(tester, viewport: const Size(390, 844));
      expect(find.byType(QuizLessonSheetProgressPanel), findsOneWidget);
      expect(find.text('Scheda 1 di 13'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('PROGRESS.3 width shell 1440 ≈ 1120; 390/768/1024 ok', (
      tester,
    ) async {
      await _pumpPlayer(tester, viewport: const Size(1440, 900));
      final width1440 = _lessonShellWidth(tester);
      expect(width1440, isNotNull);
      expect(width1440!, closeTo(1120, 1.0));
      expect(tester.takeException(), isNull);

      for (final size in const [
        Size(390, 844),
        Size(768, 1024),
        Size(1024, 768),
      ]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(size: size),
            child: MaterialApp(
              home: MultiTopicQuizPlayerPage(
                session: _session(totalSheets: 3),
                attemptRepositoryOverride: MultiTopicQuizAttemptRepositoryFake(
                  submitResult: MultiTopicQuizAttemptResult(
                    attemptId: 'att-w',
                    sessionId: 'session-ui',
                    sheetIndex: 1,
                    totalSheets: 3,
                    licenseCategory: LicenseCategoryId.motore,
                    lessonNumbers: const [1, 2],
                    completedAt: DateTime.utc(2026, 10, 2),
                    durationSeconds: 10,
                    totalQuestions: 20,
                    correctCount: 0,
                    wrongCount: 0,
                    unansweredCount: 20,
                    idempotent: false,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final w = _lessonShellWidth(tester);
        expect(w, isNotNull);
        expect(
          w!,
          closeTo(
            size.width < QuizPlayerVisual.lessonSheetContentMaxWidth
                ? size.width
                : QuizPlayerVisual.lessonSheetContentMaxWidth,
            1.0,
          ),
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('PROGRESS.3 wide shell with figure fixture', (tester) async {
      await _pumpPlayer(
        tester,
        viewport: const Size(1440, 900),
        withImage: true,
      );
      expect(_lessonShellWidth(tester), closeTo(1120, 1.0));
      expect(tester.takeException(), isNull);
    });
  });
}
