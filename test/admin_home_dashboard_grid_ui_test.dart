import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/staff/staff_school_role.dart';
import 'package:scuola_nautica_liana/pages/admin_home_page.dart';
import 'package:scuola_nautica_liana/services/staff_access_service.dart';

const _moduleKeys = [
  'admin-module-students',
  'admin-module-practices',
  'admin-module-agenda',
  'admin-module-accounting',
  'admin-module-onlinePayments',
  'admin-module-studyAccess',
  'admin-module-videoCourses',
  'admin-module-settings',
];

const _pageHorizontalPadding = 16.0;

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

/// Colonne della prima riga dai widget attualmente costruiti (vista iniziale).
int _columnCountFromVisible(WidgetTester tester) {
  final first = tester.getRect(
    find.byKey(const ValueKey<String>('admin-module-students')),
  );
  var columns = 0;
  for (final k in _moduleKeys) {
    final finder = find.byKey(ValueKey<String>(k));
    if (finder.evaluate().isEmpty) break;
    final r = tester.getRect(finder);
    if ((r.top - first.top).abs() < 1.5) {
      columns++;
    } else {
      break;
    }
  }
  return columns;
}

/// Rect di tutte e 8 le card; richiede che siano tutte nel tree (desktop/tablet).
List<Rect> _allModuleRects(WidgetTester tester) {
  return [
    for (final k in _moduleKeys)
      tester.getRect(find.byKey(ValueKey<String>(k))),
  ];
}

void _expectUniformCardSizes(List<Rect> rects) {
  final w0 = rects.first.width;
  final h0 = rects.first.height;
  for (var i = 0; i < rects.length; i++) {
    expect((rects[i].width - w0).abs(), lessThan(1.5), reason: 'larghezza $i');
    expect((rects[i].height - h0).abs(), lessThan(1.5), reason: 'altezza $i');
  }
}

void _expectFourByTwo(List<Rect> rects) {
  expect(rects, hasLength(8));
  final row1Y = rects[0].top;
  final row2Y = rects[4].top;
  expect(row2Y, greaterThan(row1Y + 40));
  for (var i = 0; i < 4; i++) {
    expect(
      (rects[i].top - row1Y).abs(),
      lessThan(1.5),
      reason: 'card $i non in riga 1',
    );
    expect(
      (rects[i + 4].top - row2Y).abs(),
      lessThan(1.5),
      reason: 'card ${i + 4} non in riga 2',
    );
  }
  _expectUniformCardSizes(rects);
}

void _expectWideDesktopGrid(List<Rect> rects, Size size) {
  _expectFourByTwo(rects);

  final gridLeft = rects[0].left;
  final gridRight = rects[3].right;
  final gridWidth = gridRight - gridLeft;
  final expectedInner = size.width - _pageHorizontalPadding * 2;
  expect(gridWidth, closeTo(expectedInner, 2));

  final leftMargin = gridLeft;
  final rightMargin = size.width - gridRight;
  expect((leftMargin - rightMargin).abs(), lessThan(2));
  expect(gridWidth / size.width, greaterThan(0.88));

  expect(rects.first.width, greaterThan(280));
  expect(rects.first.height, greaterThan(155));
}

/// Griglia che usa gran parte dell'altezza viewport: fondo griglia alto,
/// spazio residuo sotto contenuto ridotto (<= ~70 px).
void _expectTallDesktopFill(List<Rect> rects, Size size) {
  _expectWideDesktopGrid(rects, size);

  final cardH = rects.first.height;
  final bodyHeight = size.height - kToolbarHeight;
  final expectedCard = AdminHomePage.moduleMainAxisExtent(
    columns: 4,
    bodyHeight: bodyHeight,
  );
  expect(cardH, closeTo(expectedCard, 4));
  expect(cardH, greaterThan(180));
  expect(cardH, lessThanOrEqualTo(482));

  final gridBottom = rects[4].bottom;
  final unusedBelow = size.height - gridBottom;

  expect(
    gridBottom / size.height,
    greaterThan(0.88),
    reason: 'grid bottom troppo basso rispetto alla viewport',
  );
  expect(
    unusedBelow,
    lessThanOrEqualTo(70),
    reason: 'troppo spazio vuoto sotto la griglia ($unusedBelow px)',
  );

  expect(find.text('Nuova pratica'), findsOneWidget);
  expect(find.text('Moduli gestionali'), findsOneWidget);
}

