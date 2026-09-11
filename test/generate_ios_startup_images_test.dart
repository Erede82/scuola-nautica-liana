import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/constants/app_branding.dart';
import 'package:scuola_nautica_liana/widgets/startup_visual_shell.dart';
import 'package:scuola_nautica_liana/widgets/welcome_static_shell_layout.dart';

Finder _logo() => find.byWidgetPredicate(
      (w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName == AppBranding.logoMarkWhite,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('STARTUP.DECISIVE shell = Capri + logo 100 + title', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: StartupVisualShell()));
    await tester.pump();

    expect(WelcomeStaticShellLayout.fallbackBg, const Color(0xFF00BFFF));
    expect(WelcomeStaticShellLayout.startupLogoHeight, 100);
    expect(WelcomeStaticShellLayout.startupLogoToTitleGap, 24);

    expect(find.text(AppBranding.schoolName), findsOneWidget);
    final logo = tester.getRect(_logo());
    expect(logo.height, 100);
    final title = tester.getRect(find.text(AppBranding.schoolName));
    expect(title.top - logo.bottom, closeTo(24, 1));

    expect(find.text(WelcomeStaticShellLayout.ctaAccedi), findsNothing);
    expect(find.text(WelcomeStaticShellLayout.ctaScoprici), findsNothing);
    expect(
      find.byWidgetPredicate((w) {
        if (w is! Image) return false;
        final p = w.image;
        return p is AssetImage && p.assetName == AppBranding.welcomeBoatJpg;
      }),
      findsNothing,
    );
  });
}
