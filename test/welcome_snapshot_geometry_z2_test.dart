import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/constants/app_branding.dart';
import 'package:scuola_nautica_liana/pages/welcome_page.dart';
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

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void _drainKnownOverflow(WidgetTester tester) {
  Object? ex;
  while ((ex = tester.takeException()) != null) {
    expect('$ex', contains('overflowed'));
  }
}

/// FRONT.6: Z2 shell↔Welcome geometry SUPERATA (shell = solo navy).
/// Restano sole verifiche sulla Welcome reale.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PWA.7-Z2 Welcome geometry (FRONT.6 — no shell hero)', () {
    testWidgets('390×844 — logo centerX + ordine CTA sulla Welcome', (
      tester,
    ) async {
      const size = Size(390, 844);
      await _setViewport(tester, size);
      await tester.pumpWidget(const MaterialApp(home: WelcomePage()));
      await tester.pump();
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      _drainKnownOverflow(tester);

      final logo = _rect(tester, _logoImage());
      final accedi = _rect(tester, _accediButton());
      final forgot = _rect(tester, _forgotButton());
      final scoprici = _rect(tester, _scopriciButton());

      expect((logo.center.dx - size.width / 2).abs(), lessThanOrEqualTo(1));
      expect(accedi.top, greaterThan(logo.bottom));
      expect(forgot.top, greaterThan(accedi.bottom));
      expect(scoprici.top, greaterThan(forgot.bottom));
    });

    for (final size in <Size>[
      Size(375, 812),
      Size(393, 852),
      Size(430, 932),
      Size(390, 700),
    ]) {
      testWidgets(
        '${size.width.toInt()}×${size.height.toInt()} — logo centerX ≤ 1px',
        (tester) async {
          await _setViewport(tester, size);
          await tester.pumpWidget(const MaterialApp(home: WelcomePage()));
          await tester.pump();
          await tester.pumpAndSettle(const Duration(milliseconds: 100));
          _drainKnownOverflow(tester);

          final logo = _rect(tester, _logoImage());
          expect(
            (logo.center.dx - size.width / 2).abs(),
            lessThanOrEqualTo(1),
          );
        },
      );
    }

    for (final size in <Size>[
      Size(375, 812),
      Size(430, 932),
      Size(390, 700),
    ]) {
      testWidgets(
        '${size.width.toInt()}×${size.height.toInt()} — ordine CTA Welcome',
        (tester) async {
          await _setViewport(tester, size);
          await tester.pumpWidget(const MaterialApp(home: WelcomePage()));
          await tester.pump();
          await tester.pumpAndSettle(const Duration(milliseconds: 100));
          _drainKnownOverflow(tester);

          expect(find.text(WelcomeStaticShellLayout.ctaAccedi), findsOneWidget);
          expect(
            find.text(WelcomeStaticShellLayout.ctaScoprici),
            findsOneWidget,
          );

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
