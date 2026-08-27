import 'package:flutter/widgets.dart';

import '../app_root_navigator.dart';
import 'startup_viewport_diagnostics.dart';

/// Diagnostica startup/first-interaction (PWA.7-P + PWA.7-U-B raw pointer).
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
  static bool _webViewLoggedAtStartup = false;

  /// Target Welcome / overlay / back (solo se [enabled]).
  static final Map<String, GlobalKey> _targets = <String, GlobalKey>{};

  /// Provider opzionale dell'offset scroll Welcome.
  static double? Function()? welcomeScrollOffsetProvider;

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

  /// Registra (o aggiorna) un target geometrico diagnostico.
  static void registerTarget(String name, GlobalKey key) {
    if (!enabled) return;
    _targets[name] = key;
  }

  static void unregisterTarget(String name) {
    if (!enabled) return;
    _targets.remove(name);
  }

  static void clearTargetsForTest() {
    _targets.clear();
    welcomeScrollOffsetProvider = null;
  }

  /// Classificazione matematica: quali Rect contengono [point] (logical global).
  @visibleForTesting
  static List<String> classifyHitCandidates(
    Offset point,
    Map<String, Rect> rects,
  ) {
    final hits = <String>[];
    for (final entry in rects.entries) {
      if (entry.value.contains(point)) {
        hits.add(entry.key);
      }
    }
    return hits;
  }

  /// Snapshot Rect globali/logical dai target registrati.
  static Map<String, Rect> collectTargetRects() {
    final out = <String, Rect>{};
    if (!enabled) return out;
    for (final entry in _targets.entries) {
      final rect = _rectForKey(entry.value);
      if (rect != null) out[entry.key] = rect;
    }
    return out;
  }

  static Rect? _rectForKey(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final topLeft = box.localToGlobal(Offset.zero);
    return topLeft & box.size;
  }

  static String formatRect(String name, Rect r) {
    return 'RECT $name '
        'l=${_f(r.left)} t=${_f(r.top)} '
        'r=${_f(r.right)} b=${_f(r.bottom)} '
        'w=${_f(r.width)} h=${_f(r.height)}';
  }

  static String _f(double v) => v.toStringAsFixed(1);

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
    // Route note ma non in allowlist stretta: se sembra auth → redacted.
    final lower = path.toLowerCase();
    if (lower.contains('access_token') ||
        lower.contains('refresh_token') ||
        lower.contains('code=') ||
        lower.contains('type=recovery')) {
      return '<auth-redacted>';
    }
    return '<unknown>';
  }

  static String resolveRoute(BuildContext? context) {
    // Il Listener root sta nel MaterialApp.builder (sopra le route):
    // usa il Navigator root per la route corrente.
    try {
      final nav = appRootNavigatorKey.currentState;
      if (nav != null) {
        String? name;
        // popUntil con return true non modifica lo stack.
        nav.popUntil((route) {
          name ??= route.settings.name;
          return true;
        });
        final resolved = name;
        if (resolved == null || resolved.isEmpty) {
          return nav.canPop() ? '<unknown>' : '/';
        }
        return sanitizeRoute(resolved);
      }
    } catch (_) {}

    if (context == null) return '<unknown>';
    try {
      final name = ModalRoute.of(context)?.settings.name;
      if (name == null || name.isEmpty) {
        final nav = Navigator.maybeOf(context);
        if (nav != null && !nav.canPop()) return '/';
        return '<unknown>';
      }
      return sanitizeRoute(name);
    } catch (_) {
      return '<unknown>';
    }
  }

  static void logFlutterView(BuildContext context) {
    if (!enabled) return;
    final mq = MediaQuery.of(context);
    final size = mq.size;
    final pad = mq.padding;
    final vpad = mq.viewPadding;
    final insets = mq.viewInsets;
    log(
      'FLUTTER_VIEW size=${_f(size.width)}x${_f(size.height)} '
      'dpr=${_f(mq.devicePixelRatio)} '
      'padding=${_f(pad.top)},${_f(pad.right)},${_f(pad.bottom)},${_f(pad.left)} '
      'viewPadding=${_f(vpad.top)},${_f(vpad.right)},${_f(vpad.bottom)},${_f(vpad.left)} '
      'viewInsets=${_f(insets.top)},${_f(insets.right)},${_f(insets.bottom)},${_f(insets.left)}',
    );
  }

  static void logWebView() {
    if (!enabled) return;
    final snap = StartupViewportDiagnostics.capture();
    if (snap != null) log(snap);
  }

  static void logWebViewOnceAtStartup() {
    if (!enabled || _webViewLoggedAtStartup) return;
    _webViewLoggedAtStartup = true;
    logWebView();
  }

  static void logWelcomeScrollIfAvailable() {
    if (!enabled) return;
    final provider = welcomeScrollOffsetProvider;
    if (provider == null) return;
    final offset = provider();
    if (offset == null) return;
    log('WELCOME_SCROLL offset=${_f(offset)}');
  }

  static void logTargetRects() {
    if (!enabled) return;
    final rects = collectTargetRects();
    for (final entry in rects.entries) {
      log(formatRect(entry.key, entry.value));
    }
  }

  static void logRawHit(Offset point) {
    if (!enabled) return;
    final rects = collectTargetRects();
    final hits = classifyHitCandidates(point, rects);
    final label = hits.isEmpty ? '<none>' : hits.join(',');
    log('RAW HIT candidates=$label');
  }

  /// Pointer raw: coordinate Flutter logical global ([PointerEvent.position]).
  static void logRawPointer(
    String phase,
    PointerEvent event, {
    BuildContext? context,
  }) {
    if (!enabled) return;
    final route = resolveRoute(context);
    log(
      'RAW $phase id=${event.pointer} kind=${event.kind.name} '
      'x=${_f(event.position.dx)} y=${_f(event.position.dy)} '
      'buttons=${event.buttons} route=$route',
    );
  }

  /// RAW DOWN + snapshot viewport/target/hit (sequenza leggibile).
  static void onRawDown(PointerDownEvent event, BuildContext context) {
    if (!enabled) return;
    logRawPointer('DOWN', event, context: context);
    logFlutterView(context);
    logWebView();
    logWelcomeScrollIfAvailable();
    logTargetRects();
    logRawHit(event.position);
  }

  static void onRawUp(PointerUpEvent event, BuildContext context) {
    if (!enabled) return;
    logRawPointer('UP', event, context: context);
    logWelcomeScrollIfAvailable();
  }

  static void onRawCancel(PointerCancelEvent event, BuildContext context) {
    if (!enabled) return;
    logRawPointer('CANCEL', event, context: context);
  }

  static void onMetricsChanged(BuildContext? context) {
    if (!enabled) return;
    log('METRICS changed');
    if (context != null && context.mounted) {
      logFlutterView(context);
    }
    logWebView();
  }

  @visibleForTesting
  static void resetForTest() {
    capturedEvents.clear();
    _clock
      ..stop()
      ..reset();
    _started = false;
    _webViewLoggedAtStartup = false;
    clearTargetsForTest();
  }
}
