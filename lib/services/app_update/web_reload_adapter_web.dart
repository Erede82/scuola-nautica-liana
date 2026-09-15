import 'dart:js_interop';

/// `window.location.reload()` — mantiene hash e query correnti.
void reloadCurrentPage() {
  _window.location.reload();
}

@JS('window')
external _JsWindow get _window;

extension type _JsWindow._(JSObject _) implements JSObject {
  external _JsLocation get location;
}

extension type _JsLocation._(JSObject _) implements JSObject {
  external void reload();
}
