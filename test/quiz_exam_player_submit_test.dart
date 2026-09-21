import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/exam_quiz_attempt_exception.dart';
import 'package:scuola_nautica_liana/domain/exam_quiz_attempt_models.dart';
import 'package:scuola_nautica_liana/domain/exam_quiz_attempt_result.dart';
import 'package:scuola_nautica_liana/domain/exam_quiz_attempt_submission.dart';
import 'package:scuola_nautica_liana/domain/exam_quiz_client_token.dart';
import 'package:scuola_nautica_liana/domain/exam_quiz_rules.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';
import 'package:scuola_nautica_liana/models/quiz_question.dart';
import 'package:scuola_nautica_liana/pages/quiz_exam_player_page.dart';
import 'package:scuola_nautica_liana/repositories/exam_quiz_attempt_repository.dart';
import 'package:scuola_nautica_liana/widgets/nautical_answer_marker.dart';

QuizQuestion _question(int n) => QuizQuestion(
  id: '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}',
  prompt: 'Domanda $n',
  optionA: 'Risposta A$n',
  optionB: 'Risposta B$n',
  optionC: 'Risposta C$n',
  correctOption: QuizAnswerOption.b,
  lessonNumber: 1,
  licenseCategory: 'A12',
);

List<QuizQuestion> _questions([int count = 20]) =>
    List.generate(count, _question);

ExamQuizAttemptSubmitResult _submitResult({
  String id = 'att-server-1',
  int correct = 16,
  int wrong = 3,
  int unanswered = 1,
  bool idempotent = false,
}) {
  return ExamQuizAttemptSubmitResult(
    idempotent: idempotent,
    attempt: ExamQuizAttemptSummary(
      id: id,
      licenseCategory: LicenseCategoryId.motore,
      completedAt: DateTime.utc(2026, 7, 24, 10),
      duration: const Duration(minutes: 12),
      timeExpired: false,
      totalQuestions: 20,
      correctCount: correct,
      wrongCount: wrong,
      unansweredCount: unanswered,
      outcome: (wrong + unanswered) <= ExamQuizRules.maxErrorsToPass
          ? ExamQuizOutcome.passed
          : ExamQuizOutcome.failed,
    ),
  );
}

