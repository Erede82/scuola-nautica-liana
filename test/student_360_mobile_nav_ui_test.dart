import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/data/backoffice_mock/school_backoffice_demo_data.dart';
import 'package:scuola_nautica_liana/domain/course_taxonomy.dart';
import 'package:scuola_nautica_liana/domain/staff/staff_school_role.dart';
import 'package:scuola_nautica_liana/pages/admin_home_page.dart';
import 'package:scuola_nautica_liana/pages/backoffice/school_management_shell_page.dart';
import 'package:scuola_nautica_liana/pages/backoffice/student_360_direct_page.dart';
import 'package:scuola_nautica_liana/services/staff_access_service.dart';
import 'package:scuola_nautica_liana/widgets/backoffice/student_360_detail_view.dart';

Future<void> _asAdmin() async {
  staffAccessNotifier.value = StaffAccessSnapshot.initial().copyWith(
    isLoading: false,
    hasAuthSession: true,
    staffRole: StaffSchoolRole.schoolAdmin,
    clearError: true,
  );
}

Future<void> _pumpShell(WidgetTester tester, Size viewport) async {
  await tester.binding.setSurfaceSize(viewport);
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: viewport),
      child: const MaterialApp(
        home: Scaffold(body: SchoolManagementShellPage(embedded: true)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpAdminModule(
  WidgetTester tester,
  Size viewport, {
  required String moduleTitle,
}) async {
  await _asAdmin();
  addTearDown(() {
    staffAccessNotifier.value = StaffAccessSnapshot.initial().copyWith(
      isLoading: false,
      hasAuthSession: false,
      clearError: true,
    );
  });
  await tester.binding.setSurfaceSize(viewport);
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: viewport),
      child: const MaterialApp(home: AdminHomePage()),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(moduleTitle).first);
  await tester.pumpAndSettle();
}

