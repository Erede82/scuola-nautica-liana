import 'package:flutter/foundation.dart';

import 'ios_edge_catcher_stub.dart'
    if (dart.library.html) 'ios_edge_catcher_web.dart' as impl;

/// MOBILE.FINAL: DOM edge catcher sopra Flutter (solo Login interna iOS web).
abstract final class IosEdgeCatcher {
  static const double edgeZonePx = 32;
  static const double confirmDeltaPx = 72;
  static const String backEventName = 'liana-internal-login-back';

  @visibleForTesting
  static bool shouldInstall({
    required bool isWeb,
    required TargetPlatform platform,
    required bool isInternalIosWebLogin,
  }) {
    return isWeb &&
        platform == TargetPlatform.iOS &&
        isInternalIosWebLogin;
  }

  /// Installa catcher DOM + callback Flutter per back interno.
  static void installIfNeeded({
    required bool isInternalIosWebLogin,
    required VoidCallback onBack,
  }) {
    if (!shouldInstall(
      isWeb: kIsWeb,
      platform: defaultTargetPlatform,
      isInternalIosWebLogin: isInternalIosWebLogin,
    )) {
      return;
    }
    impl.installIosEdgeCatcher(
      edgeZonePx: edgeZonePx,
      confirmDeltaPx: confirmDeltaPx,
      backEventName: backEventName,
      onBack: onBack,
    );
  }

  static void uninstall() => impl.uninstallIosEdgeCatcher();

  @visibleForTesting
  static bool get isInstalledForTest => impl.isIosEdgeCatcherInstalled;

  @visibleForTesting
  static int get installCountForTest => impl.iosEdgeCatcherInstallCount;
}
