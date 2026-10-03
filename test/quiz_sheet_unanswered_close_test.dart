import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/quiz_sheet_exit_policy.dart';
import 'package:scuola_nautica_liana/models/lesson_quiz_sheet_content.dart';
import 'package:scuola_nautica_liana/models/lesson_sheet_completion_snapshot.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';
import 'package:scuola_nautica_liana/models/quiz_question.dart';
import 'package:scuola_nautica_liana/pages/quiz_sheet_detail_page.dart';
import 'package:scuola_nautica_liana/repositories/quiz_attempt_repository.dart';
import 'package:scuola_nautica_liana/repositories/student_quiz_repository.dart';
import 'package:scuola_nautica_liana/repositories/study_access_repository.dart';

QuizQuestion _q(int n) => QuizQuestion(
  id: 'q$n',
  prompt: 'Domanda $n del test unanswered',
  optionA: 'Opzione A della domanda $n',
  optionB: 'Opzione B della domanda $n',
  optionC: 'Opzione C della domanda $n',
  correctOption: QuizAnswerOption.a,
  lessonNumber: 1,
  licenseCategory: 'A12',
);

class _FakeStudentQuizRepo implements StudentQuizRepository {
  _FakeStudentQuizRepo(this.content);

  final LessonQuizSheetContent content;

  @override
  Future<LessonQuizSheetContent?> fetchLessonSheetContent({
    required LicenseCategoryId categoryId,
    required int lessonNumber,
    required int sheetNumber,
  }) async => content;

  @override
  Future<List<QuizQuestion>> fetchLessonSheetQuestions({
    required LicenseCategoryId categoryId,
    required int lessonNumber,
    required int sheetNumber,
    int? limit,
  }) async => content.questions;

  @override
  Future<LessonSheetCompletionSnapshot> fetchLessonSheetCompletion({
    required LicenseCategoryId categoryId,
    required int lessonNumber,
  }) async => LessonSheetCompletionSnapshot.empty;

  @override
  Future<Map<String, List<QuizQuestion>>> fetchExamQuestionsByTopic({
    required LicenseCategoryId categoryId,
  }) async => {};

  @override
  Future<Map<int, List<QuizQuestion>>> fetchQuestionsForLessons({
    required LicenseCategoryId categoryId,
    required List<int> lessonNumbers,
  }) async => {};

  @override
  Future<Map<int, List<int>>> fetchLessonSheetNumbersByLesson({
    required LicenseCategoryId categoryId,
  }) async => {};
}

class _RecordingAttemptRepo implements QuizAttemptRepository {
  _RecordingAttemptRepo({this.delay, bool failOnce = false})
    : _failBudget = failOnce ? 1 : 0;

  final Duration? delay;
  int submitCount = 0;
  int _failBudget;

  @override
  Future<QuizAttemptSubmitResult> submitLessonSheetAttempt({
    required String quizSetId,
    required List<QuizQuestion> questions,
    required List<QuizAnswerOption?> answers,
    required DateTime startedAt,
    required DateTime completedAt,
    String? existingQuizResultId,
  }) async {
    submitCount++;
    if (delay != null) {
      await Future<void>.delayed(delay!);
    }
    if (_failBudget > 0) {
      _failBudget--;
      throw StateError('save failed for test');
    }
    return QuizAttemptSubmitResult(quizResultId: 'result-$submitCount');
  }
}

Future<_RecordingAttemptRepo> _pumpSheet(
  WidgetTester tester, {
  required int questionCount,
  QuizAttemptRepository? attemptRepo,
  Duration? saveDelay,
  bool failOnce = false,
}) async {
  final recording = attemptRepo is _RecordingAttemptRepo
      ? attemptRepo
      : _RecordingAttemptRepo(delay: saveDelay, failOnce: failOnce);
  final repo = attemptRepo ?? recording;
  final questions = List.generate(questionCount, (i) => _q(i + 1));
  // Viewport alto: barra "Chiudi scheda" deve restare hit-testabile.
  const viewport = Size(1100, 1400);

  studyAccessWritableRepository.applyLessonQuizSheetUnlock(
    categoryId: LicenseCategoryId.motore,
    lessonNumber: 1,
    sheetNumber: 1,
    unlocked: true,
  );

  await tester.binding.setSurfaceSize(viewport);
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
    studyAccessWritableRepository.resetDemoAssignments();
  });

  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(size: viewport),
      child: MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              appBar: AppBar(title: const Text('Hub test')),
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => QuizSheetDetailPage(
                          lessonNumber: 1,
                          sheetNumber: 1,
                          categoryId: LicenseCategoryId.motore,
                          studentQuizRepositoryOverride: _FakeStudentQuizRepo(
                            LessonQuizSheetContent(
                              quizSetId: 'set-test',
                              categoryId: LicenseCategoryId.motore,
                              lessonNumber: 1,
                              sheetNumber: 1,
                              questions: questions,
                            ),
                          ),
                          quizAttemptRepositoryOverride: repo,
                        ),
                      ),
                    );
                  },
                  child: const Text('Apri scheda'),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Apri scheda'));
  await tester.pumpAndSettle();
  return recording;
}

