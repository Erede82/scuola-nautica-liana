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

  /// Origin autorizzato per successUrl/cancelUrl Stripe Checkout (web: [Uri.base.origin]).
  static String get checkoutRedirectOrigin {
    if (kIsWeb) {
      return Uri.base.origin;
    }
    const custom = String.fromEnvironment(
      'CHECKOUT_REDIRECT_ORIGIN',
      defaultValue: '',
    );
    if (custom.trim().isNotEmpty) {
      return custom.trim();
    }
    return 'https://app.scuolanauticaliana.it';
  }

  static String extraCheckoutSuccessUrl(String productId) =>
      _extraCheckoutReturnUri(status: 'success', productId: productId)
          .toString();

  static String extraCheckoutCancelUrl(String productId) =>
      _extraCheckoutReturnUri(status: 'cancel', productId: productId).toString();

  static Uri _extraCheckoutReturnUri({
    required String status,
    required String productId,
  }) {
    if (kIsWeb) {
      final base = Uri.base;
      return base.replace(
        queryParameters: <String, String>{
          ...base.queryParameters,
          'extraCheckout': status,
          'productId': productId,
        },
      );
    }
    return Uri.parse(checkoutRedirectOrigin).replace(
      path: '/',
      queryParameters: <String, String>{
        'extraCheckout': status,
        'productId': productId,
      },
    );
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