void main() {
  group('confini breakpoint viewport', () {
    for (final case_ in const [
      (Size(619, 900), 1),
      (Size(620, 900), 2),
      (Size(979, 900), 2),
      (Size(980, 900), 4),
    ]) {
      final size = case_.$1;
      final expectedCols = case_.$2;
      testWidgets(
        'viewport ${size.width.toInt()}×${size.height.toInt()} → $expectedCols colonne',
        (tester) async {
          await _pumpAdmin(tester, size);

          final cols = _columnCountFromVisible(tester);
          expect(cols, expectedCols);

          if (expectedCols == 4) {
            final rects = _allModuleRects(tester);
            _expectFourByTwo(rects);
            expect(rects.first.width, greaterThan(190));
            expect(rects.first.height, greaterThan(120));
            expect(find.text('Allievi'), findsOneWidget);
            expect(find.text('Pratiche'), findsOneWidget);
          } else if (expectedCols == 2) {
            final r0 = tester.getRect(
              find.byKey(const ValueKey('admin-module-students')),
            );
            final r1 = tester.getRect(
              find.byKey(const ValueKey('admin-module-practices')),
            );
            expect((r0.top - r1.top).abs(), lessThan(1.5));
            expect(r1.left, greaterThan(r0.right));
            final r2 = tester.getRect(
              find.byKey(const ValueKey('admin-module-agenda')),
            );
            expect(r2.top, greaterThan(r0.top + 40));
          } else {
            final r0 = tester.getRect(
              find.byKey(const ValueKey('admin-module-students')),
            );
            final r1 = tester.getRect(
              find.byKey(const ValueKey('admin-module-practices')),
            );
            expect(r1.top, greaterThan(r0.top + 40));
            expect((r0.left - r1.left).abs(), lessThan(1.5));
          }

          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  for (final size in const [
    Size(1366, 768),
    Size(1440, 900),
    Size(1512, 982),
    Size(1728, 1117),
    Size(1920, 1080),
  ]) {
    testWidgets(
      'dashboard desktop ${size.width.toInt()}×${size.height.toInt()}: 4×2 ampia e alta',
      (tester) async {
        await _pumpAdmin(tester, size);
        expect(_columnCountFromVisible(tester), 4);

        final rects = _allModuleRects(tester);
        _expectTallDesktopFill(rects, size);

        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('dashboard tablet: 2 colonne altezza compatta', (tester) async {
    await _pumpAdmin(tester, const Size(768, 1024));
    expect(_columnCountFromVisible(tester), 2);
    final r0 = tester.getRect(
      find.byKey(const ValueKey('admin-module-students')),
    );
    final r1 = tester.getRect(
      find.byKey(const ValueKey('admin-module-practices')),
    );
    expect((r0.top - r1.top).abs(), lessThan(1.5));
    expect(r0.height, lessThan(180));
    final r2 = tester.getRect(
      find.byKey(const ValueKey('admin-module-agenda')),
    );
    expect(r2.top, greaterThan(r0.top + 40));
    expect(tester.takeException(), isNull);
  });

  for (final size in const [Size(390, 844), Size(430, 932)]) {
    testWidgets('dashboard mobile ${size.width.toInt()}: 1 colonna compatta', (
      tester,
    ) async {
      await _pumpAdmin(tester, size);
      expect(_columnCountFromVisible(tester), 1);
      final r0 = tester.getRect(
        find.byKey(const ValueKey('admin-module-students')),
      );
      final r1 = tester.getRect(
        find.byKey(const ValueKey('admin-module-practices')),
      );
      expect(r1.top, greaterThan(r0.top + 40));
      // Non metà schermo: altezza naturale/compatta.
      expect(r0.height, lessThan(size.height * 0.28));
      expect(tester.takeException(), isNull);
    });
  }

  test('formula altezza desktop: clamp 156–480 e cresce col body', () {
    final short = AdminHomePage.moduleMainAxisExtent(
      columns: 4,
      bodyHeight: 500,
    );
    final mid = AdminHomePage.moduleMainAxisExtent(columns: 4, bodyHeight: 700);
    final tall = AdminHomePage.moduleMainAxisExtent(
      columns: 4,
      bodyHeight: 1200,
    );
    expect(short, greaterThanOrEqualTo(156));
    expect(mid, greaterThan(short));
    expect(tall, greaterThan(mid));
    expect(tall, lessThanOrEqualTo(480));
    // Desktop alti tipici (≈1080 body≈1024) non devono essere bloccati a 310.
    final fullHdBody = AdminHomePage.moduleMainAxisExtent(
      columns: 4,
      bodyHeight: 1024,
    );
    expect(fullHdBody, greaterThan(400));
    expect(
      AdminHomePage.moduleMainAxisExtent(columns: 2, bodyHeight: 900),
      152,
    );
    expect(
      AdminHomePage.moduleMainAxisExtent(columns: 1, bodyHeight: 900),
      136,
    );
  });
}
