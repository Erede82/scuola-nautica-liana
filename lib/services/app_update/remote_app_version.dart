import 'dart:convert';

/// Snapshot remoto da `/version.json` (detector primario PWA.AUTOUPDATE.1).
class RemoteAppVersion {
  const RemoteAppVersion({
    required this.appVersion,
    this.commit,
    this.builtAt,
    this.raw = const {},
  });

  final String appVersion;
  final String? commit;
  final String? builtAt;
  final Map<String, dynamic> raw;

  /// Parse robusto: JSON invalido / `app_version` mancante → `null`.
  static RemoteAppVersion? tryParse(String body) {
    if (body.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);
      final appVersion = _readString(map, 'app_version');
      if (appVersion == null || appVersion.isEmpty) return null;
      return RemoteAppVersion(
        appVersion: appVersion,
        commit: _readString(map, 'commit'),
        builtAt: _readString(map, 'built_at'),
        raw: map,
      );
    } catch (_) {
      return null;
    }
  }

  static String? _readString(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}
