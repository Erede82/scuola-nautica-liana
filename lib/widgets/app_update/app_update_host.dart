import 'package:flutter/material.dart';

import '../../services/app_update/app_build_info.dart';
import '../../services/app_update/app_update_coordinator.dart';
import '../../services/app_update/app_update_visibility.dart';
import 'update_available_banner.dart';

/// Host globale PWA auto-update (coesiste con StartupDiagnosticsHost).
class AppUpdateHost extends StatefulWidget {
  const AppUpdateHost({super.key, required this.child});

  final Widget child;

  @override
  State<AppUpdateHost> createState() => _AppUpdateHostState();
}

class _AppUpdateHostState extends State<AppUpdateHost>
    with WidgetsBindingObserver {
  late final AppUpdateCoordinator _coordinator;

  @override
  void initState() {
    super.initState();
    _coordinator = AppUpdateCoordinator.instance;
    _coordinator.addListener(_onCoordinatorChanged);

    if (AppBuildInfo.isUpdateCheckerEnabled) {
      WidgetsBinding.instance.addObserver(this);
      installAppUpdateVisibilityListener(_coordinator.onVisibilityVisible);
      _coordinator.installLifecycle();
    }
  }

  @override
  void dispose() {
    if (AppBuildInfo.isUpdateCheckerEnabled) {
      WidgetsBinding.instance.removeObserver(this);
      uninstallAppUpdateVisibilityListener();
      _coordinator.disposeLifecycle();
    }
    _coordinator.removeListener(_onCoordinatorChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _coordinator.onAppResumed();
    }
  }

  void _onCoordinatorChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!AppBuildInfo.isUpdateCheckerEnabled) {
      return widget.child;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        UpdateAvailableBanner(coordinator: _coordinator),
      ],
    );
  }
}
