import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/staff/staff_school_role.dart';
import 'package:scuola_nautica_liana/pages/admin_home_page.dart';
import 'package:scuola_nautica_liana/services/staff_access_service.dart';

Future<void> _pumpAdmin(WidgetTester tester, Size viewport) async {
  staffAccessNotifier.value = StaffAccessSnapshot.initial().copyWith(
    isLoading: false,
    hasAuthSession: true,
    staffRole: StaffSchoolRole.schoolAdmin,
    clearError: true,
  );
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

Future<void> _scrollLastModuleIntoView(WidgetTester tester) async {
  // SliverGrid costruisce lazy: cerca per testo e scrolla finché compare.
  final last = find.text('Impostazioni');
  await tester.scrollUntilVisible(
    last,
    240,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('admin-module-settings')), findsOneWidget);
  expect(last.hitTestable(), findsOneWidget);
}

void main() {
  group('BO-UI.1 pannello amministrativo responsive', () {
    for (final size in const [Size(390, 844), Size(430, 932)]) {
      testWidgets(
        'mobile ${size.width.toInt()}×${size.height.toInt()}: scroll senza overflow',
        (tester) async {
          await _pumpAdmin(tester, size);

          expect(find.text('Pannello amministrativo'), findsOneWidget);
          expect(find.text('Moduli gestionali'), findsOneWidget);
          expect(find.text('Nuova pratica'), findsOneWidget);
          expect(find.text('Allievi'), findsOneWidget);
          expect(tester.takeException(), isNull);

          await _scrollLastModuleIntoView(tester);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('tablet 768×1024: moduli raggiungibili senza overflow', (
      tester,
    ) async {
      await _pumpAdmin(tester, const Size(768, 1024));

      expect(find.text('Pannello amministrativo'), findsOneWidget);
      expect(find.text('Nuova pratica'), findsOneWidget);
      expect(find.text('Allievi'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _scrollLastModuleIntoView(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('desktop 1366×768: header affiancato e moduli visibili', (
      tester,
    ) async {
      await _pumpAdmin(tester, const Size(1366, 768));

      expect(find.text('Pannello amministrativo'), findsOneWidget);
      expect(find.text('Moduli gestionali'), findsOneWidget);
      expect(find.text('Nuova pratica'), findsOneWidget);
      expect(find.text('Allievi'), findsOneWidget);
      expect(find.text('Impostazioni'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
