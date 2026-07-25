import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/exam_quiz_attempt_exception.dart';
import 'package:scuola_nautica_liana/domain/exam_quiz_attempt_models.dart';
import 'package:scuola_nautica_liana/domain/exam_quiz_attempt_result.dart';
import 'package:scuola_nautica_liana/domain/exam_quiz_attempt_submission.dart';
import 'package:scuola_nautica_liana/domain/exam_quiz_rules.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';
import 'package:scuola_nautica_liana/models/quiz_question.dart';
import 'package:scuola_nautica_liana/pages/quiz_exam_attempt_detail_page.dart';
import 'package:scuola_nautica_liana/pages/quiz_exam_page.dart';
import 'package:scuola_nautica_liana/pages/quiz_exam_player_page.dart';
import 'package:scuola_nautica_liana/repositories/exam_quiz_attempt_repository.dart';
import 'package:scuola_nautica_liana/repositories/study_access_repository.dart';
import 'package:scuola_nautica_liana/widgets/exam_quiz_attempt_card.dart';
import 'package:scuola_nautica_liana/widgets/nautical_answer_marker.dart';

ExamQuizAttemptSummary _summary({
  String id = 'att-1',
  LicenseCategoryId category = LicenseCategoryId.motore,
  DateTime? completedAt,
  int correct = 16,
  int wrong = 3,
  int unanswered = 1,
  bool passed = true,
  bool timeExpired = false,
  Duration duration = const Duration(minutes: 12),
}) {
  return ExamQuizAttemptSummary(
    id: id,
    licenseCategory: category,
    completedAt: completedAt ?? DateTime.utc(2026, 7, 24, 10),
    duration: duration,
    timeExpired: timeExpired,
    totalQuestions: 20,
    correctCount: correct,
    wrongCount: wrong,
    unansweredCount: unanswered,
    outcome: passed ? ExamQuizOutcome.passed : ExamQuizOutcome.failed,
  );
}

List<ExamQuizAttemptAnswerSnapshot> _twentySnapshots({
  int wrongAt = 2,
  int unansweredAt = 3,
  String? imageAtPath,
}) {
  return List.generate(20, (i) {
    final pos = i + 1;
    QuizAnswerOption? selected;
    if (pos == wrongAt) {
      selected = QuizAnswerOption.a;
    } else if (pos == unansweredAt) {
      selected = null;
    } else {
      selected = QuizAnswerOption.b;
    }
    final correct = QuizAnswerOption.b;
    return ExamQuizAttemptAnswerSnapshot(
      position: pos,
      questionId: '00000000-0000-4000-8000-${pos.toString().padLeft(12, '0')}',
      prompt: 'Domanda $pos',
      optionA: 'Risposta A$pos',
      optionB: 'Risposta B$pos',
      optionC: 'Risposta C$pos',
      selectedOption: selected,
      correctOption: correct,
      isCorrect: selected != null && selected == correct,
      imagePath: pos == 1 ? imageAtPath : null,
    );
  });
}

ExamQuizAttemptResult _detail({
  String id = 'att-detail-1',
  bool passed = true,
  bool timeExpired = false,
}) {
  final snapshots = _twentySnapshots();
  final wrong = snapshots.where((s) => !s.isCorrect && !s.isUnanswered).length;
  final unanswered = snapshots.where((s) => s.isUnanswered).length;
  final correct = snapshots.length - wrong - unanswered;
  return ExamQuizAttemptResult(
    id: id,
    licenseCategory: LicenseCategoryId.motore,
    completedAt: DateTime.utc(2026, 7, 24, 11),
    duration: const Duration(minutes: 14),
    timeExpired: timeExpired,
    totalQuestions: 20,
    correctCount: correct,
    wrongCount: wrong,
    unansweredCount: unanswered,
    outcome: passed ? ExamQuizOutcome.passed : ExamQuizOutcome.failed,
    answers: snapshots,
  );
}

class _PendingListFake implements ExamQuizAttemptRepository {
  _PendingListFake();

  final _completer = Completer<List<ExamQuizAttemptSummary>>();
  int listCalls = 0;

  void complete(List<ExamQuizAttemptSummary> value) {
    if (!_completer.isCompleted) _completer.complete(value);
  }

