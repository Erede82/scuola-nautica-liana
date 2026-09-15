import 'dart:js_interop';

void Function()? _onVisible;
JSFunction? _listener;

void installAppUpdateVisibilityListener(void Function() onVisible) {
  _onVisible = onVisible;
  if (_listener != null) return;
  _listener = _handleVisibilityChange.toJS;
  _document.addEventListener('visibilitychange', _listener!);
}

void uninstallAppUpdateVisibilityListener() {
  if (_listener != null) {
    _document.removeEventListener('visibilitychange', _listener!);
  }
  _listener = null;
  _onVisible = null;
}

void _handleVisibilityChange() {
  if (_document.visibilityState == 'visible') {
    _onVisible?.call();
  }
}

@JS('document')
external _JsDocument get _document;

extension type _JsDocument._(JSObject _) implements JSObject {
  external String get visibilityState;
  external void addEventListener(String type, JSFunction listener);
  external void removeEventListener(String type, JSFunction listener);
}
