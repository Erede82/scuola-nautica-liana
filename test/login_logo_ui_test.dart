import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/constants/app_branding.dart';
import 'package:scuola_nautica_liana/pages/login_page.dart';

bool _usesBrandingAsset(Image widget, String assetName) {
  var provider = widget.image;
  if (provider is ResizeImage) {
    provider = provider.imageProvider;
  }
  return provider is AssetImage && provider.assetName == assetName;
}

Future<void> _pumpLogin(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size),
      child: const MaterialApp(home: LoginPage()),
    ),
  );
  await tester.pump();
  await tester.runAsync(() async {
    final ctx = tester.element(find.byType(LoginPage));
    await precacheImage(
      const AssetImage(AppBranding.logoScuolaNauticaLianaBlue),
      ctx,
    );
    await precacheImage(
      const AssetImage(AppBranding.logoScuolaNauticaLianaWhite),
      ctx,
    );
  });
  await tester.pumpAndSettle();
}

void main() {
  for (final size in const [Size(390, 844), Size(430, 932), Size(768, 1024)]) {
    testWidgets(
      'login mobile/tablet mostra logo blu a ${size.width.toInt()}×${size.height.toInt()}',
      (tester) async {
        await _pumpLogin(tester, size);

        expect(find.byType(LoginPage), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Image &&
                _usesBrandingAsset(
                  widget,
                  AppBranding.logoScuolaNauticaLianaBlue,
                ),
          ),
          findsWidgets,
        );
        expect(
          find.textContaining('Accedi con le credenziali'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('login_desktop_split')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final size in const [Size(1366, 768), Size(1440, 900)]) {
    testWidgets(
      'login desktop mostra brand panel + logo bianco a ${size.width.toInt()}×${size.height.toInt()}',
      (tester) async {
        await _pumpLogin(tester, size);

        expect(find.byKey(const Key('login_desktop_split')), findsOneWidget);
        expect(find.byKey(const Key('login_brand_panel')), findsOneWidget);
        expect(find.byKey(const Key('login_form_card')), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Image &&
                _usesBrandingAsset(
                  widget,
                  AppBranding.logoScuolaNauticaLianaWhite,
                ),
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining('Accedi con le credenziali'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
