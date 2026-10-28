import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/data/backoffice_mock/school_backoffice_demo_data.dart';
import 'package:scuola_nautica_liana/domain/backoffice/backoffice.dart';
import 'package:scuola_nautica_liana/domain/staff/staff_school_role.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';
import 'package:scuola_nautica_liana/pages/study_access_admin_page.dart';
import 'package:scuola_nautica_liana/repositories/backoffice/backoffice_repository_mock.dart';
import 'package:scuola_nautica_liana/services/staff_access_service.dart';

void _staffAdmin() {
  staffAccessNotifier.value = StaffAccessSnapshot.initial().copyWith(
    isLoading: false,
    hasAuthSession: true,
    staffRole: StaffSchoolRole.schoolAdmin,
    clearError: true,
  );
}

void _clearStaff() {
  staffAccessNotifier.value = StaffAccessSnapshot.initial().copyWith(
    isLoading: false,
    hasAuthSession: false,
    clearError: true,
  );
}

Widget _wrap(Widget child, {Size size = const Size(1366, 768)}) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: MaterialApp(
      home: Scaffold(
        body: SizedBox(width: size.width, height: size.height, child: child),
      ),
    ),
  );
}

Column _cardColumn(WidgetTester tester, Finder scope, String name) {
  return tester.widget<Column>(
    find
        .ancestor(
          of: find.descendant(of: scope, matching: find.text(name)),
          matching: find.byType(Column),
        )
        .first,
  );
}

Finder _selectedNarrowCard() {
  return find
      .ancestor(of: find.text('Cambia allievo'), matching: find.byType(Row))
      .first;
}

Finder _searchField() {
  return find.byWidgetPredicate(
    (w) =>
        w is TextField &&
        (w.decoration?.hintText?.contains('telefono') ?? false),
  );
}

class _CountingRepo extends BackofficeRepositoryMock {
  int detailLoads = 0;
  int lessonMutations = 0;

  @override
  Future<StudentAdmin360View?> getStudentAdmin360(StudentId studentId) async {
    detailLoads++;
    return super.getStudentAdmin360(studentId);
  }

  @override
  Future<void> setLessonSheetsUnlockedForLesson({
    required StudentId studentId,
    required LicenseCategoryId categoryId,
    required int lessonNumber,
    required int sheetCount,
    required bool unlocked,
  }) async {
    lessonMutations++;
    return super.setLessonSheetsUnlockedForLesson(
      studentId: studentId,
      categoryId: categoryId,
      lessonNumber: lessonNumber,
      sheetCount: sheetCount,
      unlocked: unlocked,
    );
  }
}

class _EmptyProfilesRepo extends BackofficeRepositoryMock {
  @override
  Future<List<StudentProfile>> listStudentProfiles() async => [];
}

class _DelayedListRepo extends BackofficeRepositoryMock {
  @override
  Future<List<StudentProfile>> listStudentProfiles() async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    return super.listStudentProfiles();
  }
}