  @override
  Future<ExamQuizAttemptSubmitResult> submitAttempt(
    ExamQuizAttemptSubmission submission,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<List<ExamQuizAttemptSummary>> fetchCurrentUserAttempts({
    required LicenseCategoryId category,
  }) async {
    listCalls += 1;
    return _completer.future;
  }

  @override
  Future<ExamQuizAttemptResult> fetchAttemptDetail(String attemptId) async {
    throw UnimplementedError();
  }
}

class _PendingDetailFake implements ExamQuizAttemptRepository {
  _PendingDetailFake();

  final _completer = Completer<ExamQuizAttemptResult>();
  int detailCalls = 0;

  void complete(ExamQuizAttemptResult value) {
    if (!_completer.isCompleted) _completer.complete(value);
  }

  @override
  Future<ExamQuizAttemptSubmitResult> submitAttempt(
    ExamQuizAttemptSubmission submission,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<List<ExamQuizAttemptSummary>> fetchCurrentUserAttempts({
    required LicenseCategoryId category,
  }) async => const [];

  @override
  Future<ExamQuizAttemptResult> fetchAttemptDetail(String attemptId) async {
    detailCalls += 1;
    return _completer.future;
  }
}

Future<void> _pumpExamLanding(
  WidgetTester tester, {
  ExamQuizAttemptRepository? repository,
  LicenseCategoryId categoryId = LicenseCategoryId.motore,
}) async {
  studyAccessWritableRepository.applyExamQuizUnlock(
    categoryId: categoryId,
    unlocked: true,
  );
  await tester.pumpWidget(
    MaterialApp(
      home: QuizExamPage(categoryId: categoryId, repository: repository),
    ),
  );
  await tester.pump();
}

Future<void> _pumpDetail(
  WidgetTester tester, {
  required ExamQuizAttemptRepository repository,
  String attemptId = 'att-detail-1',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: QuizExamAttemptDetailPage(
        attemptId: attemptId,
        categoryId: LicenseCategoryId.motore,
        repository: repository,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('exam attempt completed pop result', () {
    test('codifica e decodifica attemptId', () {
      const id = 'att-abc-123';
      final pop = examAttemptCompletedPopResult(id);
      expect(isExamAttemptCompletedPopResult(pop), isTrue);
      expect(attemptIdFromExamCompletedPopResult(pop), id);
      expect(isExamAttemptCompletedPopResult(null), isFalse);
    });
  });

  group('QuizExamPage storico tentativi', () {
    testWidgets('mostra loading iniziale poi lista vuota', (tester) async {
      final pending = _PendingListFake();
      await _pumpExamLanding(tester, repository: pending);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      pending.complete(const []);
      await tester.pumpAndSettle();
      expect(pending.listCalls, 1);
      expect(
        find.text(
          'Non hai ancora completato simulazioni esame in questa categoria.',
        ),
        findsOneWidget,
      );
      expect(find.text('Avvia simulazione'), findsOneWidget);
    });

    testWidgets('errore storico con Riprova', (tester) async {
      final repo = ExamQuizAttemptRepositoryFake(
        throwOnList: ExamQuizAttemptException(
          code: ExamQuizAttemptErrorCode.repositoryUnavailable,
          message: examQuizAttemptErrorMessageIt(
            ExamQuizAttemptErrorCode.repositoryUnavailable,
          ),
        ),
      );
      await _pumpExamLanding(tester, repository: repo);
      await tester.pumpAndSettle();
      expect(find.textContaining('non disponibile'), findsOneWidget);
      repo.throwOnList = null;
      await tester.tap(find.text('Riprova'));
      await tester.pumpAndSettle();
      expect(repo.listCalls, 2);
    });

    testWidgets('filtra per categoria corrente', (tester) async {
      final repo = ExamQuizAttemptRepositoryFake(
        summaries: [
          _summary(id: 'motore-1', category: LicenseCategoryId.motore),
          _summary(
            id: 'd1-1',
            category: LicenseCategoryId.d1,
            completedAt: DateTime.utc(2026, 7, 25),
          ),
        ],
      );
      await _pumpExamLanding(
        tester,
        repository: repo,
        categoryId: LicenseCategoryId.motore,
      );
      await tester.pumpAndSettle();
      expect(repo.lastListCategory, LicenseCategoryId.motore);
      expect(find.text('Svolto'), findsOneWidget);
    });

    testWidgets('ordine più recente per primo', (tester) async {
      final repo = ExamQuizAttemptRepositoryFake(
        summaries: [
          _summary(id: 'older', completedAt: DateTime.utc(2026, 7, 20, 9)),
          _summary(id: 'newer', completedAt: DateTime.utc(2026, 7, 24, 15)),
        ],
      );
      await _pumpExamLanding(tester, repository: repo);
      await tester.pumpAndSettle();
      final cards = tester.widgetList<ExamQuizAttemptCard>(
        find.byType(ExamQuizAttemptCard),
      );
      expect(cards.length, 2);
      expect(cards.first.attempt.id, 'newer');
    });

    testWidgets('card mostra Svolto, superato e timer scaduto', (tester) async {
      final repo = ExamQuizAttemptRepositoryFake(
        summaries: [
          _summary(
            id: 'passed',
            passed: true,
            timeExpired: true,
            correct: 18,
            wrong: 1,
            unanswered: 1,
          ),
        ],
      );
      await _pumpExamLanding(tester, repository: repo);
      await tester.pumpAndSettle();
      expect(find.text('Svolto'), findsOneWidget);
      expect(find.text('Superato'), findsOneWidget);
      expect(find.textContaining('Timer scaduto'), findsOneWidget);
      expect(find.textContaining('Corrette 18'), findsOneWidget);
      expect(find.textContaining('Non risposte 1'), findsOneWidget);
    });

    testWidgets('card mostra esito non superato', (tester) async {
      final repo = ExamQuizAttemptRepositoryFake(
        summaries: [
          _summary(
            id: 'failed',
            passed: false,
            correct: 10,
            wrong: 8,
            unanswered: 2,
          ),
        ],
      );
      await _pumpExamLanding(tester, repository: repo);
      await tester.pumpAndSettle();
      expect(find.text('Non superato'), findsOneWidget);
    });

    testWidgets('Avvia simulazione resta disponibile con storico', (
      tester,
    ) async {
      final repo = ExamQuizAttemptRepositoryFake(
        summaries: [
          _summary(),
          _summary(id: 'att-2'),
        ],
      );
      await _pumpExamLanding(tester, repository: repo);
      await tester.pumpAndSettle();
      expect(find.text('Avvia simulazione'), findsOneWidget);
      expect(find.text('Svolto'), findsNWidgets(2));
    });

    testWidgets('pull-to-refresh ricarica storico', (tester) async {
      final repo = ExamQuizAttemptRepositoryFake(summaries: [_summary()]);
      await _pumpExamLanding(tester, repository: repo);
      await tester.pumpAndSettle();
      expect(find.text('Svolto'), findsOneWidget);
      repo.summaries = [_summary(), _summary(id: 'att-new')];
      await tester.drag(find.byType(ListView), const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(repo.listCalls, greaterThanOrEqualTo(2));
      expect(find.text('Svolto'), findsNWidgets(2));
    });
  });

  group('QuizExamAttemptDetailPage', () {
    testWidgets('loading poi dettaglio completo con 20 snapshot', (
      tester,
    ) async {
      final pending = _PendingDetailFake();
      await _pumpDetail(tester, repository: pending, attemptId: 'att-detail-1');
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      pending.complete(_detail());
      await tester.pumpAndSettle();
      expect(pending.detailCalls, 1);
      expect(find.text('Esame superato'), findsOneWidget);
      expect(find.text('Domande (20)'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Risposta A20'), 200);
      await tester.pumpAndSettle();
      expect(find.textContaining('Risposta A20'), findsOneWidget);
    });

    testWidgets('not found mostra messaggio', (tester) async {
      final repo = ExamQuizAttemptRepositoryFake();
      await _pumpDetail(tester, repository: repo, attemptId: 'missing');
      await tester.pumpAndSettle();
      expect(find.textContaining('non trovato'), findsOneWidget);
    });

    testWidgets('errore repository con Riprova', (tester) async {
      final repo = ExamQuizAttemptRepositoryFake(
        throwOnDetail: ExamQuizAttemptException(
          code: ExamQuizAttemptErrorCode.repositoryUnavailable,
          message: 'Repo down',
        ),
      );
      await _pumpDetail(tester, repository: repo);
      await tester.pumpAndSettle();
      expect(find.text('Repo down'), findsOneWidget);
      repo.throwOnDetail = null;
      repo.details = {'att-detail-1': _detail()};
      await tester.tap(find.text('Riprova'));
      await tester.pumpAndSettle();
      expect(repo.detailCalls, 2);
      expect(find.text('Esame superato'), findsOneWidget);
    });

    testWidgets('snapshot mostra corretta, errata e non risposta', (
      tester,
    ) async {
      final repo = ExamQuizAttemptRepositoryFake(
        details: {'att-detail-1': _detail(passed: false)},
      );
      await _pumpDetail(tester, repository: repo);
      await tester.pumpAndSettle();
      expect(find.text('Esame non superato'), findsOneWidget);
      expect(find.text('Risposte errate'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Risposta A2'), 200);
      await tester.pumpAndSettle();
      expect(find.byType(NauticalAnswerMarker), findsWidgets);
    });

    testWidgets('read-only: nessun submit né timer attivo', (tester) async {
      final repo = ExamQuizAttemptRepositoryFake(
        details: {'att-detail-1': _detail()},
      );
      await _pumpDetail(tester, repository: repo);
      await tester.pumpAndSettle();
      expect(find.text('Salvataggio risultato…'), findsNothing);
      expect(find.text('Vedi riepilogo'), findsNothing);
      expect(repo.submitCalls, 0);
    });

    testWidgets('timer scaduto nel riepilogo persistito', (tester) async {
      final repo = ExamQuizAttemptRepositoryFake(
        details: {'att-detail-1': _detail(timeExpired: true)},
      );
      await _pumpDetail(tester, repository: repo);
      await tester.pumpAndSettle();
      expect(
        find.text('Simulazione chiusa per scadenza del timer.'),
        findsOneWidget,
      );
    });
  });

  group('QuizExamPage apertura dettaglio', () {
    testWidgets('tap card apre dettaglio con attemptId corretto', (
      tester,
    ) async {
      final detail = _detail(id: 'att-open-1');
      final repo = ExamQuizAttemptRepositoryFake(
        summaries: [_summary(id: 'att-open-1')],
        details: {'att-open-1': detail},
      );
      await _pumpExamLanding(tester, repository: repo);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ExamQuizAttemptCard));
      await tester.pumpAndSettle();
      expect(repo.detailCalls, 1);
      expect(repo.lastDetailId, 'att-open-1');
      expect(find.text('Risultato simulazione'), findsOneWidget);
    });

    testWidgets('ritorno da dettaglio ricarica storico', (tester) async {
      final repo = ExamQuizAttemptRepositoryFake(
        summaries: [_summary(id: 'att-open-1')],
        details: {'att-open-1': _detail(id: 'att-open-1')},
      );
      await _pumpExamLanding(tester, repository: repo);
      await tester.pumpAndSettle();
      final initialCalls = repo.listCalls;
      await tester.tap(find.byType(ExamQuizAttemptCard));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(repo.listCalls, greaterThan(initialCalls));
    });
  });

  group('QuizExamPlayerPage completamento verso landing', () {
    testWidgets('summary back pop restituisce attemptId completato', (
      tester,
    ) async {
      const attemptId = 'att-completed-back';
      final repo = ExamQuizAttemptRepositoryFake(
        submitResult: ExamQuizAttemptSubmitResult(
          idempotent: false,
          attempt: _summary(id: attemptId),
        ),
      );
      final questions = List.generate(
        20,
        (i) => QuizQuestion(
          id: 'q$i',
          prompt: 'Domanda $i',
          optionA: 'A$i',
          optionB: 'B$i',
          optionC: 'C$i',
          correctOption: QuizAnswerOption.b,
          lessonNumber: 1,
          licenseCategory: 'A12',
        ),
      );
      String? popResult;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                popResult = await Navigator.of(context).push<String?>(
                  MaterialPageRoute<String?>(
                    builder: (_) => QuizExamPlayerPage(
                      categoryId: LicenseCategoryId.motore,
                      questions: questions,
                      clientAttemptToken: 'token-back',
                      repository: repo,
                    ),
                  ),
                );
              },
              child: const Text('Apri'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Apri'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 19; i++) {
        await tester.tap(find.byTooltip('Domanda successiva'));
        await tester.pumpAndSettle();
      }
      await tester.tap(
        find.descendant(
          of: find.byType(QuizExamPlayerPage),
          matching: find.widgetWithText(FilledButton, 'Termina esame'),
        ),
      );
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
      expect(find.text('Riepilogo esame'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(isExamAttemptCompletedPopResult(popResult), isTrue);
      expect(attemptIdFromExamCompletedPopResult(popResult), attemptId);
    });
  });
}
