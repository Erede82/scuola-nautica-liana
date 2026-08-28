import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/pages/welcome_page.dart';

Widget _welcomeHarness() {
  return const MaterialApp(home: WelcomePage());
}

ScrollPosition _outerScrollPosition(WidgetTester tester) {
  final outer = find.byWidgetPredicate(
    (w) => w is SingleChildScrollView && w.physics is ClampingScrollPhysics,
  );
  final scrollable = find.descendant(
    of: outer,
    matching: find.byType(Scrollable),
  );
  return tester.state<ScrollableState>(scrollable.first).position;
}

Finder _outerScrollable() {
  final outer = find.byWidgetPredicate(
    (w) => w is SingleChildScrollView && w.physics is ClampingScrollPhysics,
  );
  return find.descendant(
    of: outer,
    matching: find.byType(Scrollable),
  ).first;
}

/// Container bianco Discover (padre diretto del titolo "Scoprici").
Finder _discoverWhiteContainer() {
  return find.ancestor(
    of: find.text('Scoprici'),
    matching: find.byWidgetPredicate(
      (w) => w is Container && w.color == Colors.white,
    ),
  ).first;
}

/// Container Journey (decoration con bordo superiore).
Finder _journeySectionContainer() {
  return find.ancestor(
    of: find.text('Il tuo percorso'),
    matching: find.byWidgetPredicate((w) {
      if (w is! Container) return false;
      final decoration = w.decoration;
      return decoration is BoxDecoration && decoration.border != null;
    }),
  ).first;
}

void _drainKnownOverflow(WidgetTester tester) {
  Object? ex;
  while ((ex = tester.takeException()) != null) {
    expect('$ex', contains('overflowed'));
  }
}

Future<void> _pumpWelcomeSettled(WidgetTester tester) async {
  await tester.pumpWidget(_welcomeHarness());
  await tester.pumpAndSettle();
  _drainKnownOverflow(tester);
}

Future<void> _tapScopriciAndCompleteAnimation(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(OutlinedButton, 'SCOPRICI'));
  await tester.pump();
  _drainKnownOverflow(tester);
  await tester.pump(const Duration(milliseconds: 50));
  _drainKnownOverflow(tester);
  await tester.pump(const Duration(milliseconds: 400));
  _drainKnownOverflow(tester);
  await tester.pump(const Duration(milliseconds: 400));
  _drainKnownOverflow(tester);
}

/// Tolleranza piccola: arrotondamenti layout/scroll e 1 frame residuo.
const double _scrollAlignTolerance = 4.0;

