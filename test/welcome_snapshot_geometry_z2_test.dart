import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/constants/app_branding.dart';
import 'package:scuola_nautica_liana/pages/welcome_page.dart';
import 'package:scuola_nautica_liana/widgets/startup_visual_shell.dart';
import 'package:scuola_nautica_liana/widgets/welcome_static_shell_layout.dart';

Finder _logoImage() {
  return find.byWidgetPredicate(
    (w) =>
        w is Image &&
        w.image is AssetImage &&
        (w.image as AssetImage).assetName == AppBranding.logoMarkWhite,
  );
}

Finder _accediButton() =>
    find.widgetWithText(OutlinedButton, WelcomeStaticShellLayout.ctaAccedi);

Finder _forgotButton() =>
    find.widgetWithText(TextButton, WelcomeStaticShellLayout.ctaForgot);

Finder _scopriciButton() =>
    find.widgetWithText(OutlinedButton, WelcomeStaticShellLayout.ctaScoprici);

Rect _rect(WidgetTester tester, Finder finder) => tester.getRect(finder);

double _deltaY(Rect a, Rect b) => (a.top - b.top).abs();

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<Rect> _measureShell(
  WidgetTester tester,
  Size size,
  Finder target,
) async {
  await _setViewport(tester, size);
  await tester.pumpWidget(const MaterialApp(home: StartupVisualShell()));
  await tester.pump();
  return _rect(tester, target);
}

Future<Rect> _measureWelcome(
  WidgetTester tester,
  Size size,
  Finder target,
) async {
  await _setViewport(tester, size);
  await tester.pumpWidget(const MaterialApp(home: WelcomePage()));
  await tester.pump();
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
  return _rect(tester, target);
}

void _drainKnownOverflow(WidgetTester tester) {
  Object? ex;
  while ((ex = tester.takeException()) != null) {
    expect('$ex', contains('overflowed'));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PWA.7-Z2 shell ↔ Welcome geometry', () {
    testWidgets('390×844 — logo/Accedi/SCOPRICI entro 2px', (tester) async {
      const size = Size(390, 844);

      final shellLogo = await _measureShell(tester, size, _logoImage());
      final shellAccedi = await _measureShell(tester, size, _accediButton());
      final shellScoprici =
          await _measureShell(tester, size, _scopriciButton());

      final welcomeLogo = await _measureWelcome(tester, size, _logoImage());
      final welcomeAccedi = await _measureWelcome(tester, size, _accediButton());
      final welcomeScoprici =
          await _measureWelcome(tester, size, _scopriciButton());
      _drainKnownOverflow(tester);

      expect(
        _deltaY(shellLogo, welcomeLogo),
        lessThanOrEqualTo(2),
        reason: 'logo shell=${shellLogo.top} welcome=${welcomeLogo.top}',
      );
      expect(
        _deltaY(shellAccedi, welcomeAccedi),
        lessThanOrEqualTo(2),
        reason:
            'accedi shell=${shellAccedi.top} welcome=${welcomeAccedi.top}',
      );
      expect(
        _deltaY(shellScoprici, welcomeScoprici),
        lessThanOrEqualTo(2),
        reason:
            'scoprici shell=${shellScoprici.top} welcome=${welcomeScoprici.top}',
      );

      final shellForgot = await _measureShell(tester, size, _forgotButton());
      final welcomeForgot =
          await _measureWelcome(tester, size, _forgotButton());
      _drainKnownOverflow(tester);
      expect(
        _deltaY(shellForgot, welcomeForgot),
        lessThanOrEqualTo(2),
        reason:
            'forgot shell=${shellForgot.top} welcome=${welcomeForgot.top}',
      );
    });

    for (final size in <Size>[
      Size(375, 812),
      Size(430, 932),
      Size(390, 700),
    ]) {
      testWidgets(
        '${size.width.toInt()}×${size.height.toInt()} — no overflow, ordine CTA',
        (tester) async {
          await _setViewport(tester, size);
          await tester.pumpWidget(const MaterialApp(home: StartupVisualShell()));
          await tester.pump();
          expect(tester.takeException(), isNull);

          expect(find.text(WelcomeStaticShellLayout.ctaAccedi), findsOneWidget);
          expect(find.text(WelcomeStaticShellLayout.ctaScoprici), findsOneWidget);

          final logoTop = _rect(tester, _logoImage()).top;
          final accediTop = _rect(tester, _accediButton()).top;
          final scopriTop = _rect(tester, _scopriciButton()).top;
          expect(accediTop, greaterThan(logoTop));
          expect(scopriTop, greaterThan(_rect(tester, _forgotButton()).top));
        },
      );
    }
  });
}
