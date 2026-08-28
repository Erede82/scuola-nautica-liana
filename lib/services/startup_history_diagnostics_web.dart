import 'dart:js_interop';

import 'startup_diagnostics.dart';

bool _installed = false;
JSFunction? _popStateListener;
JSFunction? _hashChangeListener;
JSFunction? _pageShowListener;
JSFunction? _pageHideListener;
JSFunction? _visibilityChangeListener;

void installHistoryDiagnosticsIfEnabled() {
  if (!StartupDiagnostics.enabled || _installed) return;
  _installed = true;

  _popStateListener = _onPopState.toJS;
  _hashChangeListener = _onHashChange.toJS;
  _pageShowListener = _onPageShow.toJS;
  _pageHideListener = _onPageHide.toJS;
  _visibilityChangeListener = _onVisibilityChange.toJS;

  final win = _window;
  win.addEventListener('popstate', _popStateListener!);
  win.addEventListener('hashchange', _hashChangeListener!);
  win.addEventListener('pageshow', _pageShowListener!);
  win.addEventListener('pagehide', _pageHideListener!);
  win.addEventListener('visibilitychange', _visibilityChangeListener!);
}

void logHistoryInitialSnapshot() {
  if (!StartupDiagnostics.enabled) return;

  final len = _historyLength();
  final route = _currentRouteLabel();
  final visibility = _visibilityState();
  final nav = _readNavigationType();

  StartupDiagnostics.log(
    'HISTORY_INIT len=$len route=$route visibility=$visibility nav=$nav',
  );
  StartupDiagnostics.log('NAVIGATION type=$nav');
}

void uninstallHistoryDiagnostics() {
  if (!_installed) return;
  final win = _window;
  if (_popStateListener != null) {
    win.removeEventListener('popstate', _popStateListener!);
  }
  if (_hashChangeListener != null) {
    win.removeEventListener('hashchange', _hashChangeListener!);
  }
  if (_pageShowListener != null) {
    win.removeEventListener('pageshow', _pageShowListener!);
  }
  if (_pageHideListener != null) {
    win.removeEventListener('pagehide', _pageHideListener!);
  }
  if (_visibilityChangeListener != null) {
    win.removeEventListener('visibilitychange', _visibilityChangeListener!);
  }
  _installed = false;
  _popStateListener = null;
  _hashChangeListener = null;
  _pageShowListener = null;
  _pageHideListener = null;
  _visibilityChangeListener = null;
}

void _onPopState(JSAny event) {
  final pop = event as PopStateEvent;
  _emitHistory('popstate', statePresent: pop.state != null);
}

void _onHashChange(JSAny event) {
  // Solo stato corrente classificato — mai oldURL/newURL.
  _emitHistory('hashchange');
}

void _onPageShow(JSAny event) {
  final page = event as PageTransitionEvent;
  _emitHistory('pageshow', persisted: page.persisted);
}

void _onPageHide(JSAny event) {
  final page = event as PageTransitionEvent;
  _emitHistory('pagehide', persisted: page.persisted);
}

void _onVisibilityChange(JSAny event) {
  _emitHistory('visibilitychange');
}

void _emitHistory(
  String type, {
  bool? persisted,
  bool? statePresent,
}) {
  if (!StartupDiagnostics.enabled) return;
  StartupDiagnostics.log(
    StartupDiagnostics.formatHistoryEvent(
      event: type,
      historyLength: _historyLength(),
      route: _currentRouteLabel(),
      visibility: _visibilityState(),
      persisted: persisted,
      statePresent: statePresent,
    ),
  );
}

int _historyLength() => _window.history.length.toInt();

String _currentRouteLabel() {
  final loc = _window.location;
  return StartupDiagnostics.historyRouteLabel(
    loc.pathname,
    loc.hash,
  );
}

String _visibilityState() => _window.document.visibilityState;

String _readNavigationType() {
  try {
    final entries = _window.performance.getEntriesByType('navigation');
    if (entries.length == 0) return 'unknown';
    final first = entries[0] as PerformanceNavigationTiming;
    final type = first.type;
    if (type.isEmpty) return 'unknown';
    const allowed = {'navigate', 'reload', 'back_forward', 'prerender'};
    return allowed.contains(type) ? type : 'unknown';
  } catch (_) {
    return 'unknown';
  }
}

@JS('window')
external _JsWindow get _window;

extension type _JsWindow(JSObject _) implements JSObject {
  external _JsHistory get history;
  external _JsLocation get location;
  external _JsDocument get document;
  external _JsPerformance get performance;
  external void addEventListener(String type, JSFunction listener);
  external void removeEventListener(String type, JSFunction listener);
}

extension type _JsHistory(JSObject _) implements JSObject {
  external double get length;
}

extension type _JsLocation(JSObject _) implements JSObject {
  external String get pathname;
  external String get hash;
}

extension type _JsDocument(JSObject _) implements JSObject {
  external String get visibilityState;
}

extension type _JsPerformance(JSObject _) implements JSObject {
  external JSArray<JSObject> getEntriesByType(String type);
}

extension type PopStateEvent(JSObject _) implements JSObject {
  external JSAny? get state;
}

extension type PageTransitionEvent(JSObject _) implements JSObject {
  external bool get persisted;
}

extension type PerformanceNavigationTiming(JSObject _) implements JSObject {
  external String get type;
}