Future<void> _goToLastQuestion(WidgetTester tester, int questionCount) async {
  for (var i = 0; i < questionCount - 1; i++) {
    await tester.ensureVisible(find.text('Avanti'));
    await tester.tap(find.text('Avanti'));
    await tester.pumpAndSettle();
  }
  expect(find.text('Chiudi scheda'), findsOneWidget);
}

Future<void> _answerCurrentA(WidgetTester tester, int questionNumber) async {
  final option = find.text('Opzione A della domanda $questionNumber');
  await tester.ensureVisible(option);
  await tester.tap(option);
  await tester.pumpAndSettle();
}

Future<void> _tapChiudiScheda(WidgetTester tester) async {
  final chiudi = find.widgetWithText(FilledButton, 'Chiudi scheda');
  expect(chiudi, findsOneWidget);
  await tester.tap(chiudi);
  await tester.pump();
}

Future<void> _requestExit(WidgetTester tester) async {
  // Leading AppBar back (route stack: Hub → Scheda).
  await tester.tap(find.byTooltip('Back'));
  await tester.pumpAndSettle();
}

void main() {
  group('quizSheetCloseMayProceed / quizSheetSaveMayProceed', () {
    test('blocks when summary, close, saving or saved', () {
      expect(
        quizSheetCloseMayProceed(
          showSummary: false,
          closeInProgress: false,
          isSaving: false,
          isSaved: false,
        ),
        isTrue,
      );
      expect(
        quizSheetCloseMayProceed(
          showSummary: true,
          closeInProgress: false,
          isSaving: false,
          isSaved: false,
        ),
        isFalse,
      );
      expect(
        quizSheetCloseMayProceed(
          showSummary: false,
          closeInProgress: true,
          isSaving: false,
          isSaved: false,
        ),
        isFalse,
      );
      expect(
        quizSheetCloseMayProceed(
          showSummary: false,
          closeInProgress: false,
          isSaving: true,
          isSaved: false,
        ),
        isFalse,
      );
      expect(
        quizSheetCloseMayProceed(
          showSummary: false,
          closeInProgress: false,
          isSaving: false,
          isSaved: true,
        ),
        isFalse,
      );
    });

    test('save may proceed only when idle/failed (not saving/saved)', () {
      expect(quizSheetSaveMayProceed(isSaving: false, isSaved: false), isTrue);
      expect(quizSheetSaveMayProceed(isSaving: true, isSaved: false), isFalse);
      expect(quizSheetSaveMayProceed(isSaving: false, isSaved: true), isFalse);
    });
  });

  group('STUDIO.QUIZ.UNANSWERED.1 — Schede normali close/save', () {
    testWidgets(
      '1. 0 risposte + Chiudi scheda → dialog 2 azioni, Torna, 0 save',
      (tester) async {
        final repo = await _pumpSheet(tester, questionCount: 3);
        await _goToLastQuestion(tester, 3);

        await _tapChiudiScheda(tester);
        await tester.pumpAndSettle();

        expect(find.text('Scheda non compilata'), findsOneWidget);
        expect(find.text('Torna alla scheda'), findsOneWidget);
        expect(find.text('Esci dalla scheda'), findsOneWidget);
        await tester.tap(find.text('Torna alla scheda'));
        await tester.pumpAndSettle();

        expect(repo.submitCount, 0);
        expect(find.text('Riepilogo scheda'), findsNothing);
        expect(find.text('Scheda non compilata'), findsNothing);
        expect(find.text('Domanda 3 del test unanswered'), findsOneWidget);
      },
    );

    testWidgets('1b. 0 risposte + Esci dalla scheda → pop → 0 save', (
      tester,
    ) async {
      final repo = await _pumpSheet(tester, questionCount: 3);
      await _goToLastQuestion(tester, 3);

      await _tapChiudiScheda(tester);
      await tester.pumpAndSettle();
      expect(find.text('Scheda non compilata'), findsOneWidget);

      await tester.tap(find.text('Esci dalla scheda'));
      await tester.pumpAndSettle();

      expect(repo.submitCount, 0);
      expect(find.text('Hub test'), findsOneWidget);
      expect(find.text('Domanda 3 del test unanswered'), findsNothing);
      expect(find.text('Riepilogo scheda'), findsNothing);
    });

    testWidgets('2. 0 risposte + Esci → pop → 0 save', (tester) async {
      final repo = await _pumpSheet(tester, questionCount: 3);

      expect(find.text('Domanda 1 del test unanswered'), findsOneWidget);
      await _requestExit(tester);

      expect(find.text('Hub test'), findsOneWidget);
      expect(find.text('Domanda 1 del test unanswered'), findsNothing);
      expect(repo.submitCount, 0);
    });

    testWidgets('3. partial + Esci → confirmation', (tester) async {
      final repo = await _pumpSheet(tester, questionCount: 3);
      await _answerCurrentA(tester, 1);

      await _requestExit(tester);

      expect(find.text('Concludere la scheda?'), findsOneWidget);
      expect(repo.submitCount, 0);
    });

    testWidgets('4. partial + confirmation CANCEL → 0 save', (tester) async {
      final repo = await _pumpSheet(tester, questionCount: 3);
      await _answerCurrentA(tester, 1);
      await _goToLastQuestion(tester, 3);

      await _tapChiudiScheda(tester);
      await tester.pumpAndSettle();
      expect(find.text('Concludere la scheda?'), findsOneWidget);

      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();

      expect(repo.submitCount, 0);
      expect(find.text('Riepilogo scheda'), findsNothing);
      // Cancel salta alla prima non risposta (Q2), non al summary.
      expect(find.textContaining('Domanda 2'), findsWidgets);
      expect(find.text('Hub test'), findsNothing);
    });

    testWidgets('5. partial + confirmation CONCLUDE → exactly 1 save', (
      tester,
    ) async {
      final repo = await _pumpSheet(tester, questionCount: 3);
      await _answerCurrentA(tester, 1);
      await _goToLastQuestion(tester, 3);

      await _tapChiudiScheda(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Concludi'));
      await tester.pumpAndSettle();

      expect(repo.submitCount, 1);
      expect(find.text('Riepilogo scheda'), findsOneWidget);
    });

    testWidgets('6. double tap Chiudi scheda → exactly 1 save', (tester) async {
      final repo = await _pumpSheet(
        tester,
        questionCount: 3,
        saveDelay: const Duration(milliseconds: 200),
      );
      await _answerCurrentA(tester, 1);
      await _goToLastQuestion(tester, 3);

      final chiudi = find.widgetWithText(FilledButton, 'Chiudi scheda');
      await tester.tap(chiudi);
      await tester.tap(chiudi, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('Concludere la scheda?'), findsOneWidget);
      await tester.tap(find.text('Concludi'));
      await tester.pumpAndSettle();

      expect(repo.submitCount, 1);
    });

    testWidgets('7. Esci + Chiudi scheda quasi simultanei → 1 attempt', (
      tester,
    ) async {
      final repo = await _pumpSheet(
        tester,
        questionCount: 3,
        saveDelay: const Duration(milliseconds: 150),
      );
      await _answerCurrentA(tester, 1);
      await _goToLastQuestion(tester, 3);

      final chiudi = find.widgetWithText(FilledButton, 'Chiudi scheda');
      await tester.tap(find.byTooltip('Back'));
      await tester.tap(chiudi, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('Concludere la scheda?'), findsOneWidget);
      await tester.tap(find.text('Concludi'));
      await tester.pumpAndSettle();

      expect(repo.submitCount, 1);
    });

    testWidgets('8. durante saving → secondo save impossibile', (tester) async {
      final gate = Completer<void>();
      final slowRepo = _GatedAttemptRepo(gate: gate);

      await _pumpSheet(tester, questionCount: 2, attemptRepo: slowRepo);
      await _answerCurrentA(tester, 1);
      await tester.ensureVisible(find.text('Avanti'));
      await tester.tap(find.text('Avanti'));
      await tester.pumpAndSettle();
      await _answerCurrentA(tester, 2);

      await _tapChiudiScheda(tester);
      await tester.pump(); // summary + saving, gate still open

      expect(find.text('Riepilogo scheda'), findsOneWidget);
      expect(find.text('Riprova salvataggio'), findsNothing);
      expect(slowRepo.submitCount, 1);
      expect(quizSheetSaveMayProceed(isSaving: true, isSaved: false), isFalse);

      gate.complete();
      await tester.pumpAndSettle();

      expect(slowRepo.submitCount, 1);
    });

    testWidgets('9. errore save → guard rilasciato → retry possibile', (
      tester,
    ) async {
      final repo = await _pumpSheet(tester, questionCount: 2, failOnce: true);
      await _answerCurrentA(tester, 1);
      await tester.ensureVisible(find.text('Avanti'));
      await tester.tap(find.text('Avanti'));
      await tester.pumpAndSettle();
      await _answerCurrentA(tester, 2);

      await _tapChiudiScheda(tester);
      await tester.pumpAndSettle();

      expect(repo.submitCount, 1);
      expect(find.text('Riprova salvataggio'), findsOneWidget);

      await tester.ensureVisible(find.text('Riprova salvataggio'));
      await tester.tap(find.text('Riprova salvataggio'));
      await tester.pumpAndSettle();

      expect(repo.submitCount, 2);
    });
  });
}

/// Attempt repo che resta in attesa su [gate] durante la persistenza.
class _GatedAttemptRepo implements QuizAttemptRepository {
  _GatedAttemptRepo({required this.gate});

  final Completer<void> gate;
  int submitCount = 0;

  @override
  Future<QuizAttemptSubmitResult> submitLessonSheetAttempt({
    required String quizSetId,
    required List<QuizQuestion> questions,
    required List<QuizAnswerOption?> answers,
    required DateTime startedAt,
    required DateTime completedAt,
    String? existingQuizResultId,
  }) async {
    submitCount++;
    await gate.future;
    return QuizAttemptSubmitResult(quizResultId: 'gated-$submitCount');
  }
}
