import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/constants/app_branding.dart';
import 'package:scuola_nautica_liana/widgets/welcome_asset_hints.dart';

bool _isWelcomeBoatProvider(ImageProvider provider) {
  if (provider is AssetImage) {
    return provider.assetName == AppBranding.welcomeBoatJpg;
  }
  if (provider is ResizeImage && provider.imageProvider is AssetImage) {
    return (provider.imageProvider as AssetImage).assetName ==
        AppBranding.welcomeBoatJpg;
  }
  return false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FRONT.8 heroProvider identity', () {
    for (final size in const <Size>[
      Size(390, 844),
      Size(1440, 900),
    ]) {
      testWidgets(
        '${size.width.toInt()}×${size.height.toInt()} — same policy twice',
        (tester) async {
          late ImageProvider a;
          late ImageProvider b;
          late int? cacheW;

          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(size: size, devicePixelRatio: 1),
              child: Builder(
                builder: (context) {
                  cacheW = WelcomeAssetHints.heroCacheWidth(context);
                  a = WelcomeAssetHints.heroProvider(context);
                  b = WelcomeAssetHints.heroProvider(context);
                  return const SizedBox.shrink();
                },
              ),
            ),
          );

          expect(_isWelcomeBoatProvider(a), isTrue);
          expect(_isWelcomeBoatProvider(b), isTrue);

          if (size.width >= 900) {
            expect(cacheW, isNull);
            expect(a, isA<AssetImage>());
            expect(b, isA<AssetImage>());
            expect(
              (a as AssetImage).assetName,
              (b as AssetImage).assetName,
            );
          } else {
            expect(cacheW, isNotNull);
            expect(a, isA<ResizeImage>());
            expect(b, isA<ResizeImage>());
            expect((a as ResizeImage).width, cacheW);
            expect((b as ResizeImage).width, cacheW);
          }
        },
      );
    }
  });
}
