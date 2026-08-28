import 'package:flutter/material.dart';

import 'startup_diagnostics.dart';
import 'startup_history_diagnostics.dart';

/// Host root: [Listener] translucido + [WidgetsBindingObserver] metrics.
///
/// Attivo solo se [StartupDiagnostics.enabled]. Non compete nella GestureArena
/// (nessun GestureDetector / recognizer). `HitTestBehavior.translucent` riceve
/// pointer e li lascia passare ai discendenti.
class StartupDiagnosticsHost extends StatefulWidget {
  const StartupDiagnosticsHost({super.key, required this.child});

  final Widget child;

  @override
  State<StartupDiagnosticsHost> createState() => _StartupDiagnosticsHostState();
}

class _StartupDiagnosticsHostState extends State<StartupDiagnosticsHost>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    if (!StartupDiagnostics.enabled) return;
    WidgetsBinding.instance.addObserver(this);
    StartupHistoryDiagnostics.installIfEnabled();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      StartupHistoryDiagnostics.logInitialSnapshot();
      StartupDiagnostics.logWebViewOnceAtStartup();
      StartupDiagnostics.logFlutterView(context);
    });
  }

  @override
  void dispose() {
    if (StartupDiagnostics.enabled) {
      WidgetsBinding.instance.removeObserver(this);
      StartupHistoryDiagnostics.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    // Nessun setState: solo log.
    StartupDiagnostics.onMetricsChanged(mounted ? context : null);
  }

  @override
  Widget build(BuildContext context) {
    if (!StartupDiagnostics.enabled) {
      return widget.child;
    }

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) => StartupDiagnostics.onRawDown(e, context),
      onPointerUp: (e) => StartupDiagnostics.onRawUp(e, context),
      onPointerCancel: (e) => StartupDiagnostics.onRawCancel(e, context),
      child: widget.child,
    );
  }
}
