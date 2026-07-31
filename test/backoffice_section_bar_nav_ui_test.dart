import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/staff/staff_school_role.dart';
import 'package:scuola_nautica_liana/pages/admin_home_page.dart';
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

Future<void> _openAllievi(WidgetTester tester) async {
  await tester.tap(find.text('Allievi').first);
  await tester.pumpAndSettle();
}

Finder _barScrollable() {
  return find.descendant(
    of: find.byType(BackofficeHorizontalSectionBar),
    matching: find.byType(Scrollable),
  );
}

ScrollPosition _barPosition(WidgetTester tester) {
  return tester.state<ScrollableState>(_barScrollable()).position;
}

bool _chipSelected(WidgetTester tester, String kind) {
  final chip = tester.widget<ChoiceChip>(
    find.byKey(ValueKey<String>('admin-module-tab-$kind')),
  );
  return chip.selected;
}

/// Verifica che lo scroll sia già al migliore offset di centratura possibile.
void _expectBestEffortCentered(WidgetTester tester, Finder tab) {
  final pos = _barPosition(tester);
  final tabCenter = tester.getCenter(tab).dx;
  final viewportCenter = tester.getCenter(_barScrollable()).dx;
  final delta = tabCenter - viewportCenter;
  // Se siamo a sinistra del centro, dovremmo poter scorrere a destra (se c'è spazio).
  if (delta > 1.5) {
    expect(
      pos.pixels,
      closeTo(pos.maxScrollExtent, 2),
      reason: 'tab a destra del centro ma si poteva ancora scorrere',
    );
  } else if (delta < -1.5) {
    expect(
      pos.pixels,
      closeTo(0, 2),
      reason: 'tab a sinistra del centro ma si poteva ancora scorrere',
    );
  } else {
    expect(delta.abs(), lessThan(48));
  }
}

