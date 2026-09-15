import 'anti_loop_storage_memory.dart'
    if (dart.library.html) 'anti_loop_storage_web.dart' as impl;

export 'anti_loop_storage_memory.dart' show InMemoryAntiLoopStorage;

/// Persistenza anti-loop reload (sessionStorage su web, in-memory altrove).
abstract final class AntiLoopStorage {
  static String? readLastAttemptedRemoteVersion() =>
      impl.readLastAttemptedRemoteVersion();

  static void writeLastAttemptedRemoteVersion(String version) =>
      impl.writeLastAttemptedRemoteVersion(version);

  static DateTime? readLastReloadTimestamp() =>
      impl.readLastReloadTimestamp();

  static void writeLastReloadTimestamp(DateTime timestamp) =>
      impl.writeLastReloadTimestamp(timestamp);

  /// Solo test / reset harness — non usare in runtime app.
  static void resetForTest() => impl.resetForTest();
}