void main() {
  group('PWA.7-V-C1 SCOPRICI — allineamento Discover', () {
    for (final viewport in const [
      (390.0, 844.0, '390×844'),
      (440.0, 894.0, '440×894'),
    ]) {
      testWidgets(
        'tap SCOPRICI allinea Container Discover al top (${viewport.$3})',
        (tester) async {
          await tester.binding.setSurfaceSize(Size(viewport.$1, viewport.$2));
          addTearDown(() async {
            await tester.binding.setSurfaceSize(null);
          });

          await _pumpWelcomeSettled(tester);
          await _tapScopriciAndCompleteAnimation(tester);

          final scrollAfter = _outerScrollPosition(tester).pixels;
          final discoverTop = tester.getTopLeft(_discoverWhiteContainer()).dy;
          final delta = discoverTop.abs();
          debugPrint(
            '[V-C1 SCOPRICI ${viewport.$3}] scrollAfter=$scrollAfter '
            'discoverTop=${discoverTop.toStringAsFixed(1)} delta=$delta',
          );

          expect(
            delta,
            lessThanOrEqualTo(_scrollAlignTolerance),
            reason:
                'Top Container Discover deve coincidere col top viewport '
                '(tolleranza $_scrollAlignTolerance dp)',
          );

          // Titolo ≈ 36 px sotto l'inizio del bianco (padding compact).
          final titleTop = tester.getTopLeft(find.text('Scoprici')).dy;
          final titleOffsetFromWhite = titleTop - discoverTop;
          expect(titleOffsetFromWhite, closeTo(36.0, 2.0));
        },
      );

      testWidgets(
        'tap SCOPRICI — nessuna fascia hero significativa (${viewport.$3})',
        (tester) async {
          await tester.binding.setSurfaceSize(Size(viewport.$1, viewport.$2));
          addTearDown(() async {
            await tester.binding.setSurfaceSize(null);
          });

          await _pumpWelcomeSettled(tester);
          await _tapScopriciAndCompleteAnimation(tester);

          final accediRect = tester.getRect(find.text('Accedi'));
          // CTA hero deve essere completamente sopra la viewport visibile.
          expect(accediRect.bottom, lessThanOrEqualTo(_scrollAlignTolerance));

          final discoverTop = tester.getTopLeft(_discoverWhiteContainer()).dy;
          expect(discoverTop, lessThanOrEqualTo(_scrollAlignTolerance));
        },
      );
    }
  });

  group('PWA.7-V-C1 Journey — minHeight compact e footer Dove', () {
    for (final viewport in const [
      (390.0, 844.0, '390×844'),
      (440.0, 894.0, '440×894'),
    ]) {
      testWidgets(
        'Journey top-aligned — Dove fuori viewport (${viewport.$3})',
        (tester) async {
          await tester.binding.setSurfaceSize(Size(viewport.$1, viewport.$2));
          addTearDown(() async {
            await tester.binding.setSurfaceSize(null);
          });

          await _pumpWelcomeSettled(tester);

          await tester.scrollUntilVisible(
            _journeySectionContainer(),
            0.0,
            scrollable: _outerScrollable(),
          );
          await tester.pumpAndSettle();
          _drainKnownOverflow(tester);

          final journeyTop = tester.getTopLeft(_journeySectionContainer()).dy;
          expect(
            journeyTop.abs(),
            lessThanOrEqualTo(_scrollAlignTolerance),
            reason: 'Journey section allineata in alto',
          );

          final doveRect = tester.getRect(find.text('Dove'));
          expect(
            doveRect.top,
            greaterThanOrEqualTo(viewport.$2 - _scrollAlignTolerance),
            reason: 'Footer Dove deve stare sotto il fold',
          );
          debugPrint(
            '[V-C1 Journey ${viewport.$3}] journeyTop='
            '${journeyTop.toStringAsFixed(1)} doveTop='
            '${doveRect.top.toStringAsFixed(1)} viewportH=${viewport.$2}',
          );
        },
      );

      testWidgets(
        'scroll successivo — Dove diventa visibile (${viewport.$3})',
        (tester) async {
          await tester.binding.setSurfaceSize(Size(viewport.$1, viewport.$2));
          addTearDown(() async {
            await tester.binding.setSurfaceSize(null);
          });

          await _pumpWelcomeSettled(tester);

          await tester.scrollUntilVisible(
            _journeySectionContainer(),
            0.0,
            scrollable: _outerScrollable(),
          );
          await tester.pumpAndSettle();
          _drainKnownOverflow(tester);

          final position = _outerScrollPosition(tester);
          position.jumpTo(position.maxScrollExtent);
          await tester.pumpAndSettle();
          _drainKnownOverflow(tester);

          final doveRect = tester.getRect(find.text('Dove'));
          expect(doveRect.top, lessThan(viewport.$2));
          expect(find.text('Dove'), findsOneWidget);
        },
      );
    }
  });

  group('PWA.7-V-C1 desktop — Journey non artificialmente alta', () {
    testWidgets('1200×900 — minHeight compact non applicata', (tester) async {
      const desktopWidth = 1200.0;
      const desktopHeight = 900.0;

      await tester.binding.setSurfaceSize(
        const Size(desktopWidth, desktopHeight),
      );
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await _pumpWelcomeSettled(tester);

      final journeySize = tester.getSize(_journeySectionContainer());
      // Su desktop il contenuto naturale è ben sotto un viewport pieno forzato.
      expect(
        journeySize.height,
        lessThan(desktopHeight * 0.85),
        reason: 'Desktop non deve imporre minHeight ≈ viewport',
      );
      debugPrint(
        '[V-C1 desktop] journeyHeight=${journeySize.height.toStringAsFixed(1)} '
        'viewportH=$desktopHeight',
      );
    });
  });
}
