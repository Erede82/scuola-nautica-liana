import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/utils/login_navigation_policy.dart';

void main() {
  group('FRONT.8 shouldUseInternalLoginRoute', () {
    test('web + iOS = true', () {
      expect(
        shouldUseInternalLoginRoute(
          isWeb: true,
          platform: TargetPlatform.iOS,
        ),
        isTrue,
      );
    });

    test('web + macOS = false', () {
      expect(
        shouldUseInternalLoginRoute(
          isWeb: true,
          platform: TargetPlatform.macOS,
        ),
        isFalse,
      );
    });

    test('web + Android = false', () {
      expect(
        shouldUseInternalLoginRoute(
          isWeb: true,
          platform: TargetPlatform.android,
        ),
        isFalse,
      );
    });

    test('native iOS = false', () {
      expect(
        shouldUseInternalLoginRoute(
          isWeb: false,
          platform: TargetPlatform.iOS,
        ),
        isFalse,
      );
    });
  });
}
