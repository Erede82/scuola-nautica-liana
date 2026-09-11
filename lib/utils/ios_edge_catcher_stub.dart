import 'ios_edge_catcher_gesture.dart';

bool _installed = false;
int _installCount = 0;
void Function()? _onBack;

void installIosEdgeCatcher({
  required double edgeZonePx,
  required double confirmDeltaPx,
  required String backEventName,
  required void Function() onBack,
}) {
  if (_installed) return;
  _installed = true;
  _installCount += 1;
  _onBack = onBack;
}

void uninstallIosEdgeCatcher() {
  _installed = false;
  _onBack = null;
}

bool get isIosEdgeCatcherInstalled => _installed;

int get iosEdgeCatcherInstallCount => _installCount;

/// Stub helper: simula conferma gesture → onBack (test VM).
bool stubSimulateGesture({
  required double deltaX,
  required double deltaY,
}) {
  if (!_installed || _onBack == null) return false;
  if (!iosEdgeCatcherShouldConfirmBack(deltaX: deltaX, deltaY: deltaY)) {
    return false;
  }
  _onBack!();
  return true;
}

void stubResetInstallCount() {
  _installCount = 0;
}
