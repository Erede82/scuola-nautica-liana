import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/app_auth_gate.dart';
import 'package:scuola_nautica_liana/constants/app_branding.dart';
import 'package:scuola_nautica_liana/pages/welcome_page.dart';
import 'package:scuola_nautica_liana/widgets/startup_visual_shell.dart';
import 'package:scuola_nautica_liana/widgets/welcome_static_shell_layout.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  group('StartupVisualShell STARTUP.DECISIVE — Capri + logo + title', () {
    testWidgets('fondo Capri + logo + titolo, boat e CTA assenti', (
      tester,
    ) async {
      await pumpShell(tester, const Size(390, 844));

      expect(WelcomeStaticShellLayout.fallbackBg, const Color(0xFF00BFFF));
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is ColoredBox &&
              w.color == WelcomeStaticShellLayout.fallbackBg,
        ),
        findsWidgets,
      );
      expect(find.text(AppBranding.schoolName), findsOneWidget);

      expect(
        find.byWidgetPredicate((w) {
          if (w is! Image) return false;
          final provider = w.image;
          if (provider is AssetImage) {
            return provider.assetName == AppBranding.welcomeBoatJpg;
          }
          if (provider is ResizeImage && provider.imageProvider is AssetImage) {
            return (provider.imageProvider as AssetImage).assetName ==
                AppBranding.welcomeBoatJpg;
          }
          return false;
        }),
        findsNothing,
      );

      expect(find.text(WelcomeStaticShellLayout.ctaAccedi), findsNothing);
      expect(find.text(WelcomeStaticShellLayout.ctaScoprici), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shell non interattiva (IgnorePointer)', (tester) async {
      await pumpShell(tester, const Size(390, 844));
      expect(find.byType(StartupVisualShell), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is IgnorePointer && w.ignoring),
        findsWidgets,
      );
    });
  });

  testWidgets('WelcomePage reale mostra boat + foreground completa', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: WelcomePage()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.byWidgetPredicate((w) {
        if (w is! Image) return false;
        final provider = w.image;
        if (provider is AssetImage) {
          return provider.assetName == AppBranding.welcomeBoatJpg;
        }
        if (provider is ResizeImage && provider.imageProvider is AssetImage) {
          return (provider.imageProvider as AssetImage).assetName ==
              AppBranding.welcomeBoatJpg;
        }
        return false;
      }),
      findsWidgets,
    );
    expect(find.text(WelcomeStaticShellLayout.ctaAccedi), findsOneWidget);
    expect(find.text(WelcomeStaticShellLayout.ctaScoprici), findsOneWidget);
  });

  testWidgets(
    'AppAuthGate: bootstrap → shell Capri; poi Welcome dopo hero ready',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final warmup = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: AppAuthGate(
            heroWarmupOverride: (_) => warmup.future,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(StartupVisualShell), findsOneWidget);
      expect(find.byType(WelcomePage), findsNothing);

      warmup.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(StartupVisualShell), findsNothing);
      expect(find.byType(WelcomePage), findsOneWidget);
    },
  );
}
