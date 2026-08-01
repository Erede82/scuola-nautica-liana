import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/backoffice/backoffice.dart';
import 'package:scuola_nautica_liana/domain/staff/staff_school_role.dart';
import 'package:scuola_nautica_liana/pages/backoffice/accounting_payments_directory_page.dart';
import 'package:scuola_nautica_liana/pages/backoffice/guidance_appointments_directory_page.dart';
import 'package:scuola_nautica_liana/pages/backoffice/practice_dossiers_directory_page.dart';
import 'package:scuola_nautica_liana/pages/backoffice/school_management_shell_page.dart';
import 'package:scuola_nautica_liana/pages/backoffice/video_courses_admin_page.dart';
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

Widget _wrap(Widget child, {Size size = const Size(390, 844)}) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

Future<void> _enterSearch(WidgetTester tester, Finder field, String q) async {
  await tester.enterText(field, q);
  await tester.pumpAndSettle();
}

void main() {
  setUp(_staffAdmin);
  tearDown(_clearStaff);

  testWidgets('Allievi: ricerca telefono tollera spazi', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      _wrap(const SchoolManagementShellPage(embedded: true)),
    );
    await tester.pumpAndSettle();

    // Demo Lucia: +393200000001
    await _enterSearch(tester, find.byType(TextField).first, '320 000 0001');
    expect(find.text('Lucia Bianchi'), findsOneWidget);
    expect(find.text('Marco Verdi'), findsNothing);

    await _enterSearch(tester, find.byType(TextField).first, 'Marco');
    expect(find.text('Marco Verdi'), findsOneWidget);

    await _enterSearch(tester, find.byType(TextField).first, '3999999999');
    expect(find.text('Lucia Bianchi'), findsNothing);
    expect(find.text('Marco Verdi'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Accessi studio: ricerca telefono via matchesSearch', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(_wrap(const StudyAccessAdminPage(embedded: true)));
    await tester.pumpAndSettle();

    final search = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          (w.decoration?.hintText?.contains('telefono') ?? false),
    );
    expect(search, findsOneWidget);

    await _enterSearch(tester, search, '3200000001');
    expect(find.textContaining('Lucia'), findsWidgets);
    expect(find.textContaining('Marco'), findsNothing);

    await _enterSearch(tester, search, 'Lucia');
    expect(find.textContaining('Lucia'), findsWidgets);

    await _enterSearch(tester, search, '3999999999');
    expect(find.textContaining('Lucia Bianchi'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Videocorsi: ricerca telefono tab Accessi', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(_wrap(const VideoCoursesAdminPage(embedded: true)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Accessi allievi'));
    await tester.pumpAndSettle();

    final search = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          (w.decoration?.hintText?.contains('telefono') ?? false),
    );
    expect(search, findsOneWidget);

    await _enterSearch(tester, search, '+39 320 000 0001');
    expect(find.textContaining('Lucia'), findsWidgets);
    expect(find.textContaining('Marco'), findsNothing);

    await _enterSearch(tester, search, 'Marco');
    expect(find.textContaining('Marco'), findsWidgets);

    await _enterSearch(tester, search, '3999999999');
    expect(find.textContaining('Lucia Bianchi'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Pratiche: ricerca telefono directory', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      _wrap(
        PracticeDossiersDirectoryPage(
          embedded: true,
          onOpenStudent360: (_, {int initialTabIndex = 0}) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final search = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          (w.decoration?.hintText?.contains('telefono') ?? false),
    );
    expect(search, findsOneWidget);

    await _enterSearch(tester, search, '320 000 0001');
    expect(find.textContaining('Lucia'), findsWidgets);
    expect(find.textContaining('Marco'), findsNothing);

    await _enterSearch(tester, search, 'Lucia');
    expect(find.textContaining('Lucia'), findsWidgets);

    await _enterSearch(tester, search, '3999999999');
    expect(find.textContaining('Lucia Bianchi'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Guide: ricerca telefono filtra elenco practiceSea', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final repo = BackofficeRepositoryMock();
    final now = DateTime.now();
    await repo.addGuidanceAppointment(
      studentId: 'stu-demo-lucia-001',
      lessonDate: now,
      startTime: DateTime(now.year, now.month, now.day, 10),
      endTime: DateTime(now.year, now.month, now.day, 12),
      instructorName: 'Istruttore Test',
      lessonType: GuidanceLessonType.practiceSea,
      notes: 'Slot test ricerca telefono',
    );

    await tester.pumpWidget(
      _wrap(
        GuidanceAppointmentsDirectoryPage(
          embedded: true,
          onOpenStudent360: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final search = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          (w.decoration?.hintText?.toLowerCase().contains('allievo') ?? false),
    );
    expect(search, findsOneWidget);

    await _enterSearch(tester, search, '3200000001');
    // Appuntamento nella settimana corrente → nome visibile in agenda.
    expect(find.textContaining('Lucia'), findsWidgets);

    await _enterSearch(tester, search, '3999999999');
    expect(find.textContaining('Nessuna guida in elenco'), findsOneWidget);

    await _enterSearch(tester, search, 'Lucia');
    expect(find.textContaining('Lucia'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Contabilità: ricerca telefono non altera ricevuta/email', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      _wrap(
        AccountingPaymentsDirectoryPage(
          embedded: true,
          onOpenStudent360: (_, {int initialTabIndex = 0}) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final search = find.byType(TextField).first;

    await _enterSearch(tester, search, '3200000001');
    expect(find.textContaining('Lucia'), findsWidgets);
    expect(find.textContaining('Marco'), findsNothing);

    await _enterSearch(tester, search, '3999999999');
    expect(find.textContaining('Lucia Bianchi'), findsNothing);

    // Nome continua a funzionare (campo testuale, non solo telefono).
    await _enterSearch(tester, search, 'Lucia');
    expect(find.textContaining('Lucia'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
