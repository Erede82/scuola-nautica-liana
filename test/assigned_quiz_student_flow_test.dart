import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/course_taxonomy.dart';
import 'package:scuola_nautica_liana/models/assigned_quiz_models.dart';
import 'package:scuola_nautica_liana/pages/assigned_quiz_list_page.dart';
import 'package:scuola_nautica_liana/pages/assigned_quiz_player_page.dart';
import 'package:scuola_nautica_liana/pages/assigned_quiz_result_page.dart';
import 'package:scuola_nautica_liana/pages/assigned_quiz_review_page.dart';
import 'package:scuola_nautica_liana/pages/category_selection_page.dart';
import 'package:scuola_nautica_liana/pages/error_review_page.dart';
import 'package:scuola_nautica_liana/pages/quiz_dashboard_page.dart';
import 'package:scuola_nautica_liana/pages/quiz_statistics_review_hub_page.dart';
import 'package:scuola_nautica_liana/pages/statistics_page.dart';
import 'package:scuola_nautica_liana/repositories/assigned_quiz_repository.dart';
import 'package:scuola_nautica_liana/services/demo_student_enrollment.dart';
import 'package:scuola_nautica_liana/widgets/dashboard_action_card.dart';

AssignedQuizSummary _summary({
  required String id,
  String title = 'Quiz scuola',
  String? staffNote = 'NOTA INTERNA STAFF',
  DateTime? expiresAt,
  AssignedQuizRepeatPolicy repeat = AssignedQuizRepeatPolicy.unlimited,
  int? maxAttempts,
  int? submittedAttemptsCount,
  bool? hasInProgressAttempt,
  int? attemptsCount,
  double? bestScorePercentage,
}) {
  return AssignedQuizSummary(
    id: id,
    publicCode: 'AQZ-$id',
    studentId: 'st-1',
    studentUserId: 'user-1',
    licenseCategory: 'A12',
    title: title,
    staffNote: staffNote,
    status: AssignedQuizStatus.assigned,
    questionCount: 3,
    repeatPolicy: repeat,
    maxAttempts: maxAttempts,
    createdAt: DateTime.utc(2026, 7, 1),
    assignedAt: DateTime.utc(2026, 7, 2),
    expiresAt: expiresAt,
    submittedAttemptsCount: submittedAttemptsCount,
    hasInProgressAttempt: hasInProgressAttempt,
    attemptsCount: attemptsCount,
    bestScorePercentage: bestScorePercentage,
  );
}

List<AssignedQuizQuestion> _questions({int count = 3}) {
  return List.generate(count, (i) {
    return AssignedQuizQuestion(
      assignmentItemId: 'item-$i',
      position: i + 1,
      prompt: 'Domanda ${i + 1}?',
      optionA: 'Opzione A$i',
      optionB: 'Opzione B$i',
      optionC: 'Opzione C$i',
      lessonNumber: (i % 14) + 1,
      selectedOption: i == 0 ? 'A' : null,
    );
  });
}

