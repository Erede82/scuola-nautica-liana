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

/// Observer production-safe: canonicalizza browser root quando Flutter è root.
class RootUrlCanonicalizationObserver extends NavigatorObserver {
  void _onRootVisible(Route<dynamic>? route) {
    if (route == null) return;
    if (!RootUrlCanonicalizer.isFlutterRootRoute(route)) return;
    RootUrlCanonicalizer.canonicalizeIfNeeded(flutterRouteIsRoot: true);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _onRootVisible(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _onRootVisible(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _onRootVisible(newRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _onRootVisible(previousRoute);
  }
}
