import 'package:flutter/foundation.dart';

import 'startup_history_diagnostics_stub.dart'
    if (dart.library.html) 'startup_history_diagnostics_web.dart'
    as impl;

/// Browser history / BFCache diagnostics (web-only; stub altrove).
abstract final class StartupHistoryDiagnostics {
  /// Registra listener passivi se [StartupDiagnostics.enabled].
  static void installIfEnabled() => impl.installHistoryDiagnosticsIfEnabled();

  /// Snapshot iniziale: HISTORY_INIT + NAVIGATION type (primo frame utile).
  static void logInitialSnapshot() => impl.logHistoryInitialSnapshot();

  /// Rimuove listener (dispose app / reset test).
  static void dispose() => impl.uninstallHistoryDiagnostics();

  @visibleForTesting
  static void uninstallForTest() => dispose();
}
