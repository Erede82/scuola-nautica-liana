import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/models/assigned_quiz_models.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';
import 'package:scuola_nautica_liana/repositories/assigned_quiz_repository.dart';
import 'package:scuola_nautica_liana/widgets/backoffice/assigned_quiz_staff_section.dart';

AssignedQuizSummary _summary({
  required String id,
  required AssignedQuizStatus status,
  String title = 'Quiz errori',
  String? staffNote,
  DateTime? expiresAt,
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
    status: status,
    questionCount: 20,
    repeatPolicy: status == AssignedQuizStatus.draft
        ? AssignedQuizRepeatPolicy.limited
        : AssignedQuizRepeatPolicy.unlimited,
    maxAttempts: status == AssignedQuizStatus.draft ? 2 : null,
    createdAt: DateTime.utc(2026, 7, 1),
    assignedAt: status == AssignedQuizStatus.assigned
        ? DateTime.utc(2026, 7, 2)
        : null,
    expiresAt: expiresAt,
    attemptsCount: attemptsCount,
    bestScorePercentage: bestScorePercentage,
  );
}

Widget _harness({
  required AssignedQuizRepository repository,
  LicenseCategoryId category = LicenseCategoryId.motore,
  bool isStaffPreview = false,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: AssignedQuizStaffSection(
          studentId: 'st-1',
          studentDisplayName: 'Mario Rossi',
          licenseCategoryId: category,
          repository: repository,
          isStaffPreview: isStaffPreview,
        ),
      ),
    ),
  );
}

