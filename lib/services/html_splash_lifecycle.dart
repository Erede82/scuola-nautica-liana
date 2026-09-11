import 'dart:async';

import 'package:flutter/foundation.dart';

import '../utils/startup_intro_policy.dart';
import 'html_splash_lifecycle_stub.dart'
    if (dart.library.html) 'html_splash_lifecycle_web.dart' as impl;
import 'startup_diagnostics.dart';

/// STARTUP.DECISIVE: intro Capri finché Welcome ready **e** min 1500ms.
abstract final class HtmlSplashLifecycle {
  static const String welcomeVisualReadyEvent = 'liana-welcome-visual-ready';
  static const String appSurfaceReadyEvent = 'liana-app-surface-ready';
  static const Duration minimumIntro = Duration(milliseconds: startupIntroMinMs);

  static bool _welcomeReady = false;
  static bool _surfaceReady = false;
  static bool _minElapsed = false;
  static bool _removed = false;
  static bool _introStarted = false;
  static Timer? _minTimer;

  /// Avvia cronometro intro + log `STARTUP_INTRO visible` (idempotente).
  static void ensureIntroStarted() {
    if (_introStarted) return;
    _introStarted = true;
    impl.logHtmlSplashVisibleIfPresent();
    StartupDiagnostics.log('STARTUP_INTRO visible');
    _minTimer?.cancel();
    _minTimer = Timer(minimumIntro, () {
      if (_minElapsed) return;
      _minElapsed = true;
      StartupDiagnostics.log('STARTUP_MIN_ELAPSED');
      _tryRemove();
    });
  }

  /// Alias storico.
  static void logVisibleIfPresent() => ensureIntroStarted();

  /// One-shot: Welcome hero + layout pronti.
  static void markWelcomeVisualReady() {
    if (_welcomeReady) return;
    _welcomeReady = true;
    StartupDiagnostics.log('WELCOME_VISUAL_READY');
    _tryRemove();
  }

  /// One-shot: surface non-Welcome (Home/Admin).
  static void markAppSurfaceReady() {
    if (_surfaceReady || _welcomeReady) return;
    _surfaceReady = true;
    _tryRemove();
  }

  static void _tryRemove() {
    if (_removed) return;
    final ready = _welcomeReady || _surfaceReady;
    if (!shouldRemoveStartupIntro(
      welcomeOrSurfaceReady: ready,
      minimumIntroElapsed: _minElapsed,
    )) {
      return;
    }
    _removed = true;
    _minTimer?.cancel();
    _minTimer = null;

    // Theme Welcome prima della rimozione splash (no fascia Capri).
    impl.applyWelcomeThemeNavy();
    StartupDiagnostics.log('WELCOME_THEME navy');

    impl.removeSplashDom();
    StartupDiagnostics.log('STARTUP_INTRO removed');
  }

  @visibleForTesting
  static void resetForTest() {
    _minTimer?.cancel();
    _minTimer = null;
    _welcomeReady = false;
    _surfaceReady = false;
    _minElapsed = false;
    _removed = false;
    _introStarted = false;
    impl.resetHtmlSplashLifecycleForTest();
  }

  @visibleForTesting
  static bool get welcomeVisualReadyDispatchedForTest => _welcomeReady;

  @visibleForTesting
  static bool get minimumIntroElapsedForTest => _minElapsed;

  @visibleForTesting
  static bool get introRemovedForTest => _removed;

  /// Test: forza min elapsed senza attendere il Timer reale.
  @visibleForTesting
  static void debugForceMinimumElapsed() {
    if (_minElapsed) return;
    _minElapsed = true;
    StartupDiagnostics.log('STARTUP_MIN_ELAPSED');
    _tryRemove();
  }
}
