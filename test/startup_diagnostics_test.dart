import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/services/startup_diagnostics.dart';

void main() {
  test('sanitizeRoute non espone query/token', () {
    expect(StartupDiagnostics.sanitizeRoute('/forgot-password'), '/forgot-password');
    expect(
      StartupDiagnostics.sanitizeRoute(
        'https://app.example/#access_token=secret&type=recovery',
      ),
      '<auth-redacted>',
    );
    expect(StartupDiagnostics.sanitizeRoute('#/login'), '/login');
  });
}
