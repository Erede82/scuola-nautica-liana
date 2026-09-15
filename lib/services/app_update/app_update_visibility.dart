import 'package:flutter/foundation.dart';

import 'app_update_visibility_stub.dart'
    if (dart.library.html) 'app_update_visibility_web.dart' as impl;

/// Registra listener `visibilitychange` (web) per foreground check.
void installAppUpdateVisibilityListener(VoidCallback onVisible) =>
    impl.installAppUpdateVisibilityListener(onVisible);

void uninstallAppUpdateVisibilityListener() =>
    impl.uninstallAppUpdateVisibilityListener();
