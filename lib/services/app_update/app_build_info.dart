/// Identificativo release PWA (PWA.AUTOUPDATE.1).
///
/// Valori da `--dart-define=APP_VERSION=...` e `APP_COMMIT_SHORT=...`.
/// In development ([version] == `dev`) il checker update è disabilitato.
abstract final class AppBuildInfo {
  static const String version = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: 'dev',
  );

  static const String commitShort = String.fromEnvironment(
    'APP_COMMIT_SHORT',
    defaultValue: '',
  );

  /// Formato production atteso: `YYYY.MM.DD.N` (es. `2026.09.15.1`).
  static final RegExp productionVersionPattern = RegExp(
    r'^\d{4}\.\d{2}\.\d{2}\.\d+$',
  );

  static bool get isDev => version == 'dev';

  static bool get isProductionVersion =>
      !isDev && productionVersionPattern.hasMatch(version);

  /// Checker attivo solo con versione production valida.
  static bool get isUpdateCheckerEnabled => isProductionVersion;

  static String get displayVersion => version;

  static String get displayCommit =>
      commitShort.isEmpty ? '—' : commitShort;
}
