import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/staff/staff_school_role.dart';
import 'package:scuola_nautica_liana/pages/admin_home_page.dart';
import 'package:scuola_nautica_liana/pages/backoffice/online_payments_admin_page.dart';
import 'package:scuola_nautica_liana/pages/backoffice/school_management_shell_page.dart';
import 'package:scuola_nautica_liana/services/staff_access_service.dart';
import 'package:scuola_nautica_liana/widgets/backoffice/backoffice_horizontal_section_bar.dart';

Future<void> _asAdmin() async {
  staffAccessNotifier.value = StaffAccessSnapshot.initial().copyWith(
    isLoading: false,
    hasAuthSession: true,
    staffRole: StaffSchoolRole.schoolAdmin,
    clearError: true,
  );
}

Future<void> _pumpAdmin(WidgetTester tester, Size viewport) async {
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
}

Future<void> _openModuleFromDashboard(
  WidgetTester tester, {
  required String moduleTitle,
}) async {
  await tester.tap(find.text(moduleTitle).first);
  await tester.pumpAndSettle();
}

void main() {
  group('BO-MOBILE.2-A drawer Esci', () {
    testWidgets('390×844: Esci centrato con icona in SafeArea', (tester) async {
      await _pumpAdmin(tester, const Size(390, 844));
      await tester.tap(find.byTooltip('Apri il menu'));
      await tester.pumpAndSettle();

      final logout = find.byKey(const ValueKey('admin-drawer-logout'));
      expect(logout, findsOneWidget);
      expect(
        find.descendant(of: logout, matching: find.text('Esci')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: logout,
          matching: find.byIcon(Icons.logout_rounded),
        ),
        findsOneWidget,
      );

      final logoutRect = tester.getRect(logout);
      final drawerWidth = tester.getSize(find.byType(Drawer)).width;
      expect((logoutRect.center.dx - drawerWidth / 2).abs(), lessThan(28));
      expect(logoutRect.bottom, lessThanOrEqualTo(844 + 1));
      expect(tester.takeException(), isNull);
    });
  });

  group('BO-MOBILE.2-A barra moduli', () {
    testWidgets('390×844: frecce presenti e swipe verso Impostazioni', (
      tester,
    ) async {
      await _pumpAdmin(tester, const Size(390, 844));
      await _openModuleFromDashboard(tester, moduleTitle: 'Allievi');
      expect(find.byType(BackofficeHorizontalSectionBar), findsOneWidget);

      final right = find.byKey(
        const ValueKey('backoffice-section-scroll-right'),
      );
      final left = find.byKey(const ValueKey('backoffice-section-scroll-left'));
      expect(right, findsOneWidget);
      expect(left, findsOneWidget);

      expect(tester.widget<IconButton>(left).onPressed, isNull);
      expect(tester.widget<IconButton>(right).onPressed, isNotNull);

      await tester.tap(right);
      await tester.pumpAndSettle();
      expect(tester.widget<IconButton>(left).onPressed, isNotNull);
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const ValueKey('admin-module-tab-practices')),
            )
            .selected,
        isTrue,
      );

      final settingsTab = find.byKey(
        const ValueKey('admin-module-tab-settings'),
      );
      await tester.scrollUntilVisible(
        settingsTab,
        160,
        scrollable: find.descendant(
          of: find.byType(BackofficeHorizontalSectionBar),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      expect(settingsTab.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('768×1024: frecce presenti se overflow', (tester) async {
      await _pumpAdmin(tester, const Size(768, 1024));
      await _openModuleFromDashboard(tester, moduleTitle: 'Allievi');
      expect(
        find.byKey(const ValueKey('backoffice-section-scroll-right')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('1366×768: navigazione moduli invariata', (tester) async {
      await _pumpAdmin(tester, const Size(1366, 768));
      await _openModuleFromDashboard(tester, moduleTitle: 'Allievi');
      expect(find.byType(BackofficeHorizontalSectionBar), findsOneWidget);
      expect(
        find.byKey(const ValueKey('admin-module-tab-students')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('admin-module-tab-practices')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('BO-MOBILE.2-A Allievi mobile', () {
    testWidgets('390×844: empty state assente, lista scrollabile', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(size: Size(390, 844)),
          child: MaterialApp(
            home: Scaffold(body: SchoolManagementShellPage(embedded: true)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Seleziona un allievo dalla lista'),
        findsNothing,
      );
      expect(find.textContaining('Dati letti dal database'), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Lucia Bianchi'), findsOneWidget);
      expect(find.text('Marco Verdi'), findsOneWidget);

      final last = find.text('Marco Verdi');
      await tester.ensureVisible(last);
      expect(last.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('1366×768: pannello dettaglio empty state presente', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1366, 768));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(size: Size(1366, 768)),
          child: MaterialApp(
            home: Scaffold(body: SchoolManagementShellPage(embedded: true)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Seleziona un allievo dalla lista'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('BO-MOBILE.2-A Pagamenti online', () {
    testWidgets('rimuove testi informativi e mantiene riepilogo', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: OnlinePaymentsAdminPage(embedded: true)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pagamenti online'), findsWidgets);
      expect(find.text('Riepilogo'), findsOneWidget);
      expect(find.text('Ordini in attesa'), findsOneWidget);
      expect(
        find.textContaining('Ordini online, link pagamento'),
        findsNothing,
      );
      expect(
        find.textContaining('Questa sezione non modifica Contabilità'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