void main() {
  group('BO-MOBILE.4-A frecce navigano i moduli', () {
    testWidgets('390×844: frecce cambiano modulo e centrano', (tester) async {
      await _pumpAdmin(tester, const Size(390, 844));
      await _openAllievi(tester);

      expect(find.byType(BackofficeHorizontalSectionBar), findsOneWidget);
      expect(_chipSelected(tester, 'students'), isTrue);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Allievi'),
        ),
        findsOneWidget,
      );

      final left = find.byKey(const ValueKey('backoffice-section-scroll-left'));
      final right = find.byKey(
        const ValueKey('backoffice-section-scroll-right'),
      );
      expect(left, findsOneWidget);
      expect(right, findsOneWidget);
      expect(tester.widget<IconButton>(left).onPressed, isNull);
      expect(tester.widget<IconButton>(right).onPressed, isNotNull);
      expect(tester.widget<IconButton>(right).tooltip, 'Apri Pratiche');
      expect(_barPosition(tester).pixels, closeTo(0, 1));

      await tester.tap(right);
      await tester.pumpAndSettle();

      expect(_chipSelected(tester, 'practices'), isTrue);
      expect(_chipSelected(tester, 'students'), isFalse);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Pratiche'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Elenco fascicoli'), findsOneWidget);
      expect(tester.widget<IconButton>(left).onPressed, isNotNull);
      expect(tester.widget<IconButton>(left).tooltip, 'Apri Allievi');
      expect(tester.widget<IconButton>(right).tooltip, 'Apri Guide / Agenda');

      // Sezione attiva portata il più possibile al centro (con clamp).
      final practicesTab = find.byKey(
        const ValueKey('admin-module-tab-practices'),
      );
      _expectBestEffortCentered(tester, practicesTab);

      await tester.tap(right);
      await tester.pumpAndSettle();
      expect(_chipSelected(tester, 'agenda'), isTrue);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Guide / Agenda'),
        ),
        findsOneWidget,
      );

      await tester.tap(left);
      await tester.pumpAndSettle();
      expect(_chipSelected(tester, 'practices'), isTrue);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Pratiche'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('390×844: prima e ultima sezione agli estremi', (tester) async {
      await _pumpAdmin(tester, const Size(390, 844));
      await _openAllievi(tester);

      expect(_barPosition(tester).pixels, closeTo(0, 1));

      final settingsTab = find.byKey(
        const ValueKey('admin-module-tab-settings'),
      );
      await tester.scrollUntilVisible(
        settingsTab,
        160,
        scrollable: _barScrollable(),
      );
      await tester.pumpAndSettle();
      await tester.tap(settingsTab);
      await tester.pumpAndSettle();

      expect(_chipSelected(tester, 'settings'), isTrue);
      final pos = _barPosition(tester);
      expect(pos.pixels, closeTo(pos.maxScrollExtent, 2));

      final right = find.byKey(
        const ValueKey('backoffice-section-scroll-right'),
      );
      final left = find.byKey(const ValueKey('backoffice-section-scroll-left'));
      expect(tester.widget<IconButton>(right).onPressed, isNull);
      expect(tester.widget<IconButton>(left).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('390×844: tap diretto su tab lontana centra e naviga', (
      tester,
    ) async {
      await _pumpAdmin(tester, const Size(390, 844));
      await _openAllievi(tester);

      final accountingTab = find.byKey(
        const ValueKey('admin-module-tab-accounting'),
      );
      await tester.scrollUntilVisible(
        accountingTab,
        160,
        scrollable: _barScrollable(),
      );
      await tester.pumpAndSettle();
      await tester.tap(accountingTab);
      await tester.pumpAndSettle();

      expect(_chipSelected(tester, 'accounting'), isTrue);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Contabilità'),
        ),
        findsOneWidget,
      );

      _expectBestEffortCentered(tester, accountingTab);
      expect(tester.takeException(), isNull);
    });

    testWidgets('390×844: swipe manuale non cambia modulo', (tester) async {
      await _pumpAdmin(tester, const Size(390, 844));
      await _openAllievi(tester);

      expect(_chipSelected(tester, 'students'), isTrue);
      final before = _barPosition(tester).pixels;

      await tester.drag(_barScrollable(), const Offset(-140, 0));
      await tester.pumpAndSettle();

      expect(_chipSelected(tester, 'students'), isTrue);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Allievi'),
        ),
        findsOneWidget,
      );
      expect(_barPosition(tester).pixels, greaterThan(before));
      expect(tester.takeException(), isNull);
    });
  });

  group('BO-MOBILE.4-A tablet e desktop', () {
    testWidgets('768×1024: frecce navigano e centrano', (tester) async {
      await _pumpAdmin(tester, const Size(768, 1024));
      await _openAllievi(tester);

      final right = find.byKey(
        const ValueKey('backoffice-section-scroll-right'),
      );
      expect(right, findsOneWidget);

      await tester.tap(right);
      await tester.pumpAndSettle();
      expect(_chipSelected(tester, 'practices'), isTrue);

      final practicesTab = find.byKey(
        const ValueKey('admin-module-tab-practices'),
      );
      _expectBestEffortCentered(tester, practicesTab);

      await tester.drag(_barScrollable(), const Offset(-100, 0));
      await tester.pumpAndSettle();
      expect(_chipSelected(tester, 'practices'), isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('1366×768: tap diretto invariato; frecce se overflow', (
      tester,
    ) async {
      await _pumpAdmin(tester, const Size(1366, 768));
      await _openAllievi(tester);

      expect(find.byType(BackofficeHorizontalSectionBar), findsOneWidget);

      final right = find.byKey(
        const ValueKey('backoffice-section-scroll-right'),
      );
      final left = find.byKey(const ValueKey('backoffice-section-scroll-left'));
      final overflows = right.evaluate().isNotEmpty;
      if (overflows) {
        expect(left, findsOneWidget);
        expect(tester.widget<IconButton>(left).onPressed, isNull);
        expect(tester.widget<IconButton>(right).onPressed, isNotNull);

        await tester.tap(right);
        await tester.pumpAndSettle();
        expect(_chipSelected(tester, 'practices'), isTrue);
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text('Pratiche'),
          ),
          findsOneWidget,
        );
        _expectBestEffortCentered(
          tester,
          find.byKey(const ValueKey('admin-module-tab-practices')),
        );
      } else {
        expect(left, findsNothing);
        await tester.tap(
          find.byKey(const ValueKey('admin-module-tab-practices')),
        );
        await tester.pumpAndSettle();
        expect(_chipSelected(tester, 'practices'), isTrue);
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text('Pratiche'),
          ),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
    });
  });
}
