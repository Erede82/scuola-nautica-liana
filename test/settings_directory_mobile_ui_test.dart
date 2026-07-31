import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/pages/backoffice/settings_directory_page.dart';

Future<void> _pumpSettings(WidgetTester tester, Size viewport) async {
  await tester.binding.setSurfaceSize(viewport);
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: viewport),
      child: const MaterialApp(
        home: Scaffold(body: SettingsDirectoryPage(embedded: true)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _assertSettingsResponsive(WidgetTester tester) async {
  expect(find.text('Impostazioni'), findsWidgets);
  expect(find.text('Prestazioni preimpostate'), findsOneWidget);
  expect(find.text('Nuova prestazione'), findsOneWidget);
  expect(find.text('Mostra non attive'), findsOneWidget);

  final titleRect = tester.getRect(find.text('Prestazioni preimpostate'));
  expect(titleRect.width, greaterThan(160));
  expect(titleRect.height, lessThan(48));

  expect(find.text('Patente nautica D1'), findsOneWidget);
  final last = find.text('Altro servizio nautico');
  expect(last, findsOneWidget);
  await tester.scrollUntilVisible(
    last,
    240,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  expect(last.hitTestable(), findsOneWidget);
  expect(tester.takeException(), isNull);
}

void main() {
  group('BO-MOBILE.2-A Impostazioni responsive', () {
    for (final size in const [
      Size(390, 844),
      Size(430, 932),
      Size(768, 1024),
      Size(1366, 768),
    ]) {
      testWidgets(
        '${size.width.toInt()}×${size.height.toInt()}: header e scroll senza overflow',
        (tester) async {
          await _pumpSettings(tester, size);
          await _assertSettingsResponsive(tester);
        },
      );
    }
  });
}
