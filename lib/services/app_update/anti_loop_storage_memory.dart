/// Backend in-memory per test e piattaforme non-web.
class InMemoryAntiLoopStorage {
  String? lastAttemptedRemoteVersion;
  DateTime? lastReloadTimestamp;

  void reset() {
    lastAttemptedRemoteVersion = null;
    lastReloadTimestamp = null;
  }
}

InMemoryAntiLoopStorage _memory = InMemoryAntiLoopStorage();

String? readLastAttemptedRemoteVersion() =>
    _memory.lastAttemptedRemoteVersion;

void writeLastAttemptedRemoteVersion(String version) {
  _memory.lastAttemptedRemoteVersion = version;
}

DateTime? readLastReloadTimestamp() => _memory.lastReloadTimestamp;

void writeLastReloadTimestamp(DateTime timestamp) {
  _memory.lastReloadTimestamp = timestamp;
}

void resetForTest() => _memory.reset();
