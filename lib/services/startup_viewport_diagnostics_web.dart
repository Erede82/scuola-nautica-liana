import 'dart:js_interop';

/// Snapshot viewport WebKit via JS interop (nessuna dipendenza pubspec extra).
String? captureWebViewportSnapshot() {
  try {
    final win = _window;
    final vv = win.visualViewport;

    final innerW = win.innerWidth;
    final innerH = win.innerHeight;
    final dpr = win.devicePixelRatio;

    final visualW = vv?.width ?? innerW;
    final visualH = vv?.height ?? innerH;
    final offL = vv?.offsetLeft ?? 0;
    final offT = vv?.offsetTop ?? 0;
    final scale = vv?.scale ?? 1;

    final doc = win.document;
    final el = doc.documentElement;
    final clientW = el?.clientWidth ?? 0;
    final clientH = el?.clientHeight ?? 0;

    String f(num v) => v.toDouble().toStringAsFixed(v == v.roundToDouble() ? 0 : 1);

    return 'WEB_VIEW '
        'inner=${f(innerW)}x${f(innerH)} '
        'visual=${f(visualW)}x${f(visualH)} '
        'off=${f(offL)},${f(offT)} '
        'scale=${f(scale)} '
        'dpr=${f(dpr)} '
        'client=${f(clientW)}x${f(clientH)}';
  } catch (_) {
    return 'WEB_VIEW <unavailable>';
  }
}

@JS('window')
external _JsWindow get _window;

extension type _JsWindow(JSObject _) implements JSObject {
  external double get innerWidth;
  external double get innerHeight;
  external double get devicePixelRatio;
  external _JsVisualViewport? get visualViewport;
  external _JsDocument get document;
}

extension type _JsVisualViewport(JSObject _) implements JSObject {
  external double get width;
  external double get height;
  external double get offsetLeft;
  external double get offsetTop;
  external double get scale;
}

extension type _JsDocument(JSObject _) implements JSObject {
  external _JsElement? get documentElement;
}

extension type _JsElement(JSObject _) implements JSObject {
  external double get clientWidth;
  external double get clientHeight;
}
