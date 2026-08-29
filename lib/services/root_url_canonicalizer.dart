import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'web_startup_route_guard.dart';

import 'root_url_canonicalizer_stub.dart'
    if (dart.library.html) 'root_url_canonicalizer_web.dart'
    as impl;

/// Azione pianificata per canonicalizzazione root browser (testabile senza DOM).
enum RootCanonicalizeAction {
  none,
  replace,
}

/// Canonicalizza `/` hashless → `/#/` dopo che Flutter è sulla root.
abstract final class RootUrlCanonicalizer {
  /// True se la [route] Flutter visibile corrisponde alla root app.
  static bool isFlutterRootRoute(Route<dynamic> route) {
    final name = route.settings.name;
    if (name == null || name.isEmpty || name == '/') return true;
    return false;
  }

  /// Condizione pura: root Flutter + pathname `/` + hash vuoto + no auth payload.
  static bool shouldCanonicalizeRootUrl({
    required String pathname,
    required String hash,
    required String search,
    required bool flutterRouteIsRoot,
  }) {
    if (!flutterRouteIsRoot) return false;
    if (hasRealAuthRecoveryPayload(hash: hash, search: search)) {
      return false;
    }
    final hashEmpty = hash.isEmpty || hash == '#';
    final atRoot = pathname.isEmpty || pathname == '/';
    return atRoot && hashEmpty;
  }

  /// URL target per `history.replaceState` (pathname + search + `#/`), o null.
  static String? buildCanonicalRootReplaceUrl({
    required String pathname,
    required String search,
  }) {
    final query = search.isEmpty ? '' : search;
    final normalizedPath = pathname.isEmpty ? '/' : pathname;
    return '$normalizedPath$query$flutterHashRoot';
  }

  /// Piano d'azione (replace vs no-op) per test senza browser.
  static RootCanonicalizeAction plannedAction({
    required String pathname,
    required String hash,
    required String search,
    required bool flutterRouteIsRoot,
  }) {
    if (!shouldCanonicalizeRootUrl(
      pathname: pathname,
      hash: hash,
      search: search,
      flutterRouteIsRoot: flutterRouteIsRoot,
    )) {
      return RootCanonicalizeAction.none;
    }
    return RootCanonicalizeAction.replace;
  }

  /// Applica replaceState web se necessario (no-op su non-web).
  static void canonicalizeIfNeeded({required bool flutterRouteIsRoot}) {
    impl.canonicalizeRootIfNeeded(flutterRouteIsRoot: flutterRouteIsRoot);
  }
}

/// Pianifica canonicalizzazione root al prossimo post-frame (dopo sync Flutter).
class RootUrlCanonicalizationScheduler {
  RootUrlCanonicalizationScheduler({
    void Function({required bool flutterRouteIsRoot})? canonicalize,
    SchedulerBinding? binding,
  })  : _canonicalize =
            canonicalize ?? RootUrlCanonicalizer.canonicalizeIfNeeded,
        _binding = binding ?? SchedulerBinding.instance;

  final void Function({required bool flutterRouteIsRoot}) _canonicalize;
  final SchedulerBinding _binding;

  Route<dynamic>? _pendingRoute;
  bool _postFrameScheduled = false;

  @visibleForTesting
  bool get hasPendingPostFrameForTest => _postFrameScheduled;

  /// Accoda canonicalizzazione per [route] root; esegue al post-frame se ancora current.
  void schedule(Route<dynamic> route) {
    if (!RootUrlCanonicalizer.isFlutterRootRoute(route)) return;
    _pendingRoute = route;
    if (_postFrameScheduled) return;
    _postFrameScheduled = true;
    _binding.addPostFrameCallback(_onPostFrame);
  }

  void _onPostFrame(Duration _) {
    _postFrameScheduled = false;
    final route = _pendingRoute;
    _pendingRoute = null;
    if (route == null || !route.isCurrent) return;
    if (!RootUrlCanonicalizer.isFlutterRootRoute(route)) return;
    _canonicalize(flutterRouteIsRoot: true);
  }
}

/// Observer production-safe: canonicalizza browser root quando Flutter è root.
class RootUrlCanonicalizationObserver extends NavigatorObserver {
  RootUrlCanonicalizationObserver({
    RootUrlCanonicalizationScheduler? scheduler,
  }) : _scheduler = scheduler ?? RootUrlCanonicalizationScheduler();

  final RootUrlCanonicalizationScheduler _scheduler;

  void _scheduleForRoot(Route<dynamic>? route) {
    if (route == null) return;
    _scheduler.schedule(route);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _scheduleForRoot(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _scheduleForRoot(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _scheduleForRoot(newRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _scheduleForRoot(previousRoute);
  }
}
