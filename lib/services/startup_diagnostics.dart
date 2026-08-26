import 'package:flutter/foundation.dart';

/// Diagnostica startup/first-interaction (PWA.7-P).
///
/// Attiva solo con `--dart-define=STARTUP_DIAGNOSTICS=true`.
/// Nessun dato sensibile: niente email, token, query, UUID, payload Auth.
abstract final class StartupDiagnostics {
  static const bool enabled = bool.fromEnvironment(
    'STARTUP_DIAGNOSTICS',
    defaultValue: false,
  );

  static final Stopwatch _clock = Stopwatch();
  static bool _started = false;

  /// Ultimi eventi (solo se [enabled]); utile ai test.
  @visibleForTesting
  static final List<String> capturedEvents = <String>[];

  /// Avvia il cronometro monotono (idempotente).
  static void ensureStarted() {
    if (!enabled) return;
    if (_started) return;
    _started = true;
    _clock.start();
    log('MAIN');
  }

  static void log(String event) {
    if (!enabled) return;
    if (!_started) {
      _started = true;
      _clock.start();
    }
    final ms = _clock.elapsedMilliseconds.toString().padLeft(4, '0');
    final line = '[STARTUP +${ms}ms] $event';
    capturedEvents.add(line);
    debugPrint(line);
  }

  /// Route sanitizzata: solo path noti, mai query/hash/token.
  static String sanitizeRoute(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '<unknown>';
    var path = raw.trim();

    // Se c’è un fragment, analizza quello (hash routing Flutter / Auth).
    final hashIdx = path.indexOf('#');
    if (hashIdx >= 0) {
      final frag = path.substring(hashIdx + 1);
      final lower = frag.toLowerCase();
      if (lower.contains('access_token') ||
          lower.contains('refresh_token') ||
          lower.contains('type=recovery') ||
          lower.contains('type%3drecovery') ||
          RegExp(r'(^|[?&])code=').hasMatch(lower)) {
        return '<auth-redacted>';
      }
      path = frag.startsWith('/') ? frag : '/$frag';
    }

    final q = path.indexOf('?');
    if (q >= 0) {
      final query = path.substring(q + 1).toLowerCase();
      path = path.substring(0, q);
      if (query.contains('access_token') ||
          query.contains('refresh_token') ||
          query.contains('type=recovery') ||
          query.contains('code=')) {
        return '<auth-redacted>';
      }
    }

    if (!path.startsWith('/')) path = '/$path';
    path = path.replaceAll(RegExp(r'/+'), '/');
    if (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }

    const allowed = <String>{
      '/',
      '/login',
      '/register',
      '/forgot-password',
    };
    if (allowed.contains(path)) return path;
    return '<unknown>';
  }

  @visibleForTesting
  static void resetForTest() {
    capturedEvents.clear();
    _clock
      ..stop()
      ..reset();
    _started = false;
  }
}
