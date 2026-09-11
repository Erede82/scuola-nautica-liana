import 'dart:js_interop';

bool _visibleLogged = false;
bool _removed = false;

void logHtmlSplashVisibleIfPresent() {
  if (_visibleLogged) return;
  final el = _document.getElementById('liana-splash');
  if (el == null) return;
  _visibleLogged = true;
}

/// Theme Welcome/app: conferma `#005E83` (root già Navy in CSS critico).
void applyWelcomeThemeNavy() {
  const navy = '#005E83';
  final metas = _document.querySelectorAll('meta[name="theme-color"]');
  for (var i = 0; i < metas.length; i++) {
    final m = metas.item(i);
    if (m != null) m.setAttribute('content', navy);
  }
  final html = _document.documentElement;
  final body = _document.body;
  html?.style.setProperty('background-color', navy);
  body?.style.setProperty('background-color', navy);
}

void removeSplashDom() {
  if (_removed) return;
  final el = _document.getElementById('liana-splash');
  if (el == null) {
    _removed = true;
    return;
  }
  el.remove();
  _removed = true;
}

/// Legacy: eventi custom non rimuovono più lo splash (gate Dart).
void dispatchSplashReadyEvent(String eventName) {
  _window.dispatchEvent(_CustomEvent(eventName));
}

void resetHtmlSplashLifecycleForTest() {
  _visibleLogged = false;
  _removed = false;
}

bool get welcomeVisualReadyDispatchedForTest => false;

@JS('document')
external _Doc get _document;

@JS('window')
external _Win get _window;

extension type _Doc(JSObject _) implements JSObject {
  external _HtmlEl? getElementById(String id);
  external _HtmlEl? get documentElement;
  external _HtmlEl? get body;
  external _NodeList querySelectorAll(String selectors);
}

extension type _NodeList(JSObject _) implements JSObject {
  external int get length;
  external _HtmlEl? item(int index);
}

extension type _HtmlEl(JSObject _) implements JSObject {
  external void remove();
  external void setAttribute(String name, String value);
  external _CssStyle get style;
}

extension type _CssStyle(JSObject _) implements JSObject {
  external void setProperty(String name, String value);
}

extension type _Win(JSObject _) implements JSObject {
  external void dispatchEvent(JSObject event);
}

@JS('CustomEvent')
extension type _CustomEvent._(JSObject _) implements JSObject {
  external factory _CustomEvent(String type);
}
