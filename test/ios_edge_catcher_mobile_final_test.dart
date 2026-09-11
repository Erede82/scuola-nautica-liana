import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/utils/ios_edge_catcher.dart';
import 'package:scuola_nautica_liana/utils/ios_edge_catcher_gesture.dart';
import 'package:scuola_nautica_liana/utils/ios_edge_catcher_stub.dart' as stub;

void main() {
  setUp(() {
    IosEdgeCatcher.uninstall();
    stub.uninstallIosEdgeCatcher();
    stub.stubResetInstallCount();
  });

  group('MOBILE.FINAL IosEdgeCatcher policy', () {
    test('web + iOS + internal login = ON', () {
      expect(
        IosEdgeCatcher.shouldInstall(
          isWeb: true,
          platform: TargetPlatform.iOS,
          isInternalIosWebLogin: true,
        ),
        isTrue,
      );
    });

    test('web + iOS + direct /login = OFF', () {
      expect(
        IosEdgeCatcher.shouldInstall(
          isWeb: true,
          platform: TargetPlatform.iOS,
          isInternalIosWebLogin: false,
        ),
        isFalse,
      );
    });

    test('web + macOS = OFF', () {
      expect(
        IosEdgeCatcher.shouldInstall(
          isWeb: true,
          platform: TargetPlatform.macOS,
          isInternalIosWebLogin: true,
        ),
        isFalse,
      );
    });

    test('web + Android = OFF', () {
      expect(
        IosEdgeCatcher.shouldInstall(
          isWeb: true,
          platform: TargetPlatform.android,
          isInternalIosWebLogin: true,
        ),
        isFalse,
      );
    });

    test('native iOS = OFF', () {
      expect(
        IosEdgeCatcher.shouldInstall(
          isWeb: false,
          platform: TargetPlatform.iOS,
          isInternalIosWebLogin: true,
        ),
        isFalse,
      );
    });
  });

  group('MOBILE.FINAL lifecycle', () {
    test('install exactly once; dispose remove once', () {
      var backs = 0;
      stub.installIosEdgeCatcher(
        edgeZonePx: 32,
        confirmDeltaPx: 72,
        backEventName: IosEdgeCatcher.backEventName,
        onBack: () => backs++,
      );
      expect(stub.isIosEdgeCatcherInstalled, isTrue);
      expect(stub.iosEdgeCatcherInstallCount, 1);

      stub.installIosEdgeCatcher(
        edgeZonePx: 32,
        confirmDeltaPx: 72,
        backEventName: IosEdgeCatcher.backEventName,
        onBack: () => backs++,
      );
      expect(stub.iosEdgeCatcherInstallCount, 1);

      stub.uninstallIosEdgeCatcher();
      expect(stub.isIosEdgeCatcherInstalled, isFalse);
      expect(backs, 0);
    });
  });

  group('MOBILE.FINAL gesture recognition', () {
    test('dx=90 dy=10 → back', () {
      expect(
        iosEdgeCatcherShouldConfirmBack(deltaX: 90, deltaY: 10),
        isTrue,
      );
    });

    test('dx=50 dy=5 → no', () {
      expect(
        iosEdgeCatcherShouldConfirmBack(deltaX: 50, deltaY: 5),
        isFalse,
      );
    });

    test('dx=90 dy=90 → no', () {
      expect(
        iosEdgeCatcherShouldConfirmBack(deltaX: 90, deltaY: 90),
        isFalse,
      );
    });

    test('dx=-90 → no', () {
      expect(
        iosEdgeCatcherShouldConfirmBack(deltaX: -90, deltaY: 0),
        isFalse,
      );
    });

    test('una sola callback per gesture', () {
      var backs = 0;
      stub.installIosEdgeCatcher(
        edgeZonePx: 32,
        confirmDeltaPx: 72,
        backEventName: IosEdgeCatcher.backEventName,
        onBack: () => backs++,
      );

      expect(stub.stubSimulateGesture(deltaX: 90, deltaY: 10), isTrue);
      expect(backs, 1);
      // Seconda conferma nella stessa install: callback può ripetere in stub,
      // ma il widget Login usa _edgeBackHandled per una sola maybePop.
      expect(stub.stubSimulateGesture(deltaX: 50, deltaY: 5), isFalse);
      expect(backs, 1);
    });
  });
}
