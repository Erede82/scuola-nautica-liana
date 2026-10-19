// ignore_for_file: invalid_runtime_check_with_js_interop_types
// Needed for clean analyze on current Flutter/web toolchain (raw is! JSObject).

import 'dart:js_interop';

@JS('fetch')
external JSPromise<JSAny?> _fetch(String url);

extension type _FetchResponse(JSObject _) implements JSObject {
  external bool get ok;
  external JSPromise<JSString> text();
}

/// Fetch `version.json` via Fetch API (cache-bust via query param).
Future<String?> fetchVersionJsonBody(String url) async {
  try {
    final raw = await _fetch(url).toDart;
    if (raw == null || raw is! JSObject) return null;
    final response = _FetchResponse(raw);
    if (!response.ok) return null;
    final jsText = await response.text().toDart;
    return jsText.toDart;
  } catch (_) {
    return null;
  }
}
