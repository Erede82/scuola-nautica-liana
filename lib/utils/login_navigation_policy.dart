import 'package:flutter/foundation.dart';

/// FRONT.8: su iOS web il tap Accedi non deve creare entry browser `/#/login`.
@visibleForTesting
bool shouldUseInternalLoginRoute({
  required bool isWeb,
  required TargetPlatform platform,
}) {
  return isWeb && platform == TargetPlatform.iOS;
}

/// Usa [kIsWeb] + [defaultTargetPlatform] (production).
bool shouldUseInternalLoginRouteNow() {
  return shouldUseInternalLoginRoute(
    isWeb: kIsWeb,
    platform: defaultTargetPlatform,
  );
}
