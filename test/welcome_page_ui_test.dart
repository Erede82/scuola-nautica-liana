import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/constants/app_branding.dart';
import 'package:scuola_nautica_liana/pages/login_page.dart';
import 'package:scuola_nautica_liana/pages/welcome_page.dart';

bool _usesBrandingAsset(Image widget, String assetName) {
  var provider = widget.image;
  if (provider is ResizeImage) {
    provider = provider.imageProvider;
  }
  return provider is AssetImage && provider.assetName == assetName;
}

void main() {
  test('welcome_boat.jpg ottimizzato entro target PWA mobile', () {
    final file = File('assets/images/welcome/welcome_boat.jpg');
    expect(file.existsSync(), isTrue);

    // Verifica leggera via dimensione file; il long side target è ~1700 px lato prod.
    final bytes = file.lengthSync();
    expect(bytes, lessThan(400 * 1024), reason: 'JPEG hero troppo pesante');
    expect(bytes, greaterThan(80 * 1024));
  });

  testWidgets('WelcomePage carica, precache e naviga al login', (tester) async {
    var loginTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: WelcomePage(
          onLoginTap: () => loginTapped = true,
        ),
        routes: {
          '/login': (_) => const LoginPage(),
        },
      ),
    );
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    });
    await tester.pumpAndSettle();

    expect(find.text('Accedi'), findsOneWidget);
    expect(find.text('Registrati'), findsOneWidget);
    expect(find.textContaining('Benvenuto'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            _usesBrandingAsset(widget, AppBranding.welcomeBoatJpg),
      ),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Accedi'));
    await tester.pumpAndSettle();
    expect(loginTapped, isTrue);
  });
}
