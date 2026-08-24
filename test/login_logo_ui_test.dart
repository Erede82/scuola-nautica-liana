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

void main() {
  for (final size in const [
    Size(390, 844),
    Size(430, 932),
    Size(768, 1024),
    Size(1366, 768),
    Size(1440, 900),
  ]) {
    testWidgets(
      'login mostra logo ufficiale a ${size.width.toInt()}×${size.height.toInt()}',
      (tester) async {
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
        });
        await tester.pumpAndSettle();

        expect(find.byType(LoginPage), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Image &&
                _usesBrandingAsset(widget, AppBranding.logoScuolaNauticaLianaBlue),
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
