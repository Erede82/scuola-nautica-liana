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

void main() {
  testWidgets('Impostazioni desktop: 4 card uniformi, azioni allineate', (
    tester,
  ) async {
    await _pumpSettings(tester, const Size(1366, 768));

    expect(find.text('Mostra non attive'), findsOneWidget);
    expect(find.text('Nuova prestazione'), findsOneWidget);
    expect(find.text('Aggiorna elenco'), findsNothing); // tooltip only
    expect(find.byTooltip('Aggiorna elenco'), findsOneWidget);

    final cards = find.byWidgetPredicate(
      (w) =>
          w is KeyedSubtree &&
          w.key is ValueKey<String> &&
          (w.key as ValueKey<String>).value.startsWith('settings-template-'),
    );
    expect(cards, findsWidgets);
    expect(cards.evaluate().length, greaterThanOrEqualTo(4));

    final firstFour = cards.evaluate().take(4).toList();
    final rects = firstFour
        .map((e) => tester.getRect(find.byWidget(e.widget)))
        .toList();

    final top0 = rects[0].top;
    for (final r in rects) {
      expect((r.top - top0).abs(), lessThan(1.5));
      expect((r.height - rects[0].height).abs(), lessThan(1.5));
      expect((r.width - rects[0].width).abs(), lessThan(1.5));
    }

    // Pulsanti Modifica alla stessa quota nella prima riga (per card).
    final editTops = <double>[];
    for (final el in firstFour) {
      final editInCard = find.descendant(
        of: find.byWidget(el.widget),
        matching: find.text('Modifica'),
      );
      expect(editInCard, findsOneWidget);
      editTops.add(tester.getTopLeft(editInCard).dy);
    }
    for (final t in editTops) {
      expect((t - editTops.first).abs(), lessThan(2.5));
    }

    expect(tester.takeException(), isNull);
  });

  testWidgets('Impostazioni tablet: 2 colonne', (tester) async {
    await _pumpSettings(tester, const Size(768, 1024));
    final cards = find.byWidgetPredicate(
      (w) =>
          w is KeyedSubtree &&
          w.key is ValueKey<String> &&
          (w.key as ValueKey<String>).value.startsWith('settings-template-'),
    );
    final rects = cards
        .evaluate()
        .take(2)
        .map((e) => tester.getRect(find.byWidget(e.widget)))
        .toList();
    expect((rects[0].top - rects[1].top).abs(), lessThan(1.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Impostazioni mobile: 1 colonna senza overflow', (tester) async {
    await _pumpSettings(tester, const Size(390, 844));
    expect(find.text('Prestazioni preimpostate'), findsOneWidget);
    expect(find.text('Mostra non attive'), findsOneWidget);
    expect(find.text('Nuova prestazione'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