void _surface(WidgetTester tester, {Size size = const Size(390, 844)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _list(AssignedQuizRepository repo) {
  return MaterialApp(home: AssignedQuizListPage(repository: repo));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AssignedQuizListPage', () {
    testWidgets('loading empty errore card scaduta e no nota staff', (
      tester,
    ) async {
      _surface(tester);
      final repo = AssignedQuizRepositoryFake(
        loadDelay: const Duration(milliseconds: 40),
        summaries: [
          _summary(
            id: '1',
            title: 'Assegnato vivo',
            hasInProgressAttempt: false,
          ),
          _summary(
            id: '2',
            title: 'Assegnato scaduto',
            expiresAt: DateTime.utc(2020, 1, 1),
          ),
          _summary(
            id: '3',
            title: 'Limitato',
            repeat: AssignedQuizRepeatPolicy.limited,
            maxAttempts: 2,
            submittedAttemptsCount: 2,
            hasInProgressAttempt: false,
          ),
        ],
      );
      await tester.pumpWidget(_list(repo));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();

      expect(find.text('Assegnato vivo'), findsOneWidget);
      expect(find.text('Scaduto'), findsWidgets);
      expect(find.text('Inizia quiz'), findsOneWidget);
      expect(find.textContaining('Tentativi illimitati'), findsWidgets);
      expect(find.textContaining('NOTA INTERNA'), findsNothing);
      expect(find.textContaining('Tentativi: 0'), findsNothing);

      await tester.scrollUntilVisible(find.text('Limitato'), 120);
      expect(find.text('Tentativi terminati'), findsOneWidget);
      expect(find.textContaining('Massimo 2 tentativi'), findsOneWidget);
    });

    testWidgets('empty state', (tester) async {
      _surface(tester);
      await tester.pumpWidget(_list(AssignedQuizRepositoryFake()));
      await tester.pumpAndSettle();
      expect(find.text('Nessun quiz assegnato'), findsOneWidget);
    });

    testWidgets('errore e retry', (tester) async {
      _surface(tester);
      final repo = AssignedQuizRepositoryFake(
        throwOnLoadMine: AssignedQuizException(
          code: AssignedQuizErrorCode.notAuthorized,
          message: assignedQuizErrorMessageIt(
            AssignedQuizErrorCode.notAuthorized,
          ),
        ),
      );
      await tester.pumpWidget(_list(repo));
      await tester.pumpAndSettle();
      expect(find.textContaining('Non hai i permessi'), findsOneWidget);
      repo.throwOnLoadMine = null;
      repo.summaries = [_summary(id: 'ok')];
      await tester.tap(find.text('Riprova'));
      await tester.pumpAndSettle();
      expect(find.text('Quiz scuola'), findsOneWidget);
    });

    testWidgets('start una sola volta e apre player', (tester) async {
      _surface(tester);
      final repo = AssignedQuizRepositoryFake(
        summaries: [_summary(id: 'a1', hasInProgressAttempt: false)],
        questions: _questions(),
        startResult: const AssignedQuizAttemptStartResult(
          attemptId: 'att-1',
          attemptNumber: 1,
          resumed: false,
          questionCount: 3,
          attemptsUsed: 1,
        ),
      );
      await tester.pumpWidget(_list(repo));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Inizia quiz'));
      await tester.tap(find.text('Inizia quiz'));
      await tester.tap(find.text('Inizia quiz'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(repo.startOrResumeCalls, 1);
      expect(find.byType(AssignedQuizPlayerPage), findsOneWidget);
      expect(find.textContaining('Domanda 1'), findsWidgets);
    });

    testWidgets('resumed mostra snackbar', (tester) async {
      _surface(tester);
      final repo = AssignedQuizRepositoryFake(
        summaries: [_summary(id: 'a1', hasInProgressAttempt: true)],
        questions: _questions(),
        startResult: const AssignedQuizAttemptStartResult(
          attemptId: 'att-1',
          attemptNumber: 2,
          resumed: true,
          questionCount: 3,
          attemptsUsed: 2,
        ),
      );
      await tester.pumpWidget(_list(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Riprendi quiz'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Riprendiamo il tentativo'), findsOneWidget);
    });

    testWidgets('lazy storico tentativi', (tester) async {
      _surface(tester);
      final repo = AssignedQuizRepositoryFake(
        summaries: [_summary(id: 'a1')],
        attempts: [
          AssignedQuizAttemptSummary(
            id: 'att-s',
            assignmentId: 'a1',
            attemptNumber: 1,
            status: AssignedQuizAttemptStatus.submitted,
            startedAt: DateTime.utc(2026, 7, 3),
            submittedAt: DateTime.utc(2026, 7, 3, 1),
            correctCount: 2,
            wrongCount: 1,
            unansweredCount: 0,
            scorePercentage: 67,
          ),
          AssignedQuizAttemptSummary(
            id: 'att-p',
            assignmentId: 'a1',
            attemptNumber: 2,
            status: AssignedQuizAttemptStatus.inProgress,
            startedAt: DateTime.utc(2026, 7, 4),
            correctCount: 0,
            wrongCount: 0,
            unansweredCount: 0,
          ),
          AssignedQuizAttemptSummary(
            id: 'att-x',
            assignmentId: 'a1',
            attemptNumber: 3,
            status: AssignedQuizAttemptStatus.abandoned,
            startedAt: DateTime.utc(2026, 7, 5),
            abandonedAt: DateTime.utc(2026, 7, 5, 1),
            correctCount: 0,
            wrongCount: 0,
            unansweredCount: 0,
          ),
        ],
      );
      await tester.pumpWidget(_list(repo));
      await tester.pumpAndSettle();
      expect(repo.loadAttemptsCalls, isEmpty);
      await tester.tap(find.text('Vedi tentativi'));
      await tester.pumpAndSettle();
      expect(repo.loadAttemptsCalls, ['a1']);
      expect(find.textContaining('Completato'), findsOneWidget);
      expect(find.textContaining('In corso'), findsOneWidget);
      expect(find.textContaining('Abbandonato'), findsOneWidget);
      expect(find.text('Rivedi'), findsOneWidget);
    });
  });

  group('AssignedQuizPlayerPage', () {
    AssignedQuizPlayerPage playerOf(AssignedQuizRepositoryFake repo) {
      return AssignedQuizPlayerPage(
        repository: repo,
        assignment: _summary(id: 'a1'),
        start: const AssignedQuizAttemptStartResult(
          attemptId: 'att-1',
          attemptNumber: 1,
          resumed: false,
          questionCount: 3,
          attemptsUsed: 1,
        ),
        questions: repo.questions,
      );
    }

    testWidgets('mapping 1/2/3, ripristino selectedOption, save e progress', (
      tester,
    ) async {
      _surface(tester);
      final repo = AssignedQuizRepositoryFake(questions: _questions());
      await tester.pumpWidget(MaterialApp(home: playerOf(repo)));
      await tester.pumpAndSettle();

      expect(find.text('1'), findsWidgets);
      expect(find.text('2'), findsWidgets);
      expect(find.text('3'), findsWidgets);
      expect(find.textContaining('Pronto'), findsOneWidget);

      await tester.tap(find.text('Opzione B0'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Salvat'), findsWidgets);
      expect(repo.saveCalls.length, 1);
      expect(repo.saveCalls.single['selectedOption'], 'B');

      await tester.tap(find.text('Successiva'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Domanda 2'), findsWidgets);
      await tester.tap(find.text('Opzione A1'));
      await tester.pumpAndSettle();
      expect(repo.saveCalls.length, 2);
    });

    testWidgets('cambio rapido risposta usa ultima selezione', (tester) async {
      _surface(tester);
      final repo = AssignedQuizRepositoryFake(
        questions: _questions(),
        saveDelay: const Duration(milliseconds: 80),
      );
      await tester.pumpWidget(MaterialApp(home: playerOf(repo)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Opzione A0'));
      await tester.tap(find.text('Opzione C0'));
      await tester.pumpAndSettle();
      expect(repo.saveCalls.last['selectedOption'], 'C');
    });

    testWidgets('save failure blocca submit', (tester) async {
      _surface(tester);
      final repo = AssignedQuizRepositoryFake(
        questions: _questions(count: 1),
        throwOnSave: AssignedQuizException(
          code: AssignedQuizErrorCode.invalidSelectedOption,
          message: assignedQuizErrorMessageIt(
            AssignedQuizErrorCode.invalidSelectedOption,
          ),
        ),
      );
      await tester.pumpWidget(MaterialApp(home: playerOf(repo)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Opzione B0'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Concludi quiz'));
      await tester.pumpAndSettle();
      expect(find.textContaining('sincronizzate'), findsOneWidget);
      expect(repo.submitCalls, 0);
    });

    testWidgets('submit solo attemptId e apre risultato', (tester) async {
      _surface(tester);
      final repo = AssignedQuizRepositoryFake(
        questions: _questions(count: 1),
        submitResult: AssignedQuizSubmitResult(
          attemptId: 'att-1',
          attemptNumber: 1,
          correctCount: 1,
          wrongCount: 0,
          unansweredCount: 0,
          scorePercentage: 100,
          submittedAt: DateTime.utc(2026, 7, 10, 12),
        ),
      );
      await tester.pumpWidget(MaterialApp(home: playerOf(repo)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Opzione A0'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Concludi quiz'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Consegna'));
      await tester.pumpAndSettle();
      expect(repo.submitCalls, 1);
      expect(repo.lastSubmitParams, {'p_attempt_id': 'att-1'});
      expect(find.byType(AssignedQuizResultPage), findsOneWidget);
      expect(find.textContaining('100%'), findsOneWidget);
    });

    testWidgets('back non abbandona; esci lascia in_progress', (tester) async {
      _surface(tester);
      final repo = AssignedQuizRepositoryFake(questions: _questions(count: 1));
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => playerOf(repo)),
                  );
                },
                child: const Text('Apri player'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Apri player'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Esci dal quiz'));
      await tester.pumpAndSettle();
      expect(find.text('Esci dal quiz'), findsWidgets);
      await tester.tap(find.text('Esci e riprendi più tardi'));
      await tester.pumpAndSettle();
      expect(repo.abandonCalls, 0);
      expect(find.byType(AssignedQuizPlayerPage), findsNothing);
    });

    testWidgets('abbandono esplicito con doppia conferma', (tester) async {
      _surface(tester);
      final repo = AssignedQuizRepositoryFake(questions: _questions(count: 1));
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => playerOf(repo)),
                  );
                },
                child: const Text('Apri player'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Apri player'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Esci dal quiz'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abbandona tentativo'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Abbandona'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sì, abbandona'));
      await tester.pumpAndSettle();
      expect(repo.abandonCalls, 1);
    });

    testWidgets('responsive 320px senza overflow', (tester) async {
      _surface(tester, size: const Size(320, 640));
      final repo = AssignedQuizRepositoryFake(questions: _questions(count: 20));
      await tester.pumpWidget(MaterialApp(home: playerOf(repo)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Successiva'), findsOneWidget);
    });
  });

  group('AssignedQuizReviewPage', () {
    testWidgets('carica review post-submit con explanation null', (
      tester,
    ) async {
      _surface(tester);
      final repo = AssignedQuizRepositoryFake(
        reviewItems: [
          const AssignedQuizReviewItem(
            position: 1,
            prompt: 'Prompt review?',
            optionA: 'A',
            optionB: 'B',
            optionC: 'C',
            correctOption: 'B',
            selectedOption: 'A',
            isCorrect: false,
            lessonNumber: 3,
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: AssignedQuizReviewPage(
            repository: repo,
            attemptId: 'att-1',
            assignmentTitle: 'Quiz',
            publicCode: 'AQZ-1',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Prompt review?'), findsOneWidget);
      expect(find.text('Da ripassare'), findsOneWidget);
      expect(find.textContaining('Lezione 3'), findsOneWidget);
    });

    testWidgets('not_authorized', (tester) async {
      _surface(tester);
      final repo = AssignedQuizRepositoryFake(
        throwOnReview: AssignedQuizException(
          code: AssignedQuizErrorCode.notAuthorized,
          message: assignedQuizErrorMessageIt(
            AssignedQuizErrorCode.notAuthorized,
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: AssignedQuizReviewPage(
            repository: repo,
            attemptId: 'att-1',
            assignmentTitle: 'Quiz',
            publicCode: 'AQZ-1',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Non hai i permessi'), findsOneWidget);
    });
  });

  group('QuizDashboard four cards', () {
    List<String> tileTitlesInOrder(WidgetTester tester) {
      final cards = tester.widgetList<DashboardActionCard>(
        find.byType(DashboardActionCard),
      );
      return cards.map((c) => c.title).toList(growable: false);
    }

    testWidgets('esattamente quattro card nell’ordine approvato', (
      tester,
    ) async {
      _surface(tester);
      await tester.pumpWidget(const MaterialApp(home: QuizDashboardPage()));
      await tester.pumpAndSettle();

      expect(find.byType(DashboardActionCard), findsNWidgets(4));
      expect(tileTitlesInOrder(tester), [
        'Lezioni e schede',
        'Quiz esame',
        'Statistiche e ripasso errori',
        'Quiz assegnati dalla scuola',
      ]);
      expect(find.text('Statistiche'), findsNothing);
      expect(find.text('Ripasso errori'), findsNothing);
    });

    testWidgets('quarta card apre AssignedQuizListPage', (tester) async {
      _surface(tester);
      await tester.pumpWidget(const MaterialApp(home: QuizDashboardPage()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Quiz assegnati dalla scuola'));
      await tester.pumpAndSettle();
      expect(find.byType(AssignedQuizListPage), findsOneWidget);
    });

    testWidgets('hub Statistiche e ripasso errori e routing', (tester) async {
      _surface(tester);
      demoStudentEnrollmentPath.value = EnrollmentCoursePath.d1;
      addTearDown(() {
        demoStudentEnrollmentPath.value = EnrollmentCoursePath.entro12Miglia;
      });

      await tester.pumpWidget(const MaterialApp(home: QuizDashboardPage()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Statistiche e ripasso errori'));
      await tester.pumpAndSettle();
      expect(find.byType(QuizStatisticsReviewHubPage), findsOneWidget);
      expect(find.text('Statistiche'), findsOneWidget);
      expect(find.text('Ripasso errori'), findsOneWidget);

      await tester.tap(find.text('Statistiche'));
      await tester.pumpAndSettle();
      // Senza studentSession la destinazione resta CategorySelection (comportamento storico).
      expect(
        find.byType(CategorySelectionPage).evaluate().isNotEmpty ||
            find.byType(StatisticsPage).evaluate().isNotEmpty,
        isTrue,
      );

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(QuizStatisticsReviewHubPage), findsOneWidget);

      await tester.tap(find.text('Ripasso errori'));
      await tester.pumpAndSettle();
      expect(find.byType(ErrorReviewPage), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(QuizStatisticsReviewHubPage), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(QuizDashboardPage), findsOneWidget);
    });

    testWidgets('responsive 320px senza overflow né FittedBox nelle card', (
      tester,
    ) async {
      _surface(tester, size: const Size(320, 640));
      await tester.pumpWidget(const MaterialApp(home: QuizDashboardPage()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(DashboardActionCard), findsNWidgets(4));
      expect(
        find.descendant(
          of: find.byType(DashboardActionCard),
          matching: find.byType(FittedBox),
        ),
        findsNothing,
      );

      final assigned = tester.widget<DashboardActionCard>(
        find.widgetWithText(DashboardActionCard, 'Quiz assegnati dalla scuola'),
      );
      expect(assigned.titleMaxLines, 2);
      expect(assigned.compactContent, isTrue);
    });

    testWidgets('hub responsive 320 colonna e desktop affiancato', (
      tester,
    ) async {
      _surface(tester, size: const Size(320, 640));
      await tester.pumpWidget(
        const MaterialApp(home: QuizStatisticsReviewHubPage()),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Statistiche'), findsOneWidget);
      expect(find.text('Ripasso errori'), findsOneWidget);

      _surface(tester, size: const Size(1024, 800));
      await tester.pumpWidget(
        const MaterialApp(home: QuizStatisticsReviewHubPage()),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(DashboardActionCard), findsNWidgets(2));
    });

    testWidgets(
      'DashboardActionCard default senza FittedBox né titleMaxLines',
      (tester) async {
        _surface(tester);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 180,
                height: 200,
                child: DashboardActionCard(
                  title: 'Lezioni e schede',
                  subtitle: 'Percorso lezioni con schede quiz',
                  icon: Icons.menu_book_rounded,
                  dense: true,
                  useStudentBrandStyle: true,
                  onTap: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(FittedBox), findsNothing);
        final card = tester.widget<DashboardActionCard>(
          find.byType(DashboardActionCard),
        );
        expect(card.titleMaxLines, isNull);
        expect(card.compactContent, isFalse);

        final titleText = tester.widget<Text>(find.text('Lezioni e schede'));
        expect(titleText.maxLines, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
