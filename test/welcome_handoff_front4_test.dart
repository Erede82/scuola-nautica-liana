import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/constants/app_branding.dart';
import 'package:scuola_nautica_liana/widgets/startup_visual_shell.dart';
import 'package:scuola_nautica_liana/widgets/welcome_static_shell_layout.dart';

/// STARTUP.DECISIVE: shell = Capri + logo + title; Welcome = unica hero + UI.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'STARTUP.DECISIVE — shell desktop/mobile Capri+logo+title senza boat/CTA',
    (tester) async {
      for (final size in const <Size>[
        Size(390, 844),
        Size(1440, 900),
      ]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        await tester.pumpWidget(const MaterialApp(home: StartupVisualShell()));
        await tester.pump();

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
            if (provider is ResizeImage &&
                provider.imageProvider is AssetImage) {
              return (provider.imageProvider as AssetImage).assetName ==
                  AppBranding.welcomeBoatJpg;
            }
            return false;
          }),
          findsNothing,
        );
        expect(find.text(WelcomeStaticShellLayout.ctaAccedi), findsNothing);
        expect(find.text(WelcomeStaticShellLayout.ctaScoprici), findsNothing);
      }
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    },
  );
}