void main() {
  group('BO-MOBILE.3-A Scheda 360 mobile 390×844', () {
    testWidgets('lista → push 360 → back preserva ricerca e filtro percorso', (
      tester,
    ) async {
      await _pumpShell(tester, const Size(390, 844));

      expect(find.byType(SchoolManagementShellPage), findsOneWidget);
      expect(find.byType(Student360DirectPage), findsNothing);
      expect(find.byType(Student360DetailView), findsNothing);
      expect(
        find.textContaining('Seleziona un allievo dalla lista'),
        findsNothing,
      );
      expect(find.text('Lucia Bianchi'), findsOneWidget);
      expect(find.text('Marco Verdi'), findsOneWidget);

      // Ricerca + filtro percorso D1 (fixture: Marco Verdi è D1).
      await tester.enterText(find.byType(TextField), 'Marco');
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButton<EnrollmentCoursePath?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('D1 · d1').last);
      await tester.pumpAndSettle();

      final pathBefore = tester.widget<DropdownButton<EnrollmentCoursePath?>>(
        find.byType(DropdownButton<EnrollmentCoursePath?>),
      );
      expect(pathBefore.value, EnrollmentCoursePath.d1);
      expect(find.text('Marco Verdi'), findsOneWidget);
      expect(find.text('Lucia Bianchi'), findsNothing);
      expect(find.text('Marco'), findsOneWidget);

      await tester.tap(find.text('Marco Verdi'));
      await tester.pumpAndSettle();

      expect(find.byType(Student360DirectPage), findsOneWidget);
      expect(find.text('Scheda 360'), findsOneWidget);
      expect(find.text('Marco Verdi'), findsWidgets);
      // Lista non sotto il dettaglio.
      expect(find.byType(TextField), findsNothing);

      await tester.tap(find.byType(BackButton).first);
      await tester.pumpAndSettle();

      expect(find.byType(Student360DirectPage), findsNothing);
      expect(find.byType(Student360DetailView), findsNothing);
      expect(
        find.textContaining('Seleziona un allievo dalla lista'),
        findsNothing,
      );
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Marco'), findsOneWidget);

      final pathAfter = tester.widget<DropdownButton<EnrollmentCoursePath?>>(
        find.byType(DropdownButton<EnrollmentCoursePath?>),
      );
      expect(pathAfter.value, EnrollmentCoursePath.d1);
      expect(find.text('D1 · d1'), findsWidgets);
      expect(find.text('Marco Verdi'), findsOneWidget);
      expect(find.text('Lucia Bianchi'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('BO-MOBILE.3-A Scheda 360 mobile 430×932', () {
    testWidgets('header, KPI 2×2, tab e scroll', (tester) async {
      await _pumpShell(tester, const Size(430, 932));
      await tester.tap(find.text('Lucia Bianchi'));
      await tester.pumpAndSettle();

      expect(find.byType(Student360DetailView), findsOneWidget);
      expect(find.text('Lucia Bianchi'), findsWidgets);
      expect(find.text('Stato pratica'), findsWidgets);
      expect(find.text('Saldo residuo'), findsOneWidget);
      expect(find.text('Prossima guida'), findsOneWidget);
      expect(find.text('Ultimo esame'), findsOneWidget);

      final kpiRects = [
        tester.getRect(find.text('Stato pratica').first),
        tester.getRect(find.text('Saldo residuo')),
        tester.getRect(find.text('Prossima guida')),
        tester.getRect(find.text('Ultimo esame')),
      ];
      // Prima riga: due card affiancate (top simili).
      expect((kpiRects[0].top - kpiRects[1].top).abs(), lessThan(8));
      expect(kpiRects[1].left, greaterThan(kpiRects[0].right - 1));
      // Seconda riga sotto la prima.
      expect(kpiRects[2].top, greaterThan(kpiRects[0].bottom - 1));

      expect(find.text('Scheda'), findsOneWidget);
      expect(find.text('Documenti'), findsOneWidget);
      expect(find.text('Studio'), findsOneWidget);
      expect(find.text('Guide'), findsOneWidget);
      expect(find.text('Esami'), findsOneWidget);
      expect(find.text('Contabilità'), findsOneWidget);

      await tester.tap(find.text('Documenti'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Studio'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('BO-MOBILE.3-A tablet 768×1024', () {
    testWidgets('768 < 880: push dedicato senza split-pane', (tester) async {
      await _pumpShell(tester, const Size(768, 1024));

      expect(
        find.textContaining('Seleziona un allievo dalla lista'),
        findsNothing,
      );
      await tester.tap(find.text('Marco Verdi'));
      await tester.pumpAndSettle();

      expect(find.byType(Student360DirectPage), findsOneWidget);
      expect(find.text('Scheda 360'), findsOneWidget);
      expect(find.text('Marco Verdi'), findsWidgets);
      expect(find.byType(VerticalDivider), findsNothing);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(Student360DirectPage), findsNothing);
      expect(find.text('Marco Verdi'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('BO-MOBILE.3-A desktop 1366×768', () {
    testWidgets('split-pane inline senza Navigator.push', (tester) async {
      await _pumpShell(tester, const Size(1366, 768));

      expect(
        find.textContaining('Seleziona un allievo dalla lista'),
        findsOneWidget,
      );
      expect(find.byType(Student360DirectPage), findsNothing);

      await tester.tap(find.text('Lucia Bianchi'));
      await tester.pumpAndSettle();

      expect(find.byType(Student360DirectPage), findsNothing);
      expect(find.byType(Student360DetailView), findsOneWidget);
      expect(find.text('Lucia Bianchi'), findsWidgets);
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('BO-MOBILE.3-A aperture da altri moduli', () {
    Future<void> openFirstScheda360AndBack(
      WidgetTester tester, {
      required String moduleTitle,
    }) async {
      await _pumpAdminModule(
        tester,
        const Size(390, 844),
        moduleTitle: moduleTitle,
      );
      expect(find.text(moduleTitle), findsWidgets);

      final open360 = find.text('Apri Scheda 360');
      expect(open360, findsWidgets);
      await tester.scrollUntilVisible(
        open360.first,
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(open360.first);
      await tester.pumpAndSettle();

      expect(find.byType(Student360DirectPage), findsOneWidget);
      expect(find.text('Scheda 360'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(Student360DirectPage), findsNothing);
      expect(find.text(moduleTitle), findsWidgets);
      expect(tester.takeException(), isNull);
    }

    testWidgets('Pratiche → Scheda 360 → back', (tester) async {
      await openFirstScheda360AndBack(tester, moduleTitle: 'Pratiche');
    });

    testWidgets('Guide / Agenda: same Student360DirectPage + back', (
      tester,
    ) async {
      // L’agenda è settimanale: gli appuntamenti demo possono essere fuori settimana.
      // Verifica il target condiviso usato da onOpenStudent360 (come da bottom sheet).
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                return Scaffold(
                  appBar: AppBar(title: const Text('Guide / Agenda')),
                  body: Center(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => Student360DirectPage(
                              studentId:
                                  SchoolBackofficeDemoData.demoStudentLucia,
                            ),
                          ),
                        );
                      },
                      child: const Text('Simula Apri Scheda 360'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simula Apri Scheda 360'));
      await tester.pumpAndSettle();
      expect(find.byType(Student360DirectPage), findsOneWidget);
      expect(find.text('Scheda 360'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(Student360DirectPage), findsNothing);
      expect(find.text('Guide / Agenda'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Contabilità → Scheda 360 → back', (tester) async {
      await openFirstScheda360AndBack(tester, moduleTitle: 'Contabilità');
    });
  });
}
