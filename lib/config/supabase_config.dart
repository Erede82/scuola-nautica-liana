import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Configurazione Supabase da `--dart-define` (CI / release) o valori vuoti in dev senza backend.
///
/// Esempio locale:
/// ```bash
/// flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=eyJ...
/// ```
abstract final class SupabaseConfig {
  static const String _url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const String _anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  /// `true` se URL e anon key sono valorizzati (progetto collegato a Supabase).
  static bool get isConfigured =>
      _url.trim().isNotEmpty && _anonKey.trim().isNotEmpty;

  /// Redirect OAuth (Google). Web: origine corrente; mobile: `--dart-define` o default scheme app.
  static String get oauthRedirectUrl {
    if (kIsWeb) {
      return Uri.base.origin;
    }
    const custom = String.fromEnvironment(
      'SUPABASE_OAUTH_REDIRECT',
      defaultValue: '',
    );
    if (custom.trim().isNotEmpty) {
      return custom.trim();
    }
    return 'it.scuolanauticaliana.app://login-callback';
  }

  /// Inizializza il client. No-op se non configurato.
  static Future<void> initialize() async {
    if (!isConfigured) return;
    await Supabase.initialize(
      url: _url.trim(),
      anonKey: _anonKey.trim(),
    );
  }
}
