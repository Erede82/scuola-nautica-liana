import 'dart:js_interop';

import 'anti_loop_storage_memory.dart' as memory;

const _versionKey = 'liana_lastAttemptedRemoteVersion';
const _reloadKey = 'liana_lastReloadTimestamp';

String? readLastAttemptedRemoteVersion() {
  try {
    return _sessionStorage?.getItem(_versionKey)?.toDart;
  } catch (_) {
    return memory.readLastAttemptedRemoteVersion();
  }
}

void writeLastAttemptedRemoteVersion(String version) {
  try {
    _sessionStorage?.setItem(_versionKey, version);
  } catch (_) {
    memory.writeLastAttemptedRemoteVersion(version);
  }
}

DateTime? readLastReloadTimestamp() {
  try {
    final raw = _sessionStorage?.getItem(_reloadKey)?.toDart;
    if (raw == null || raw.isEmpty) return null;
    final ms = int.tryParse(raw);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  } catch (_) {
    return memory.readLastReloadTimestamp();
  }
}

void writeLastReloadTimestamp(DateTime timestamp) {
  try {
    _sessionStorage?.setItem(
      _reloadKey,
      timestamp.millisecondsSinceEpoch.toString(),
    );
  } catch (_) {
    memory.writeLastReloadTimestamp(timestamp);
  }
}

void resetForTest() {
  try {
    _sessionStorage?.removeItem(_versionKey);
    _sessionStorage?.removeItem(_reloadKey);
  } catch (_) {}
  memory.resetForTest();
}

@JS('window.sessionStorage')
external _JsStorage? get _sessionStorage;

extension type _JsStorage._(JSObject _) implements JSObject {
  external JSString? getItem(String key);
  external void setItem(String key, String value);
  external void removeItem(String key);
}
