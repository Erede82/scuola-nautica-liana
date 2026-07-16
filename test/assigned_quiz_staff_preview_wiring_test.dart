import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/data/backoffice_mock/school_backoffice_demo_data.dart';
import 'package:scuola_nautica_liana/models/assigned_quiz_models.dart';
import 'package:scuola_nautica_liana/repositories/assigned_quiz_repository.dart';
import 'package:scuola_nautica_liana/repositories/backoffice/backoffice_repository_mock.dart';
import 'package:scuola_nautica_liana/widgets/backoffice/assigned_quiz_staff_section.dart';
import 'package:scuola_nautica_liana/widgets/backoffice/student_360_detail_view.dart';

void _prepareSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _scheda360({
  required bool isStaffPreview,
  required AssignedQuizRepository assignedQuizzes,
  required BackofficeRepositoryMock backoffice,
}) {
  final view = SchoolBackofficeDemoData.aggregateFor(
    SchoolBackofficeDemoData.demoStudentLucia,
  )!;
  return MaterialApp(
    home: Scaffold(
      body: Student360DetailView(
        view: view,
        repository: backoffice,
        onRefreshDetail: ([_]) async {},
        initialTabIndex: 2, // Studio
        isStaffPreview: isStaffPreview,
        assignedQuizzes: assignedQuizzes,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Scheda 360 preview wiring AssignedQuiz', () {
    testWidgets('preview: nessun loadForStudent, testo anteprima, no azioni', (
      tester,
    ) async {
      _prepareSurface(tester);
      final assigned = AssignedQuizRepositoryFake(
        summaries: [
          AssignedQuizSummary(
            id: 'should-not-load',
            publicCode: 'AQZ-REAL',
            studentId: SchoolBackofficeDemoData.demoStudentLucia,
            studentUserId: 'u',
            licenseCategory: 'A12',
            title: 'Reale nascosto',
            status: AssignedQuizStatus.assigned,
            questionCount: 10,
            repeatPolicy: AssignedQuizRepeatPolicy.unlimited,
            createdAt: DateTime.utc(2026, 7, 1),
          ),
        ],
      );
      final backoffice = BackofficeRepositoryMock();

      await tester.pumpWidget(
        _scheda360(
          isStaffPreview: true,
          assignedQuizzes: assigned,
          backoffice: backoffice,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AssignedQuizStaffSection), findsOneWidget);
      expect(assigned.loadForStudentCalls, 0);
      expect(find.textContaining('Anteprima dimostrativa'), findsOneWidget);
      expect(find.text('DEMO-NON-REALE'), findsOneWidget);
      expect(find.text('Reale nascosto'), findsNothing);
      expect(find.text('Vedi tentativi'), findsNothing);
      expect(find.text('Modifica'), findsNothing);
      expect(find.text('Archivia'), findsNothing);
      expect(find.text('Elimina bozza'), findsNothing);

      final generateBtn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Genera quiz dagli errori'),
      );
      expect(generateBtn.onPressed, isNull);
    });

    testWidgets('scheda reale: loadForStudent con students.id', (tester) async {
      _prepareSurface(tester);
      final studentId = SchoolBackofficeDemoData.demoStudentLucia;
      final assigned = AssignedQuizRepositoryFake(
        summaries: [
          AssignedQuizSummary(
            id: 'a1',
            publicCode: 'AQZ-1',
            studentId: studentId,
            studentUserId: 'auth-user-not-student-id',
            licenseCategory: 'A12',
            title: 'Quiz reale scheda',
            status: AssignedQuizStatus.assigned,
            questionCount: 20,
            repeatPolicy: AssignedQuizRepeatPolicy.unlimited,
            createdAt: DateTime.utc(2026, 7, 1),
            assignedAt: DateTime.utc(2026, 7, 2),
          ),
        ],
      );
      final backoffice = BackofficeRepositoryMock();

      await tester.pumpWidget(
        _scheda360(
          isStaffPreview: false,
          assignedQuizzes: assigned,
          backoffice: backoffice,
        ),
      );
      await tester.pumpAndSettle();

      expect(assigned.loadForStudentCalls, 1);
      expect(find.text('Quiz reale scheda'), findsOneWidget);
      expect(find.textContaining('Anteprima dimostrativa'), findsNothing);
      // Il repository riceve students.id, non user_id.
      expect(assigned.summaries.single.studentId, studentId);
      expect(assigned.summaries.single.studentUserId, isNot(studentId));
    });

    testWidgets('regressioni Studio: 6 tab e Abilita quiz esame', (
      tester,
    ) async {
      _prepareSurface(tester);
      final assigned = AssignedQuizRepositoryFake();
      final backoffice = BackofficeRepositoryMock();

      await tester.pumpWidget(
        _scheda360(
          isStaffPreview: true,
          assignedQuizzes: assigned,
          backoffice: backoffice,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Scheda'), findsOneWidget);
      expect(find.text('Documenti'), findsOneWidget);
      expect(find.text('Studio'), findsOneWidget);
      expect(find.text('Guide'), findsOneWidget);
      expect(find.text('Esami'), findsOneWidget);
      expect(find.text('Contabilità'), findsOneWidget);
      expect(find.byType(Tab), findsNWidgets(6));

      expect(find.text('Gestisci schede'), findsOneWidget);
      expect(find.text('Abilita quiz esame'), findsOneWidget);
      expect(find.text('Assegna ripasso'), findsOneWidget);

      await tester.tap(find.text('Abilita quiz esame'));
      await tester.pumpAndSettle();
      expect(find.textContaining('quiz esame'), findsWidgets);
    });
  });
}
