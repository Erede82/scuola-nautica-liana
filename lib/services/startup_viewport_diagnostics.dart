import 'startup_viewport_diagnostics_stub.dart'
    if (dart.library.html) 'startup_viewport_diagnostics_web.dart'
    as impl;

/// Snapshot WebKit/DOM viewport (solo web; stub altrove).
abstract final class StartupViewportDiagnostics {
  /// Ritorna una riga `WEB_VIEW ...` oppure `null` se non disponibile.
  static String? capture() => impl.captureWebViewportSnapshot();
}
