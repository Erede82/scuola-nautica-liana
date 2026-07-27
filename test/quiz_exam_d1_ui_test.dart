import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/exam_quiz_attempt_models.dart';
import 'package:scuola_nautica_liana/domain/exam_quiz_rules.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';
import 'package:scuola_nautica_liana/models/quiz_question.dart';
import 'package:scuola_nautica_liana/pages/quiz_exam_page.dart';
import 'package:scuola_nautica_liana/pages/quiz_exam_player_page.dart';
import 'package:scuola_nautica_liana/repositories/exam_quiz_attempt_repository.dart';
import 'package:scuola_nautica_liana/repositories/study_access_repository.dart';
import 'package:scuola_nautica_liana/widgets/quiz_question_progress_strip.dart';

QuizQuestion _question(int n) => QuizQuestion(
  id: 'd1-q$n',
  prompt: 'Domanda D1 $n',
  optionA: 'Risposta A$n',
  optionB: 'Risposta B$n',
  optionC: 'Risposta C$n',
  correctOption: QuizAnswerOption.b,
  lessonNumber: 1,
  licenseCategory: 'D1',
);

ExamQuizAttemptSubmitResult _d1SubmitResult({
  String id = 'att-d1',
  int totalQuestions = 15,
}) {
  return ExamQuizAttemptSubmitResult(
    idempotent: false,
    attempt: ExamQuizAttemptSummary(
      id: id,
      licenseCategory: LicenseCategoryId.d1,
      completedAt: DateTime.utc(2026, 7, 26),
      duration: const Duration(minutes: 10),
      timeExpired: false,
      totalQuestions: totalQuestions,
      correctCount: totalQuestions,
      wrongCount: 0,
      unansweredCount: 0,
      outcome: ExamQuizOutcome.passed,
    ),
  );
}

Future<void> _pumpD1Landing(
  WidgetTester tester, {
  ExamQuizAttemptRepository? repository,
  bool unlocked = true,
}) async {
  studyAccessWritableRepository.applyExamQuizUnlock(
    categoryId: LicenseCategoryId.d1,
    unlocked: unlocked,
  );
  await tester.pumpWidget(
    MaterialApp(
      home: QuizExamPage(
        categoryId: LicenseCategoryId.d1,
        repository: repository,
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpD1Player(
  WidgetTester tester, {
  ExamQuizAttemptRepository? repository,
}) async {
  final questions = List.generate(15, _question);
  final repo =
      repository ??
      ExamQuizAttemptRepositoryFake(submitResult: _d1SubmitResult());
  await tester.pumpWidget(
    MaterialApp(
      home: QuizExamPlayerPage(
        categoryId: LicenseCategoryId.d1,
        questions: questions,
        clientAttemptToken: 'd1-test-token',
        repository: repo,
      ),
    ),
  );
  await tester.pump();
}

Future<void> _tapPrimaryTerminaEsame(WidgetTester tester) async {
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
}

void main() {
  group('QuizExamPage D1 landing', () {
    testWidgets('non mostra più in preparazione', (tester) async {
      await _pumpD1Landing(tester, repository: ExamQuizAttemptRepositoryFake());
      await tester.pumpAndSettle();
      expect(find.textContaining('in preparazione'), findsNothing);
      expect(find.textContaining('selezione domande'), findsNothing);
    });

    testWidgets('mostra regole D1: 15 domande, 30 minuti, 3 errori', (
      tester,
    ) async {
      await _pumpD1Landing(tester, repository: ExamQuizAttemptRepositoryFake());
      await tester.pumpAndSettle();
      expect(find.textContaining('15 quesiti'), findsOneWidget);
      expect(find.textContaining('30 minuti'), findsOneWidget);
      expect(find.textContaining('massimo 3 errori'), findsOneWidget);
    });

    testWidgets('accesso non abilitato → CTA bloccata', (tester) async {
      await _pumpD1Landing(
        tester,
        repository: ExamQuizAttemptRepositoryFake(),
        unlocked: false,
      );
      await tester.pumpAndSettle();
      expect(find.text('Avvia simulazione'), findsNothing);
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
    });

    testWidgets('accesso abilitato → simulazione avviabile', (tester) async {
      await _pumpD1Landing(tester, repository: ExamQuizAttemptRepositoryFake());
      await tester.pumpAndSettle();
      expect(find.text('Avvia simulazione'), findsOneWidget);
    });
  });

  group('QuizExamPlayerPage D1', () {
    testWidgets('contiene 15 domande e strip progressivo 1/15', (tester) async {
      await _pumpD1Player(tester);
      expect(find.byType(QuizQuestionProgressStrip), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(QuizQuestionProgressStrip),
          matching: find.byType(DecoratedBox),
        ),
        findsNWidgets(15),
      );
      expect(find.text('1/15'), findsOneWidget);
    });

    testWidgets(
      'navigazione fino a 15/15, Termina esame e submit con 15 risposte D1',
      (tester) async {
        final repo = ExamQuizAttemptRepositoryFake(
          submitResult: _d1SubmitResult(id: 'att-d1-submit'),
        );
        await _pumpD1Player(tester, repository: repo);

        expect(find.text('1/15'), findsOneWidget);

        for (var i = 0; i < 14; i++) {
          await tester.tap(find.byTooltip('Domanda successiva'));
          await tester.pumpAndSettle();
        }

        expect(find.text('15/15'), findsOneWidget);
        expect(find.text('Termina esame'), findsOneWidget);

        await _tapPrimaryTerminaEsame(tester);

        expect(repo.submitCalls, 1);
        expect(repo.lastSubmission?.answers, hasLength(15));
        expect(repo.lastSubmission?.licenseCategory, LicenseCategoryId.d1);
        expect(repo.lastSubmission?.toRpcParams()['p_license_category'], 'D1');
        expect(repo.lastSubmission?.answers.map((a) => a.position).toList(), [
          for (var i = 1; i <= 15; i++) i,
        ]);
        expect(find.text('Riepilogo esame'), findsOneWidget);
        expect(find.text('Esame superato'), findsOneWidget);
      },
    );

    testWidgets('timer D1 scaduto → 15 answers, timeExpired=true', (
      tester,
    ) async {
      final rules = examQuizRulesForCategory(LicenseCategoryId.d1)!;
      expect(rules.durationSeconds, 1800);

      final repo = ExamQuizAttemptRepositoryFake(
        submitResult: _d1SubmitResult(id: 'att-d1-timeout'),
      );
      await _pumpD1Player(tester, repository: repo);

      await tester.pump(const Duration(minutes: 31));
      await tester.pumpAndSettle();

      expect(repo.submitCalls, 1);
      expect(repo.lastSubmission?.timeExpired, isTrue);
      expect(repo.lastSubmission?.answers, hasLength(15));
      expect(
        repo.lastSubmission?.answers.every((a) => a.position <= 15),
        isTrue,
      );
      expect(
        repo.lastSubmission?.answers.map((a) => a.position).toSet(),
        hasLength(15),
      );
      expect(find.text('Domande non completate'), findsNothing);
      expect(find.text('Riepilogo esame'), findsOneWidget);
    });
  });
}
