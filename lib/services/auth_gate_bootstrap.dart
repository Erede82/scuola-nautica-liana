import 'package:flutter/foundation.dart';

/// Coordina auth bootstrap + hero warmup prima di lasciare lo StartupShell.
///
/// FRONT.8: Welcome monta solo quando entrambi sono completi.
bool isAuthGateReady({
  required bool authComplete,
  required bool heroWarmupComplete,
}) {
  return authComplete && heroWarmupComplete;
}

/// Future paralleli: entrambi devono completare prima del gate ready.
@visibleForTesting
Future<void> waitAuthGateBootstrap({
  required Future<void> authBootstrap,
  required Future<void> heroWarmup,
}) {
  return Future.wait<void>([authBootstrap, heroWarmup]);
}
