import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/app_auth_gate.dart';
import 'package:scuola_nautica_liana/constants/app_branding.dart';
import 'package:scuola_nautica_liana/pages/welcome_page.dart';
import 'package:scuola_nautica_liana/widgets/startup_visual_shell.dart';
import 'package:scuola_nautica_liana/widgets/welcome_static_shell_layout.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const viewports = <Size>[
    Size(390, 844),
    Size(430, 932),
  ];

  Future<void> pumpShell(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: StartupVisualShell()),
    );
    await tester.pump();
  }

  void expectWelcomeCopyPresent() {
    expect(find.text(AppBranding.schoolName), findsOneWidget);
    expect(
      find.text(WelcomeStaticShellLayout.welcomeSubtitle),
      findsOneWidget,
    );
    expect(
      find.text(WelcomeStaticShellLayout.welcomeEditorial),
      findsOneWidget,
    );
    expect(find.text(WelcomeStaticShellLayout.ctaAccedi), findsOneWidget);
    expect(find.text(WelcomeStaticShellLayout.ctaRegistrati), findsOneWidget);
    expect(find.text(WelcomeStaticShellLayout.ctaForgot), findsOneWidget);
    expect(find.text(WelcomeStaticShellLayout.ctaScoprici), findsOneWidget);
  }

  group('StartupVisualShell Welcome-like (PWA.7-Z1)', () {
    for (final size in viewports) {
      testWidgets('renderizza copy completa ${size.width.toInt()}×${size.height.toInt()}',
          (tester) async {
        await pumpShell(tester, size);
        expectWelcomeCopyPresent();
        expect(find.byType(Image), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('logo in alto, non centrato verticalmente', (tester) async {
      await pumpShell(tester, const Size(390, 844));

      final logoFinder = find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName == AppBranding.logoMarkWhite,
      );
      expect(logoFinder, findsOneWidget);

      final logoBox = tester.getRect(logoFinder);
      final screenHeight = tester.getSize(find.byType(StartupVisualShell)).height;
      expect(logoBox.center.dy, lessThan(screenHeight * 0.45));
      expect(logoBox.left, lessThan(120));
    });

    testWidgets('titolo sotto il logo', (tester) async {
      await pumpShell(tester, const Size(390, 844));

      final logoFinder = find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName == AppBranding.logoMarkWhite,
      );
      final titleFinder = find.text(AppBranding.schoolName);
      final logoBottom = tester.getRect(logoFinder).bottom;
      final titleTop = tester.getRect(titleFinder).top;
      expect(titleTop, greaterThan(logoBottom));
    });

    testWidgets('CTA sotto i sottotitoli', (tester) async {
      await pumpShell(tester, const Size(390, 844));

      final editorialBottom = tester
          .getRect(find.text(WelcomeStaticShellLayout.welcomeEditorial))
          .bottom;
      final accediTop = tester
          .getRect(find.text(WelcomeStaticShellLayout.ctaAccedi))
          .top;
      expect(accediTop, greaterThan(editorialBottom));
    });

    testWidgets('SCOPRICI sotto Password dimenticata', (tester) async {
      await pumpShell(tester, const Size(390, 844));

      final forgotBottom = tester
          .getRect(find.text(WelcomeStaticShellLayout.ctaForgot))
          .bottom;
      final scopriTop = tester
          .getRect(find.text(WelcomeStaticShellLayout.ctaScoprici))
          .top;
      expect(scopriTop, greaterThan(forgotBottom));
    });

    testWidgets('shell non interattiva (IgnorePointer + button disabled)', (
      tester,
    ) async {
      await pumpShell(tester, const Size(390, 844));

      expect(find.byType(StartupVisualShell), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is IgnorePointer && w.ignoring,
        ),
        findsWidgets,
      );
      expect(
        find.ancestor(
          of: find.text(WelcomeStaticShellLayout.ctaAccedi),
          matching: find.byWidgetPredicate(
            (w) => w is IgnorePointer && w.ignoring,
          ),
        ),
        findsWidgets,
      );
    });
  });

  testWidgets('AppAuthGate senza sessione arriva a Welcome senza crash', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AppAuthGate()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(WelcomePage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
