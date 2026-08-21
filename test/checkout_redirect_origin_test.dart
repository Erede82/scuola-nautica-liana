import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/config/supabase_config.dart';

void main() {
  group('SupabaseConfig non-web checkout redirect', () {
    test('fallback default è il dominio production definitivo', () {
      expect(
        SupabaseConfig.resolveNonWebCheckoutRedirectOrigin(''),
        'https://app.autoscuolaliana.it',
      );
      expect(
        SupabaseConfig.defaultNonWebCheckoutRedirectOrigin,
        'https://app.autoscuolaliana.it',
      );
    });

    test('CHECKOUT_REDIRECT_ORIGIN override ha priorità sul fallback', () {
      expect(
        SupabaseConfig.resolveNonWebCheckoutRedirectOrigin(
          'https://staging.example.test',
        ),
        'https://staging.example.test',
      );
      expect(
        SupabaseConfig.resolveNonWebCheckoutRedirectOrigin(
          '  https://override.example.test  ',
        ),
        'https://override.example.test',
      );
    });

    test('success URL include status, productId e origin di fallback', () {
      final uri = SupabaseConfig.buildNonWebExtraCheckoutReturnUri(
        origin: SupabaseConfig.defaultNonWebCheckoutRedirectOrigin,
        status: 'success',
        productId: 'prod-extra-1',
      );

      expect(uri.scheme, 'https');
      expect(uri.host, 'app.autoscuolaliana.it');
      expect(uri.path, '/');
      expect(uri.queryParameters['extraCheckout'], 'success');
      expect(uri.queryParameters['productId'], 'prod-extra-1');
      expect(uri.toString(), contains('productId=prod-extra-1'));
      expect(uri.toString(), isNot(contains('app.scuolanauticaliana.it')));
    });

    test('cancel URL include status, productId e origin di fallback', () {
      final uri = SupabaseConfig.buildNonWebExtraCheckoutReturnUri(
        origin: SupabaseConfig.defaultNonWebCheckoutRedirectOrigin,
        status: 'cancel',
        productId: 'prod-extra-2',
      );

      expect(uri.queryParameters['extraCheckout'], 'cancel');
      expect(uri.queryParameters['productId'], 'prod-extra-2');
      expect(
        uri.toString(),
        startsWith('https://app.autoscuolaliana.it/?'),
      );
    });

    test('success/cancel rispettano origin override', () {
      const override = 'https://checkout-override.example.test';
      final success = SupabaseConfig.buildNonWebExtraCheckoutReturnUri(
        origin: override,
        status: 'success',
        productId: 'p-9',
      );
      final cancel = SupabaseConfig.buildNonWebExtraCheckoutReturnUri(
        origin: override,
        status: 'cancel',
        productId: 'p-9',
      );

      expect(success.host, 'checkout-override.example.test');
      expect(cancel.host, 'checkout-override.example.test');
      expect(success.queryParameters['productId'], 'p-9');
      expect(cancel.queryParameters['productId'], 'p-9');
    });

    test('nessun riferimento funzionale residuo al dominio legacy', () {
      expect(
        SupabaseConfig.defaultNonWebCheckoutRedirectOrigin,
        isNot(contains('app.scuolanauticaliana.it')),
      );
      expect(
        SupabaseConfig.resolveNonWebCheckoutRedirectOrigin(''),
        isNot(contains('scuolanauticaliana.it')),
      );
    });
  });
}