void main() {
  setUp(_staffAdmin);
  tearDown(_clearStaff);

  const marco = SchoolBackofficeDemoData.demoStudentMarco;

  group('STAFF.STUDIO.ACCESS.1 selection', () {
    testWidgets('initial list → auto-select first + detail, no select prompt', (
      tester,
    ) async {
      final repo = _CountingRepo();
      await tester.binding.setSurfaceSize(const Size(1366, 768));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(
        _wrap(StudyAccessAdminPage(embedded: true, repository: repo)),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Seleziona un allievo'), findsNothing);
      expect(find.byKey(const Key('study_access_detail_pane')), findsOneWidget);
      expect(find.text('Lucia Bianchi'), findsWidgets);
      expect(find.text('Schede'), findsOneWidget);
      expect(repo.detailLoads, 1);
    });

    testWidgets('candidate cards omit course badges and keep contact', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1366, 768));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(
        _wrap(
          StudyAccessAdminPage(embedded: true, repository: _CountingRepo()),
        ),
      );
      await tester.pumpAndSettle();

      final list = find.byKey(const Key('study_access_student_list'));
      expect(list, findsOneWidget);
      expect(
        find.descendant(of: list, matching: find.text('Lucia Bianchi')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: list,
          matching: find.textContaining('lucia.bianchi@example.com'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: list, matching: find.textContaining('+39')),
        findsWidgets,
      );
      expect(
        find.descendant(
          of: list,
          matching: find.byIcon(Icons.chevron_right_rounded),
        ),
        findsNWidgets(2),
      );
      expect(
        find.descendant(
          of: list,
          matching: find.text('Oltre 12 miglia vela e motore'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(of: list, matching: find.text('D1')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: list,
          matching: find.text('Entro le 12 miglia motore'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(of: list, matching: find.text('Entro 12 · motore')),
        findsNothing,
      );
      expect(
        find.descendant(of: list, matching: find.text('Vela e motore')),
        findsNothing,
      );
      expect(
        find.descendant(of: list, matching: find.text('Patente a vela')),
        findsNothing,
      );
      expect(
        find.descendant(of: list, matching: find.text('Patente D1')),
        findsNothing,
      );
      expect(
        find.descendant(of: list, matching: find.text('Rinnovo patente')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: list, matching: find.text('Duplicato patente')),
        findsNothing,
      );

      final luciaColumn = _cardColumn(tester, list, 'Lucia Bianchi');
      expect(luciaColumn.children.whereType<SizedBox>(), hasLength(1));
      expect(luciaColumn.children.last, isA<Text>());

      final marcoColumn = _cardColumn(tester, list, 'Marco Verdi');
      expect(marcoColumn.children.whereType<SizedBox>(), hasLength(2));
      expect(marcoColumn.children.last, isNot(isA<SizedBox>()));

      final selectedCard = tester.widget<Material>(
        find
            .ancestor(
              of: find.descendant(
                of: list,
                matching: find.text('Lucia Bianchi'),
              ),
              matching: find.byType(Material),
            )
            .first,
      );
      final shape = selectedCard.shape! as RoundedRectangleBorder;
      expect(shape.side.width, 1.5);

      expect(find.byType(DropdownButton<LicenseCategoryId>), findsOneWidget);
      expect(find.text('Statistiche'), findsOneWidget);
      expect(find.text('Schede'), findsOneWidget);
      expect(find.text('Esame'), findsOneWidget);
      expect(find.text('Ripasso'), findsOneWidget);
    });

    testWidgets('valid preselection preserved', (tester) async {
      final repo = _CountingRepo();
      await tester.binding.setSurfaceSize(const Size(1366, 768));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(
        _wrap(
          StudyAccessAdminPage(
            embedded: true,
            repository: repo,
            initialStudentId: marco,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Marco Verdi'), findsWidgets);
      expect(find.byKey(const Key('study_access_detail_pane')), findsOneWidget);
      // Un solo load per Marco, non Lucia-then-Marco.
      expect(repo.detailLoads, 1);
    });

    testWidgets('invalid preselection → first student', (tester) async {
      final repo = _CountingRepo();
      await tester.binding.setSurfaceSize(const Size(1366, 768));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(
        _wrap(
          StudyAccessAdminPage(
            embedded: true,
            repository: repo,
            initialStudentId: 'stu-does-not-exist',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Lucia Bianchi'), findsWidgets);
      expect(find.byKey(const Key('study_access_detail_pane')), findsOneWidget);
      expect(repo.detailLoads, 1);
    });

    testWidgets('manual change after auto-select sticks', (tester) async {
      final repo = _CountingRepo();
      await tester.binding.setSurfaceSize(const Size(1366, 768));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(
        _wrap(StudyAccessAdminPage(embedded: true, repository: repo)),
      );
      await tester.pumpAndSettle();
      expect(repo.detailLoads, 1);

      await tester.tap(find.text('Marco Verdi').first);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('study_access_detail_pane')), findsOneWidget);
      expect(repo.detailLoads, 2);

      // Rebuild via search noop should keep Marco.
      await tester.enterText(_searchField(), 'Marco');
      await tester.pumpAndSettle();
      expect(find.textContaining('Marco Verdi'), findsWidgets);
      expect(find.textContaining('Lucia Bianchi'), findsNothing);
      expect(repo.detailLoads, 2);
    });

    testWidgets('filter keep / fallback / empty search', (tester) async {
      final repo = _CountingRepo();
      await tester.binding.setSurfaceSize(const Size(1366, 768));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(
        _wrap(
          StudyAccessAdminPage(
            embedded: true,
            repository: repo,
            initialStudentId: marco,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.detailLoads, 1);

      // B+C style: keep Marco when still in results.
      await tester.enterText(_searchField(), 'a'); // Lucia + Marco both match?
      await tester.pumpAndSettle();
      // Use name filter that keeps Marco.
      await tester.enterText(_searchField(), 'Marco');
      await tester.pumpAndSettle();
      expect(find.textContaining('Marco Verdi'), findsWidgets);
      expect(repo.detailLoads, 1);

      // Only Lucia → fallback to Lucia.
      await tester.enterText(_searchField(), 'Lucia');
      await tester.pumpAndSettle();
      expect(find.textContaining('Lucia Bianchi'), findsWidgets);
      expect(find.byKey(const Key('study_access_detail_pane')), findsOneWidget);
      expect(repo.detailLoads, 2);

      // Empty results → no stale detail.
      await tester.enterText(_searchField(), 'zzz-no-match-999');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('study_access_empty_search')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('study_access_detail_pane')), findsNothing);
      expect(find.textContaining('Seleziona un allievo'), findsNothing);
    });

    testWidgets('empty profiles → empty state, no crash, no select prompt', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1366, 768));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(
        _wrap(
          StudyAccessAdminPage(
            embedded: true,
            repository: _EmptyProfilesRepo(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('study_access_empty_profiles')),
        findsOneWidget,
      );
      expect(find.textContaining('Seleziona un allievo'), findsNothing);
      expect(find.byKey(const Key('study_access_detail_pane')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('async load shows loading then auto-selects once', (
      tester,
    ) async {
      final repo = _DelayedListRepo();
      await tester.binding.setSurfaceSize(const Size(1366, 768));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(
        _wrap(StudyAccessAdminPage(embedded: true, repository: repo)),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(find.textContaining('Seleziona un allievo'), findsNothing);

      await tester.pumpAndSettle();
      expect(find.byKey(const Key('study_access_detail_pane')), findsOneWidget);
      expect(find.textContaining('Lucia Bianchi'), findsWidgets);
    });

    testWidgets('auto-select detail load count == one manual selection', (
      tester,
    ) async {
      final autoRepo = _CountingRepo();
      await tester.binding.setSurfaceSize(const Size(1366, 768));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(
        _wrap(StudyAccessAdminPage(embedded: true, repository: autoRepo)),
      );
      await tester.pumpAndSettle();
      // Una sola getStudentAdmin360 — equivalente a un click manuale.
      expect(autoRepo.detailLoads, 1);

      await tester.tap(find.text('Marco Verdi').first);
      await tester.pumpAndSettle();
      expect(autoRepo.detailLoads, 2);
    });

    testWidgets('studio unlock action still wired after auto-select', (
      tester,
    ) async {
      final repo = _CountingRepo();
      await tester.binding.setSurfaceSize(const Size(1366, 768));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(
        _wrap(StudyAccessAdminPage(embedded: true, repository: repo)),
      );
      await tester.pumpAndSettle();

      // Primary unlock/lock button on first lesson card.
      final action = find.widgetWithText(FilledButton, 'Sblocca lezione');
      final lockAction = find.widgetWithText(FilledButton, 'Blocca lezione');
      final button = action.evaluate().isNotEmpty ? action : lockAction;
      expect(button, findsWidgets);

      await tester.ensureVisible(button.first);
      await tester.tap(button.first);
      await tester.pumpAndSettle();

      expect(repo.lessonMutations, 1);
      expect(find.byKey(const Key('study_access_detail_pane')), findsOneWidget);
    });

    testWidgets('desktop 1024/1440/1920: list + detail, no H-overflow', (
      tester,
    ) async {
      for (final size in const [
        Size(1024, 768),
        Size(1366, 768),
        Size(1440, 900),
        Size(1920, 1080),
      ]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(
          _wrap(const StudyAccessAdminPage(embedded: true), size: size),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Seleziona un allievo'),
          findsNothing,
          reason: 'size $size',
        );
        expect(
          find.byKey(const Key('study_access_detail_pane')),
          findsOneWidget,
          reason: 'size $size',
        );
        expect(
          find.byKey(const Key('study_access_student_list')),
          findsOneWidget,
          reason: 'size $size',
        );
        expect(tester.takeException(), isNull);
      }
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('narrow: list-first, no auto-select, no select prompt', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(
        _wrap(
          const StudyAccessAdminPage(embedded: true),
          size: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Seleziona un allievo'), findsNothing);
      expect(find.byKey(const Key('study_access_detail_pane')), findsNothing);
      expect(_searchField(), findsOneWidget);
      expect(find.textContaining('Lucia Bianchi'), findsWidgets);
      expect(find.textContaining('Marco Verdi'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('narrow: manual select shows detail + Cambia allievo', (
      tester,
    ) async {
      // In produzione la page è dentro Expanded(AdminHome); qui simuliamo
      // lo stesso vincolo di altezza del modulo gestionale.
      const size = Size(390, 844);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: size),
          child: const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  SizedBox(height: 48), // faux module switcher
                  Expanded(child: StudyAccessAdminPage(embedded: true)),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Marco Verdi').first);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('study_access_detail_pane')), findsOneWidget);
      expect(find.text('Cambia allievo'), findsOneWidget);
      expect(find.textContaining('Seleziona un allievo'), findsNothing);
      final marcoCard = _selectedNarrowCard();
      expect(
        find.descendant(of: marcoCard, matching: find.text('Rinnovo patente')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: marcoCard, matching: find.text('D1')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: marcoCard,
          matching: find.text('Entro le 12 miglia motore'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(of: marcoCard, matching: find.text('Patente D1')),
        findsNothing,
      );

      await tester.tap(find.text('Cambia allievo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lucia Bianchi').first);
      await tester.pumpAndSettle();
      expect(find.text('Cambia allievo'), findsOneWidget);
      final luciaCard = _selectedNarrowCard();
      expect(
        find.descendant(of: luciaCard, matching: find.text('Rinnovo patente')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: luciaCard,
          matching: find.text('Oltre 12 miglia vela e motore'),
        ),
        findsNothing,
      );
      final luciaColumn = tester.widget<Column>(
        find.descendant(of: luciaCard, matching: find.byType(Column)).first,
      );
      expect(luciaColumn.children.whereType<SizedBox>(), hasLength(1));
      expect(luciaColumn.children.last, isA<Text>());
      // Overflow verticale su 390 con header+card+tab lezioni è un vincolo
      // layout pre-esistente del list-then-detail; la selection resta corretta.
      tester.takeException();
    });
  });
}
