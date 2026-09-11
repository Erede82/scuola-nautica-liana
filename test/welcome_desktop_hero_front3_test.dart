import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/constants/app_branding.dart';
import 'package:scuola_nautica_liana/pages/welcome_page.dart';
import 'package:scuola_nautica_liana/widgets/welcome_static_shell_layout.dart';

/// Hero boat: unica Image welcome_boat con gaplessPlayback (FRONT.2).
Finder _heroBoatImage() {
  return find.byWidgetPredicate(
    (w) =>
        w is Image &&
        w.gaplessPlayback &&
        w.image is AssetImage &&
        (w.image as AssetImage).assetName == AppBranding.welcomeBoatJpg,
  );
}

Finder _logoImage() {
  return find.byWidgetPredicate(
    (w) =>
        w is Image &&
        w.image is AssetImage &&
        (w.image as AssetImage).assetName == AppBranding.logoMarkWhite,
  );
}

Finder _heroTitle() {
  return find.byWidgetPredicate(
    (w) =>
        w is Text &&
        w.data == AppBranding.schoolName &&
        (w.style?.fontSize ?? 0) >= 40,
  );
}

Future<void> _pumpWelcome(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(const MaterialApp(home: WelcomePage()));
  await tester.pump();
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
  Object? ex;
  while ((ex = tester.takeException()) != null) {
    expect('$ex', contains('overflowed'));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FRONT.3 desktop hero full viewport', () {
    for (final size in const <Size>[
      Size(1366, 768),
      Size(1440, 900),
      Size(1920, 1080),
    ]) {
      testWidgets(
        '${size.width.toInt()}×${size.height.toInt()} — hero == viewport',
        (tester) async {
          await _pumpWelcome(tester, size);
          final boat = tester.getRect(_heroBoatImage());
          expect(boat.height, size.height);
          expect(boat.bottom, size.height);
        },
      );
    }

    testWidgets('1200×700 — hero == 760, scroll disponibile', (tester) async {
      const size = Size(1200, 700);
      await _pumpWelcome(tester, size);
      final boat = tester.getRect(_heroBoatImage());
      expect(boat.height, 760);
      expect(tester.takeException(), isNull);
      expect(find.byType(Scrollable), findsWidgets);
    });
  });

  group('FRONT.FINAL desktop logo legato al titolo', () {
    for (final size in const <Size>[
      Size(1366, 768),
      Size(1440, 900),
      Size(1920, 1080),
    ]) {
      testWidgets(
        '${size.width.toInt()}×${size.height.toInt()} — gap logo→title ≈28',
        (tester) async {
          await _pumpWelcome(tester, size);
          final logo = tester.getRect(_logoImage());
          final title = tester.getRect(_heroTitle());
          final gap = title.top - logo.bottom;

          expect(logo.height, WelcomeStaticShellLayout.desktopLogoHeight);
          expect(
            (logo.center.dx - size.width / 2).abs(),
            lessThanOrEqualTo(1),
          );
          expect(gap, inInclusiveRange(26, 32));
          expect(title.top, greaterThan(logo.bottom));
        },
      );
    }
  });

  group('FRONT.FINAL copy frozen (title centerY)', () {
    for (final size in const <Size>[
      Size(1440, 900),
      Size(1920, 1080),
    ]) {
      testWidgets(
        '${size.width.toInt()}×${size.height.toInt()} — cta area FRONT.8',
        (tester) async {
          await _pumpWelcome(tester, size);

          final logo = tester.getRect(_logoImage());
          final title = tester.getRect(_heroTitle());
          final scoprici = tester.getRect(
            find.widgetWithText(
              OutlinedButton,
              WelcomeStaticShellLayout.ctaScoprici,
            ),
          );

          expect(title.top, greaterThan(logo.bottom));

          const vp = WelcomeStaticShellLayout.desktopVerticalPadding;
          final contentTop = vp +
              WelcomeStaticShellLayout.desktopLogoHeight +
              WelcomeStaticShellLayout.desktopLogoToCopyGap;
          final contentBottom = size.height - vp;
          final expectedCenterY = (contentTop + contentBottom) / 2;
          final ctaColumnCenterY = (title.top + scoprici.bottom) / 2;

          expect(
            (ctaColumnCenterY - expectedCenterY).abs(),
            lessThanOrEqualTo(2),
            reason:
                'ctaCenter=$ctaColumnCenterY expected=$expectedCenterY '
                'title.top=${title.top}',
          );
        },
      );
    }
  });

  group('FRONT.7 mobile logo frozen', () {
    testWidgets('390×844 — logo 70, top = padding compact 20', (tester) async {
      const size = Size(390, 844);
      await _pumpWelcome(tester, size);
      final logo = tester.getRect(_logoImage());
      expect(logo.height, 70);
      expect(logo.top, greaterThanOrEqualTo(20));
      expect((logo.center.dx - size.width / 2).abs(), lessThanOrEqualTo(1));
    });

    testWidgets('390×700 — logo 56 (cramped)', (tester) async {
      const size = Size(390, 700);
      await _pumpWelcome(tester, size);
      final logo = tester.getRect(_logoImage());
      expect(logo.height, 56);
      expect((logo.center.dx - size.width / 2).abs(), lessThanOrEqualTo(1));
    });
  });
}
