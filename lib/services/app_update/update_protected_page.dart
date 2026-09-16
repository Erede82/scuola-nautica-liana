import 'package:flutter/widgets.dart';

import 'app_update_coordinator.dart';

/// Marks a full-page flow as in-progress work for PWA auto-update.
///
/// Dialogs use [showUpdateProtectedDialog]; this mixin is for long-lived
/// players that keep unsaved answers in memory (exam, lesson sheet, assigned
/// quiz). A browser reload bypasses [PopScope], so those pages must hold
/// [AppUpdateCoordinator.beginUnsafeWork] for their entire lifetime.
mixin UpdateProtectedPageMixin<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    AppUpdateCoordinator.instance.beginUnsafeWork();
  }

  @override
  void dispose() {
    AppUpdateCoordinator.instance.endUnsafeWork();
    super.dispose();
  }
}