void _prepareSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AssignedQuizStaffSection', () {
    testWidgets('loading', (tester) async {
      _prepareSurface(tester);
      final repo = AssignedQuizRepositoryFake(
        loadDelay: const Duration(milliseconds: 80),
        summaries: [_summary(id: '1', status: AssignedQuizStatus.assigned)],
      );
      await tester.pumpWidget(_harness(repository: repo));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Quiz errori'), findsOneWidget);
    });

    testWidgets('empty state', (tester) async {
      _prepareSurface(tester);
      final repo = AssignedQuizRepositoryFake();
      await tester.pumpWidget(_harness(repository: repo));
      await tester.pumpAndSettle();
      expect(
        find.text('Nessun quiz personalizzato assegnato.'),
        findsOneWidget,
      );
      expect(find.text('Genera il primo quiz'), findsOneWidget);
    });

    testWidgets('lista draft/assigned/archived e niente stats false', (
      tester,
    ) async {
      _prepareSurface(tester);
      final repo = AssignedQuizRepositoryFake(
        summaries: [
          _summary(id: 'd', status: AssignedQuizStatus.draft, title: 'Bozza X'),
          _summary(
            id: 'a',
            status: AssignedQuizStatus.assigned,
            title: 'Assegnato Y',
          ),
          _summary(
            id: 'z',
            status: AssignedQuizStatus.archived,
            title: 'Archivio Z',
          ),
        ],
      );
      await tester.pumpWidget(_harness(repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('Bozza X'), findsOneWidget);
      expect(find.text('Assegnato Y'), findsOneWidget);
      expect(find.text('Archivio Z'), findsOneWidget);
      expect(find.text('Bozza'), findsWidgets);
      expect(find.text('Assegnato'), findsWidgets);
      expect(find.text('Archiviato'), findsOneWidget);
      expect(find.textContaining('Tentativi: 0'), findsNothing);
      expect(find.textContaining('Miglior punteggio'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Assegna'), findsOneWidget);
      expect(find.text('Elimina bozza'), findsOneWidget);
    });

    testWidgets('pubblica una bozza e la rende assegnata', (tester) async {
      _prepareSurface(tester);
      final repo = AssignedQuizRepositoryFake(
        summaries: [
          _summary(
            id: 'd1',
            status: AssignedQuizStatus.draft,
            title: 'Bozza da assegnare',
          ),
        ],
      );
      await tester.pumpWidget(_harness(repository: repo));
      await tester.pumpAndSettle();

      await _tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Assegna'),
      );
      expect(
        find.textContaining('diventerà visibile all’allievo'),
        findsOneWidget,
      );
      await _tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Assegna'),
      );

      expect(repo.rpcCalls, contains('publish_draft'));
      expect(repo.summaries.single.status, AssignedQuizStatus.assigned);
      expect(find.text('Assegnato'), findsOneWidget);
      expect(find.text('Elimina bozza'), findsNothing);
    });

    testWidgets('apertura dialog e validazione titolo', (tester) async {
      _prepareSurface(tester);
      final repo = AssignedQuizRepositoryFake();
      await tester.pumpWidget(_harness(repository: repo));
      await tester.pumpAndSettle();

      await _tapVisible(tester, find.text('Genera quiz dagli errori'));
      expect(find.text('Genera quiz dagli errori'), findsWidgets);

      await tester.enterText(find.byType(TextField).first, '   ');
      await _tapVisible(tester, find.text('Assegna ora'));
      expect(find.textContaining('titolo'), findsWidgets);
      expect(repo.rpcCalls, isEmpty);
    });

    testWidgets('selected lessons e limited maxAttempts', (tester) async {
      _prepareSurface(tester);
      final repo = AssignedQuizRepositoryFake();
      await tester.pumpWidget(_harness(repository: repo));
      await tester.pumpAndSettle();
      await _tapVisible(tester, find.text('Genera quiz dagli errori'));

      await _tapVisible(tester, find.text('Seleziona lezioni'));
      await _tapVisible(tester, find.text('Limitati'));
      final maxAttemptsField = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(maxAttemptsField.last, '');
      await _tapVisible(tester, find.text('Assegna ora'));
      expect(find.textContaining('tentativ'), findsWidgets);
    });

    testWidgets('vela disabilitata', (tester) async {
      _prepareSurface(tester);
      final repo = AssignedQuizRepositoryFake();
      await tester.pumpWidget(
        _harness(repository: repo, category: LicenseCategoryId.vela),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Funzione non disponibile per questo percorso'),
        findsOneWidget,
      );
      await _tapVisible(tester, find.text('Genera quiz dagli errori'));
      expect(
        find.text('Funzione non disponibile per questo percorso'),
        findsWidgets,
      );
      final assignBtn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Assegna ora'),
      );
      expect(assignBtn.onPressed, isNull);
    });

    testWidgets('success RPC con refresh e doppio click impedito', (
      tester,
    ) async {
      _prepareSurface(tester);
      final repo = AssignedQuizRepositoryFake();
      await tester.pumpWidget(_harness(repository: repo));
      await tester.pumpAndSettle();
      expect(repo.loadForStudentCalls, 1);

      await _tapVisible(tester, find.text('Genera quiz dagli errori'));
      await tester.ensureVisible(find.text('Assegna ora'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Assegna ora'));
      await tester.pump();
      await tester.tap(find.text('Assegna ora'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(
        repo.rpcCalls
            .where((c) => c == 'generate_assigned_quiz_from_errors')
            .length,
        1,
      );
      expect(repo.loadForStudentCalls, greaterThan(1));
      expect(find.textContaining('AQZ-'), findsWidgets);
      expect(find.textContaining('assegnato con'), findsOneWidget);
    });

    testWidgets('errore insufficient_error_questions', (tester) async {
      _prepareSurface(tester);
      final repo = AssignedQuizRepositoryFake(
        throwOnGenerate: AssignedQuizException(
          code: AssignedQuizErrorCode.insufficientErrorQuestions,
          message: assignedQuizErrorMessageIt(
            AssignedQuizErrorCode.insufficientErrorQuestions,
          ),
        ),
      );
      await tester.pumpWidget(_harness(repository: repo));
      await tester.pumpAndSettle();
      await _tapVisible(tester, find.text('Genera quiz dagli errori'));
      await _tapVisible(tester, find.text('Assegna ora'));
      expect(
        find.textContaining('abbastanza domande sbagliate'),
        findsOneWidget,
      );
      expect(find.text('Genera quiz dagli errori'), findsWidgets);
    });

    testWidgets('archivia e elimina bozza', (tester) async {
      _prepareSurface(tester);
      final repo = AssignedQuizRepositoryFake(
        summaries: [
          _summary(
            id: 'd1',
            status: AssignedQuizStatus.draft,
            title: 'Bozza 1',
          ),
          _summary(
            id: 'a1',
            status: AssignedQuizStatus.assigned,
            title: 'Assegnato 1',
          ),
        ],
      );
      await tester.pumpWidget(_harness(repository: repo));
      await tester.pumpAndSettle();

      await _tapVisible(tester, find.text('Elimina bozza'));
      expect(
        find.text(
          'La bozza e le sue domande verranno eliminate definitivamente.',
        ),
        findsOneWidget,
      );
      await _tapVisible(tester, find.text('Elimina'));
      expect(find.text('Bozza 1'), findsNothing);

      await _tapVisible(tester, find.text('Archivia'));
      await _tapVisible(tester, find.widgetWithText(FilledButton, 'Archivia'));
      expect(find.text('Archiviato'), findsWidgets);
    });

    testWidgets('modifica e clear expiresAt', (tester) async {
      _prepareSurface(tester);
      final repo = AssignedQuizRepositoryFake(
        summaries: [
          _summary(
            id: 'a1',
            status: AssignedQuizStatus.assigned,
            title: 'Da modificare',
            expiresAt: DateTime.utc(2026, 12, 1),
          ),
        ],
      );
      await tester.pumpWidget(_harness(repository: repo));
      await tester.pumpAndSettle();

      await _tapVisible(tester, find.text('Modifica'));
      await _tapVisible(tester, find.text('Cancella scadenza'));
      await _tapVisible(tester, find.text('Salva'));

      expect(repo.lastMetadataPatch?.expiresAt.isClear, isTrue);
      expect(repo.summaries.single.expiresAt, isNull);
    });

    testWidgets('lazy load tentativi', (tester) async {
      _prepareSurface(tester);
      final repo = AssignedQuizRepositoryFake(
        summaries: [_summary(id: 'a1', status: AssignedQuizStatus.assigned)],
        attempts: [
          AssignedQuizAttemptSummary(
            id: 'att-1',
            assignmentId: 'a1',
            attemptNumber: 1,
            status: AssignedQuizAttemptStatus.submitted,
            startedAt: DateTime.utc(2026, 7, 3, 10),
            submittedAt: DateTime.utc(2026, 7, 3, 10, 20),
            correctCount: 18,
            wrongCount: 2,
            unansweredCount: 0,
            scorePercentage: 90,
            durationSeconds: 600,
          ),
          AssignedQuizAttemptSummary(
            id: 'att-2',
            assignmentId: 'a1',
            attemptNumber: 2,
            status: AssignedQuizAttemptStatus.inProgress,
            startedAt: DateTime.utc(2026, 7, 4, 9),
            correctCount: 0,
            wrongCount: 0,
            unansweredCount: 0,
          ),
        ],
      );
      await tester.pumpWidget(_harness(repository: repo));
      await tester.pumpAndSettle();
      expect(repo.loadAttemptsCalls, isEmpty);

      await _tapVisible(tester, find.text('Vedi tentativi'));
      expect(repo.loadAttemptsCalls, ['a1']);
      expect(find.textContaining('Tentativo 1'), findsOneWidget);
      expect(find.textContaining('In corso'), findsOneWidget);
      expect(find.textContaining('90%'), findsOneWidget);
    });

    testWidgets('preview staff senza fetch né azioni', (tester) async {
      _prepareSurface(tester);
      final repo = AssignedQuizRepositoryFake(
        summaries: [_summary(id: 'real', status: AssignedQuizStatus.assigned)],
      );
      await tester.pumpWidget(_harness(repository: repo, isStaffPreview: true));
      await tester.pumpAndSettle();
      expect(repo.loadForStudentCalls, 0);
      expect(find.textContaining('Anteprima dimostrativa'), findsOneWidget);
      expect(find.textContaining('non reale'), findsOneWidget);
      expect(find.text('DEMO-NON-REALE'), findsOneWidget);
      expect(find.text('Vedi tentativi'), findsNothing);
      expect(find.text('Modifica'), findsNothing);
      final generateBtn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Genera quiz dagli errori'),
      );
      expect(generateBtn.onPressed, isNull);
    });

    testWidgets('cambio modalità preview → reale e reale → preview', (
      tester,
    ) async {
      _prepareSurface(tester);
      final repo = AssignedQuizRepositoryFake(
        loadDelay: const Duration(milliseconds: 40),
        summaries: [
          _summary(
            id: 'real-1',
            status: AssignedQuizStatus.assigned,
            title: 'Quiz reale caricato',
          ),
        ],
      );

      await tester.pumpWidget(_harness(repository: repo, isStaffPreview: true));
      await tester.pumpAndSettle();
      expect(repo.loadForStudentCalls, 0);
      expect(find.textContaining('Esempio dimostrativo'), findsOneWidget);

      await tester.pumpWidget(
        _harness(repository: repo, isStaffPreview: false),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
      expect(repo.loadForStudentCalls, 1);
      expect(find.text('Quiz reale caricato'), findsOneWidget);
      expect(find.textContaining('Esempio dimostrativo'), findsNothing);

      await tester.pumpWidget(_harness(repository: repo, isStaffPreview: true));
      await tester.pumpAndSettle();
      expect(repo.loadForStudentCalls, 1);
      expect(find.textContaining('Esempio dimostrativo'), findsOneWidget);
      expect(find.text('Quiz reale caricato'), findsNothing);
    });
  });
}
