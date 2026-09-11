import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/pages/welcome_page.dart';

void _drainKnownOverflow(WidgetTester tester) {
  Object? ex;
  while ((ex = tester.takeException()) != null) {
    expect('$ex', contains('overflowed'));
  }
}

Future<void> _pumpAt(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(const MaterialApp(home: WelcomePage()));
  await tester.pump();
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
  _drainKnownOverflow(tester);
}

Finder _discoverWhiteBackground() {
  return find.byWidgetPredicate(
    (w) => w is ColoredBox && w.color == Colors.white ||
        (w is Container &&
            w.color == Colors.white &&
            w.child is Center),
  );
}

Finder _discoverTitle() => find.text('Scoprici');

/// FRONT.7: Discover background sempre opaco (niente AnimatedOpacity 0 sull'intera sezione).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FRONT.7 Discover background sempre opaco', () {
    for (final size in const <Size>[
      Size(375, 812),
      Size(390, 844),
      Size(393, 852),
      Size(430, 932),
      Size(390, 700),
    ]) {
      testWidgets(
        '${size.width.toInt()}×${size.height.toInt()} — Scoprici + bianco al first frame',
        (tester) async {
          await _pumpAt(tester, size);

          // Titolo Discover presente subito (sezione non opacity 0).
          expect(_discoverTitle(), findsOneWidget);

          expect(_discoverWhiteBackground(), findsWidgets);

          // Nessun AnimatedOpacity che tiene l'intera Discover a 0.
          final zeroOpacityOverDiscover = find.ancestor(
            of: _discoverTitle(),
            matching: find.byWidgetPredicate(
              (w) => w is AnimatedOpacity && w.opacity == 0,
            ),
          );
          expect(zeroOpacityOverDiscover, findsNothing);
        },
      );
    }

    testWidgets('390×844 — scroll hero→Discover senza gap blu Scaffold', (
      tester,
    ) async {
      const size = Size(390, 844);
      await _pumpAt(tester, size);

      final scrollable = find
          .descendant(
            of: find.byWidgetPredicate(
              (w) =>
                  w is SingleChildScrollView &&
                  w.physics is ClampingScrollPhysics,
            ),
            matching: find.byType(Scrollable),
          )
          .first;

      final heroBoat = find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.gaplessPlayback == true,
      );
      expect(heroBoat, findsOneWidget);

      // Scroll fino a portare Discover nel viewport.
      await tester.drag(scrollable, Offset(0, -size.height * 0.85));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      _drainKnownOverflow(tester);

      final titleRect = tester.getRect(_discoverTitle());
      expect(titleRect.top, lessThan(size.height));
      expect(titleRect.bottom, greaterThan(0));

      // Background bianco Discover ancora presente (non Scaffold #123A5A).
      expect(_discoverWhiteBackground(), findsWidgets);
      expect(
        find.ancestor(
          of: _discoverTitle(),
          matching: find.byWidgetPredicate(
            (w) => w is AnimatedOpacity && w.opacity == 0,
          ),
        ),
        findsNothing,
      );
    });
  });
}
