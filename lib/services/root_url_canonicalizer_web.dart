import 'dart:js_interop';

import 'root_url_canonicalizer.dart';
import 'startup_diagnostics.dart';

void canonicalizeRootIfNeeded({required bool flutterRouteIsRoot}) {
  if (!flutterRouteIsRoot) return;

  final loc = _window.location;
  final pathname = loc.pathname;
  final hash = loc.hash;
  final search = loc.search;

  if (!RootUrlCanonicalizer.shouldCanonicalizeRootUrl(
    pathname: pathname,
    hash: hash,
    search: search,
    flutterRouteIsRoot: true,
  )) {
    return;
  }

  final replaceUrl = RootUrlCanonicalizer.buildCanonicalRootReplaceUrl(
    pathname: pathname,
    search: search,
  );
  if (replaceUrl == null) return;

  // Preserva history.state corrente (non sostituire con null).
  final currentState = _window.history.state;
  _window.history.replaceState(currentState, '', replaceUrl);

  if (StartupDiagnostics.enabled) {
    StartupDiagnostics.log('ROOT_CANONICALIZE from=empty-hash to=root');
  }
}

@JS('window')
external _JsWindow get _window;

extension type _JsWindow(JSObject _) implements JSObject {
  external _JsLocation get location;
  external _JsHistory get history;
}

extension type _JsLocation(JSObject _) implements JSObject {
  external String get pathname;
  external String get hash;
  external String get search;
}

extension type _JsHistory(JSObject _) implements JSObject {
  external JSAny? get state;
  external void replaceState(JSAny? data, String unused, String url);
}