Future<ExamQuizAttemptRepositoryFake> _pumpPlayer(
  WidgetTester tester, {
  ExamQuizAttemptRepository? repository,
  String token = 'stable-token',
  int questionCount = 20,
}) async {
  final repo =
      repository ??
      ExamQuizAttemptRepositoryFake(submitResult: _submitResult());
  final player = QuizExamPlayerPage(
    categoryId: LicenseCategoryId.motore,
    questions: _questions(questionCount),
    clientAttemptToken: token,
    repository: repo,
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () {
              Navigator.of(
                context,
              ).push<void>(MaterialPageRoute<void>(builder: (_) => player));
            },
            child: const Text('Apri player'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Apri player'));
  await tester.pumpAndSettle();
  if (repo is ExamQuizAttemptRepositoryFake) return repo;
  return ExamQuizAttemptRepositoryFake();
}

Future<void> _goToLastQuestion(WidgetTester tester, int questionCount) async {
  for (var i = 0; i < questionCount - 1; i++) {
    await tester.tap(find.byTooltip('Domanda successiva'));
    await tester.pumpAndSettle();
  }
}

Future<void> _goToFirstQuestion(WidgetTester tester) async {
  for (var i = 0; i < 19; i++) {
    final back = find.ancestor(
      of: find.byIcon(Icons.chevron_left_rounded),
      matching: find.byType(IconButton),
    );
    if (back.evaluate().isEmpty) break;
    final button = tester.widget<IconButton>(back);
    if (button.onPressed == null) break;
    await tester.tap(back);
    await tester.pumpAndSettle();
  }
}

int? _selectedAnswerNumber(WidgetTester tester) {
  final selected = tester
      .widgetList<NauticalAnswerMarker>(find.byType(NauticalAnswerMarker))
      .where((m) => m.state == NauticalAnswerMarkerState.selected)
      .toList(growable: false);
  if (selected.length != 1) return null;
  return selected.single.answerNumber;
}

Finder _examPrimaryFinishButton() {
  return find.descendant(
    of: find.byType(QuizExamPlayerPage),
    matching: find.widgetWithText(FilledButton, 'Termina esame'),
  );
}

Future<void> _confirmSummaryDialog(WidgetTester tester) async {
  await tester.tap(_examPrimaryFinishButton());
  await tester.pumpAndSettle();
  if (find.byType(AlertDialog).evaluate().isNotEmpty) {
    await tester.tap(
      find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Termina esame'),
          )
          .last,
    );
    await tester.pumpAndSettle();
  }
}

class _SubmitRecordingFake extends ExamQuizAttemptRepositoryFake {
  _SubmitRecordingFake({super.throwOnSubmit});

  final submissions = <ExamQuizAttemptSubmission>[];

  @override
  Future<ExamQuizAttemptSubmitResult> submitAttempt(
    ExamQuizAttemptSubmission submission,
  ) async {
    submissions.add(submission);
    return super.submitAttempt(submission);
  }
}

class _PendingSubmitRepository implements ExamQuizAttemptRepository {
  Completer<ExamQuizAttemptSubmitResult>? _completer;

  void complete(ExamQuizAttemptSubmitResult result) {
    _completer?.complete(result);
  }

  @override
  Future<ExamQuizAttemptSubmitResult> submitAttempt(
    ExamQuizAttemptSubmission submission,
  ) {
    _completer = Completer<ExamQuizAttemptSubmitResult>();
    return _completer!.future;
  }

  @override
  Future<List<ExamQuizAttemptSummary>> fetchCurrentUserAttempts({
    required LicenseCategoryId category,
  }) async => const [];

  @override
  Future<ExamQuizAttemptResult> fetchAttemptDetail(String attemptId) async {
    throw UnimplementedError();
  }
}

void main() {
  group('generateExamClientAttemptToken', () {
    test('genera token distinti', () {
      final a = generateExamClientAttemptToken();
      final b = generateExamClientAttemptToken();
      expect(a, isNotEmpty);
      expect(b, isNotEmpty);
      expect(a, isNot(equals(b)));
    });
  });

  group('QuizExamPlayerPage exit policy', () {
    testWidgets('zero risposte → uscita immediata, zero submit', (
      tester,
    ) async {
      final repo = ExamQuizAttemptRepositoryFake(submitResult: _submitResult());
      await _pumpPlayer(tester, repository: repo, questionCount: 20);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(repo.submitCalls, 0);
      expect(find.text('Apri player'), findsOneWidget);
    });

    testWidgets('risposta parziale → dialog di conferma', (tester) async {
      final repo = ExamQuizAttemptRepositoryFake(submitResult: _submitResult());
      await _pumpPlayer(tester, repository: repo, questionCount: 20);
      await tester.tap(find.text('Risposta A0'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Uscire dalla simulazione?'), findsOneWidget);
      expect(repo.submitCalls, 0);
    });

    testWidgets('conferma uscita parziale → esce senza submit', (tester) async {
      final repo = ExamQuizAttemptRepositoryFake(submitResult: _submitResult());
      await _pumpPlayer(tester, repository: repo, questionCount: 20);
      await tester.tap(find.text('Risposta A0'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Esci senza salvare'));
      await tester.pumpAndSettle();
      expect(repo.submitCalls, 0);
      expect(find.text('Apri player'), findsOneWidget);
    });

    testWidgets('annulla uscita parziale → resta nel player', (tester) async {
      final repo = ExamQuizAttemptRepositoryFake(submitResult: _submitResult());
      await _pumpPlayer(tester, repository: repo, questionCount: 20);
      await tester.tap(find.text('Risposta A0'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resta nella simulazione'));
      await tester.pumpAndSettle();
      expect(find.text('Simulazione esame'), findsOneWidget);
      expect(repo.submitCalls, 0);
    });

    testWidgets('riepilogo mostrato → uscita libera', (tester) async {
      final repo = ExamQuizAttemptRepositoryFake(submitResult: _submitResult());
      await _pumpPlayer(tester, repository: repo, questionCount: 20);
      await _goToLastQuestion(tester, 20);
      await _confirmSummaryDialog(tester);
      expect(find.text('Riepilogo esame'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(repo.submitCalls, 1);
      expect(find.byType(QuizExamPlayerPage), findsNothing);
    });

    testWidgets('submit in corso → nessuna uscita accidentale', (tester) async {
      final pending = _PendingSubmitRepository();
      await _pumpPlayer(tester, repository: pending, questionCount: 20);
      await _goToLastQuestion(tester, 20);
      await tester.tap(_examPrimaryFinishButton());
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.text('Termina esame'),
            )
            .last,
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Salvataggio risultato…'), findsOneWidget);
      expect(find.text('Riepilogo esame'), findsNothing);
      pending.complete(_submitResult());
      await tester.pumpAndSettle();
      expect(find.text('Riepilogo esame'), findsOneWidget);
    });

    testWidgets(
      'submit fallito a zero risposte → back conferma, non perde subito',
      (tester) async {
        final repo = ExamQuizAttemptRepositoryFake(
          throwOnSubmit: ExamQuizAttemptException(
            code: ExamQuizAttemptErrorCode.repositoryUnavailable,
            message: examQuizAttemptErrorMessageIt(
              ExamQuizAttemptErrorCode.repositoryUnavailable,
            ),
          ),
        );
        await _pumpPlayer(tester, repository: repo, questionCount: 20);
        // Timer scaduto: conclude con 0 risposte e tenta il submit.
        await tester.pump(const Duration(minutes: 31));
        await tester.pumpAndSettle();
        expect(repo.submitCalls, 1);
        expect(find.textContaining('non disponibile'), findsOneWidget);
        expect(find.text('Riepilogo esame'), findsNothing);

        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.text('Uscire dalla simulazione?'), findsOneWidget);
        expect(
          find.textContaining('non verrà salvato nello storico'),
          findsOneWidget,
        );
        // Resta: il pending submission non deve sparire.
        await tester.tap(find.text('Resta nella simulazione'));
        await tester.pumpAndSettle();
        expect(find.textContaining('non disponibile'), findsOneWidget);
        expect(find.text('Riprova'), findsOneWidget);
      },
    );
  });

  group('QuizExamPlayerPage submit manuale', () {
    testWidgets('invoca repository con payload completo', (tester) async {
      const token = 'manual-token';
      final repo = ExamQuizAttemptRepositoryFake(submitResult: _submitResult());
      await _pumpPlayer(
        tester,
        repository: repo,
        token: token,
        questionCount: 20,
      );
      await tester.tap(find.text('Risposta A0'));
      await tester.pumpAndSettle();
      await _goToLastQuestion(tester, 20);
      await _confirmSummaryDialog(tester);

      expect(repo.submitCalls, 1);
      expect(repo.lastSubmission?.clientAttemptToken, token);
      expect(repo.lastSubmission?.timeExpired, isFalse);
      expect(repo.lastSubmission?.licenseCategory, LicenseCategoryId.motore);
      expect(repo.lastSubmission?.answers, hasLength(20));
      expect(
        repo.lastSubmission?.answers.where((a) => a.selectedOption != null),
        hasLength(1),
      );
      expect(find.text('Riepilogo esame'), findsOneWidget);
      expect(find.text('16'), findsWidgets);
    });

    testWidgets('idempotent=true trattato come successo', (tester) async {
      final repo = ExamQuizAttemptRepositoryFake(
        submitResult: _submitResult(idempotent: true, id: 'att-same'),
      );
      await _pumpPlayer(tester, repository: repo, questionCount: 20);
      await _goToLastQuestion(tester, 20);
      await _confirmSummaryDialog(tester);
      expect(find.text('Riepilogo esame'), findsOneWidget);
      expect(find.textContaining('Operazione non riuscita'), findsNothing);
    });
  });

  group('QuizExamPlayerPage dialog gap (P9E.6-A3)', () {
    testWidgets('mostra Indietro e Termina esame', (tester) async {
      final repo = ExamQuizAttemptRepositoryFake(submitResult: _submitResult());
      await _pumpPlayer(tester, repository: repo, questionCount: 20);
      await _goToLastQuestion(tester, 20);
      await tester.tap(_examPrimaryFinishButton());
      await tester.pumpAndSettle();
      expect(find.text('Indietro'), findsOneWidget);
      expect(find.text('Termina esame'), findsNWidgets(2));
      expect(find.text('Ricontrolla'), findsNothing);
      expect(find.text('Vedi riepilogo'), findsNothing);
      expect(repo.submitCalls, 0);
    });

    testWidgets('Indietro non chiama il repository', (tester) async {
      final repo = ExamQuizAttemptRepositoryFake(submitResult: _submitResult());
      await _pumpPlayer(tester, repository: repo, questionCount: 20);
      await _goToLastQuestion(tester, 20);
      await tester.tap(_examPrimaryFinishButton());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Indietro'));
      await tester.pumpAndSettle();
      expect(repo.submitCalls, 0);
      expect(find.text('Simulazione esame'), findsOneWidget);
    });

    testWidgets('Termina esame chiama il repository una volta', (tester) async {
      final repo = ExamQuizAttemptRepositoryFake(submitResult: _submitResult());
      await _pumpPlayer(tester, repository: repo, questionCount: 20);
      await _goToLastQuestion(tester, 20);
      await tester.tap(_examPrimaryFinishButton());
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.text('Termina esame'),
            )
            .last,
      );
      await tester.pumpAndSettle();
      expect(repo.submitCalls, 1);
      expect(find.text('Riepilogo esame'), findsOneWidget);
    });
  });

  group('QuizExamPlayerPage timer', () {
    testWidgets('scadenza timer → submit timeExpired=true senza dialog gap', (
      tester,
    ) async {
      final repo = ExamQuizAttemptRepositoryFake(submitResult: _submitResult());
      await _pumpPlayer(tester, repository: repo, questionCount: 20);
      await tester.pump(const Duration(minutes: 31));
      await tester.pumpAndSettle();
      expect(repo.submitCalls, 1);
      expect(repo.lastSubmission?.timeExpired, isTrue);
      expect(find.text('Domande non completate'), findsNothing);
      expect(find.text('Riepilogo esame'), findsOneWidget);
    });

    testWidgets('race timer durante dialog gap → un solo submit', (
      tester,
    ) async {
      final repo = ExamQuizAttemptRepositoryFake(submitResult: _submitResult());
      await _pumpPlayer(tester, repository: repo, questionCount: 20);
      await _goToLastQuestion(tester, 20);
      await tester.tap(_examPrimaryFinishButton());
      await tester.pump();
      expect(find.text('Domande non completate'), findsOneWidget);
      await tester.pump(const Duration(minutes: 31));
      await tester.pumpAndSettle();
      expect(repo.submitCalls, 1);
      if (find.byType(AlertDialog).evaluate().isNotEmpty) {
        await tester.tap(
          find
              .descendant(
                of: find.byType(AlertDialog),
                matching: find.text('Termina esame'),
              )
              .last,
        );
        await tester.pumpAndSettle();
      }
      expect(repo.submitCalls, 1);
      expect(find.text('Riepilogo esame'), findsOneWidget);
    });
  });

  group('QuizExamPlayerPage errori e retry', () {
    testWidgets('errore submit → nessun riepilogo, retry stesso token', (
      tester,
    ) async {
      const token = 'retry-token';
      final repo = ExamQuizAttemptRepositoryFake(
        throwOnSubmit: ExamQuizAttemptException(
          code: ExamQuizAttemptErrorCode.repositoryUnavailable,
          message: examQuizAttemptErrorMessageIt(
            ExamQuizAttemptErrorCode.repositoryUnavailable,
          ),
        ),
      );
      await _pumpPlayer(tester, repository: repo, token: token);
      await _goToLastQuestion(tester, 20);
      await _confirmSummaryDialog(tester);
      expect(find.text('Riepilogo esame'), findsNothing);
      expect(find.textContaining('non disponibile'), findsOneWidget);

      repo.throwOnSubmit = null;
      repo.submitResult = _submitResult();
      await tester.tap(find.text('Riprova'));
      await tester.pumpAndSettle();

      expect(repo.submitCalls, 2);
      expect(repo.lastSubmission?.clientAttemptToken, token);
      expect(find.text('Riepilogo esame'), findsOneWidget);
    });

    testWidgets('access denied mostra messaggio comprensibile', (tester) async {
      final repo = ExamQuizAttemptRepositoryFake(
        throwOnSubmit: ExamQuizAttemptException(
          code: ExamQuizAttemptErrorCode.examAccessDenied,
          message: examQuizAttemptErrorMessageIt(
            ExamQuizAttemptErrorCode.examAccessDenied,
          ),
        ),
      );
      await _pumpPlayer(tester, repository: repo);
      await _goToLastQuestion(tester, 20);
      await _confirmSummaryDialog(tester);
      expect(find.textContaining('Non hai accesso'), findsOneWidget);
    });

    testWidgets('idempotency conflict non crea nuovo tentativo', (
      tester,
    ) async {
      final repo = ExamQuizAttemptRepositoryFake(
        throwOnSubmit: ExamQuizAttemptException(
          code: ExamQuizAttemptErrorCode.idempotencyConflict,
          message: examQuizAttemptErrorMessageIt(
            ExamQuizAttemptErrorCode.idempotencyConflict,
          ),
        ),
      );
      await _pumpPlayer(tester, repository: repo, token: 'conflict-token');
      await _goToLastQuestion(tester, 20);
      await _confirmSummaryDialog(tester);
      expect(find.textContaining('token'), findsOneWidget);
      expect(find.text('Riepilogo esame'), findsNothing);
      expect(repo.submitCalls, 1);
    });
  });

  group('QuizExamPlayerPage nuova simulazione', () {
    testWidgets('token passato al player resta stabile per retry', (
      tester,
    ) async {
      const token = 'fixed-token';
      final repo = ExamQuizAttemptRepositoryFake(
        throwOnSubmit: ExamQuizAttemptException(
          code: ExamQuizAttemptErrorCode.unknown,
          message: 'Errore',
        ),
      );
      await _pumpPlayer(tester, repository: repo, token: token);
      await _goToLastQuestion(tester, 20);
      await _confirmSummaryDialog(tester);
      repo.throwOnSubmit = null;
      repo.submitResult = _submitResult(id: 'att-new');
      await tester.tap(find.text('Riprova'));
      await tester.pumpAndSettle();
      expect(repo.lastSubmission?.clientAttemptToken, token);
    });
  });

  group('QuizExamPlayerPage retry idempotente (P9E.5-A1)', () {
    testWidgets('retry con payload identico', (tester) async {
      const token = 'idempotent-retry-token';
      final repo = _SubmitRecordingFake(
        throwOnSubmit: ExamQuizAttemptException(
          code: ExamQuizAttemptErrorCode.repositoryUnavailable,
          message: examQuizAttemptErrorMessageIt(
            ExamQuizAttemptErrorCode.repositoryUnavailable,
          ),
        ),
      );
      await _pumpPlayer(tester, repository: repo, token: token);
      await _goToLastQuestion(tester, 20);
      await _confirmSummaryDialog(tester);
      expect(repo.submissions, hasLength(1));

      await tester.pump(const Duration(seconds: 5));

      repo.throwOnSubmit = null;
      repo.submitResult = _submitResult();
      await tester.tap(find.text('Riprova'));
      await tester.pumpAndSettle();

      expect(repo.submitCalls, 2);
      expect(repo.submissions, hasLength(2));
      expect(repo.submissions[1].clientAttemptToken, token);
      expect(repo.submissions[1].duration, repo.submissions[0].duration);
      expect(repo.submissions[1].timeExpired, repo.submissions[0].timeExpired);
      expect(repo.submissions[1].answers, repo.submissions[0].answers);
      expect(
        repo.submissions[1].toRpcParams(),
        repo.submissions[0].toRpcParams(),
      );
      expect(find.text('Riepilogo esame'), findsOneWidget);
    });

    testWidgets('durata non cambia dopo errore e avanzamento tempo', (
      tester,
    ) async {
      final repo = _SubmitRecordingFake(
        throwOnSubmit: ExamQuizAttemptException(
          code: ExamQuizAttemptErrorCode.unknown,
          message: 'Errore',
        ),
      );
      await _pumpPlayer(tester, repository: repo);
      await _goToLastQuestion(tester, 20);
      await _confirmSummaryDialog(tester);
      final firstDuration = repo.submissions.single.duration;

      await tester.pump(const Duration(seconds: 8));

      repo.throwOnSubmit = null;
      repo.submitResult = _submitResult();
      await tester.tap(find.text('Riprova'));
      await tester.pumpAndSettle();

      expect(repo.submitCalls, 2);
      expect(repo.submissions[1].duration, firstDuration);
      expect(
        repo.submissions[1].duration.inSeconds,
        repo.submissions[0].duration.inSeconds,
      );
    });

    testWidgets('risposta bloccata dopo errore e payload retry invariato', (
      tester,
    ) async {
      final repo = _SubmitRecordingFake(
        throwOnSubmit: ExamQuizAttemptException(
          code: ExamQuizAttemptErrorCode.unknown,
          message: 'Errore',
        ),
      );
      await _pumpPlayer(tester, repository: repo, questionCount: 20);
      await tester.tap(find.text('Risposta A0'));
      await tester.pumpAndSettle();
      await _goToLastQuestion(tester, 20);
      await _confirmSummaryDialog(tester);

      expect(
        repo.submissions.single.answers.first.selectedOption,
        QuizAnswerOption.a,
      );

      await _goToFirstQuestion(tester);
      expect(_selectedAnswerNumber(tester), 1);

      await tester.tap(find.text('Risposta C0'));
      await tester.pumpAndSettle();
      expect(_selectedAnswerNumber(tester), 1);

      repo.throwOnSubmit = null;
      repo.submitResult = _submitResult();
      await tester.tap(find.text('Riprova'));
      await tester.pumpAndSettle();

      expect(repo.submitCalls, 2);
      expect(
        repo.submissions[1].answers.first.selectedOption,
        QuizAnswerOption.a,
      );
      expect(
        repo.submissions[1].toRpcParams(),
        repo.submissions[0].toRpcParams(),
      );
    });

    testWidgets('timer scaduto e retry conserva timeExpired=true', (
      tester,
    ) async {
      final repo = _SubmitRecordingFake(
        throwOnSubmit: ExamQuizAttemptException(
          code: ExamQuizAttemptErrorCode.unknown,
          message: 'Errore',
        ),
      );
      await _pumpPlayer(tester, repository: repo);
      await tester.pump(const Duration(minutes: 31));
      await tester.pumpAndSettle();

      expect(repo.submissions, hasLength(1));
      expect(repo.submissions.single.timeExpired, isTrue);

      repo.throwOnSubmit = null;
      repo.submitResult = _submitResult();
      await tester.tap(find.text('Riprova'));
      await tester.pumpAndSettle();

      expect(repo.submitCalls, 2);
      expect(repo.submissions[0].timeExpired, isTrue);
      expect(repo.submissions[1].timeExpired, isTrue);
      expect(
        repo.submissions[1].toRpcParams(),
        repo.submissions[0].toRpcParams(),
      );
      expect(find.text('Riepilogo esame'), findsOneWidget);
    });

    testWidgets('submit manuale e retry conserva timeExpired=false', (
      tester,
    ) async {
      final repo = _SubmitRecordingFake(
        throwOnSubmit: ExamQuizAttemptException(
          code: ExamQuizAttemptErrorCode.unknown,
          message: 'Errore',
        ),
      );
      await _pumpPlayer(tester, repository: repo);
      await _goToLastQuestion(tester, 20);
      await _confirmSummaryDialog(tester);
      expect(repo.submissions.single.timeExpired, isFalse);
      final firstDuration = repo.submissions.single.duration;

      await tester.pump(const Duration(seconds: 6));

      repo.throwOnSubmit = null;
      repo.submitResult = _submitResult();
      await tester.tap(find.text('Riprova'));
      await tester.pumpAndSettle();

      expect(repo.submitCalls, 2);
      expect(repo.submissions[0].timeExpired, isFalse);
      expect(repo.submissions[1].timeExpired, isFalse);
      expect(repo.submissions[1].duration, firstDuration);
      expect(
        repo.submissions[1].toRpcParams(),
        repo.submissions[0].toRpcParams(),
      );
    });
  });

  group('QuizExamPlayerPage regressioni', () {
    testWidgets('review errori disponibile dopo submit', (tester) async {
      final repo = ExamQuizAttemptRepositoryFake(
        submitResult: _submitResult(correct: 0, wrong: 20, unanswered: 0),
      );
      await _pumpPlayer(tester, repository: repo, questionCount: 20);
      await tester.tap(find.text('Risposta A0'));
      await tester.pumpAndSettle();
      await _goToLastQuestion(tester, 20);
      await _confirmSummaryDialog(tester);
      expect(find.text('Rivedi errori'), findsOneWidget);
      await tester.tap(find.text('Rivedi errori'));
      await tester.pumpAndSettle();
      expect(find.text('Domanda 1'), findsWidgets);
      expect(repo.submitCalls, 1);
    });
  });
}
