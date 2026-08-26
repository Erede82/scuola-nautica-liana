import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/app_auth_gate.dart';
import 'package:scuola_nautica_liana/pages/forgot_password_page.dart';
import 'package:scuola_nautica_liana/pages/login_page.dart';
import 'package:scuola_nautica_liana/pages/student_registration_page.dart';
import 'package:scuola_nautica_liana/pages/welcome_page.dart';
import 'package:scuola_nautica_liana/services/web_startup_route_guard.dart';

Map<String, WidgetBuilder> _productionRoutes() => {
      '/login': (context) => const LoginPage(),
      '/register': (context) => const StudentRegistrationPage(),
      '/forgot-password': (context) => const ForgotPasswordPage(),
    };

Widget _productionWelcomeApp({Widget? home}) {
  return MaterialApp(
    home: home ?? const WelcomePage(),
    routes: _productionRoutes(),
  );
}

void main() {
  group('web startup route guard', () {
    test('root hashless / → /#/', () {
      expect(
        resolvedCleanStartupLocation(
          hash: '',
          search: '',
          pathname: '/',
        ),
        '/#/',
      );
    });

    test('root con query /?foo=bar → /?foo=bar#/', () {
      expect(
        resolvedCleanStartupLocation(
          hash: '',
          search: '?foo=bar',
          pathname: '/',
        ),
        '/?foo=bar#/',
      );
    });

    test('/#/ è idempotente → no action', () {
      expect(
        resolvedCleanStartupLocation(
          hash: '#/',
          search: '',
          pathname: '/',
        ),
        isNull,
      );
    });

    test('/#/login → no action', () {
      expect(
        resolvedCleanStartupLocation(
          hash: '#/login',
          search: '',
          pathname: '/',
        ),
        isNull,
      );
    });

    test('/#/register → no action', () {
      expect(
        resolvedCleanStartupLocation(
          hash: '#/register',
          search: '',
          pathname: '/',
        ),
        isNull,
      );
    });

    test('stale #/forgot-password senza recovery → /#/', () {
      expect(
        resolvedCleanStartupLocation(
          hash: '#/forgot-password',
          search: '',
          pathname: '/',
        ),
        '/#/',
      );
    });

    test('stale app.autoscuolaliana.it/#/forgot-password → /#/', () {
      expect(
        resolvedCleanStartupLocation(
          hash: '#/forgot-password',
          search: '',
          pathname: '/',
        ),
        '/#/',
      );
    });

    test('stale forgot-password path → /#/', () {
      expect(
        resolvedCleanStartupLocation(
          hash: '',
          search: '',
          pathname: '/forgot-password',
        ),
        '/#/',
      );
    });

    test('stale con query legittima preserva search → /?foo=bar#/', () {
      expect(
        resolvedCleanStartupLocation(
          hash: '#/forgot-password',
          search: '?foo=bar',
          pathname: '/',
        ),
        '/?foo=bar#/',
      );
    });

    test('recovery reale type=recovery non viene normalizzato', () {
      expect(
        resolvedCleanStartupLocation(
          hash: '#access_token=abc&type=recovery&refresh_token=xyz',
          search: '',
          pathname: '/',
        ),
        isNull,
      );
      expect(
        hasRealAuthRecoveryPayload(
          hash: '#access_token=abc&type=recovery',
          search: '',
        ),
        isTrue,
      );
    });

    test('recovery reale su #/forgot-password con payload preserva URL', () {
      expect(
        resolvedCleanStartupLocation(
          hash: '#/forgot-password?type=recovery&access_token=abc',
          search: '',
          pathname: '/',
        ),
        isNull,
      );
    });

    test('root hashless con recovery code in query → no action', () {
      expect(
        resolvedCleanStartupLocation(
          hash: '',
          search: '?code=auth-code-1',
          pathname: '/',
        ),
        isNull,
      );
    });

    test('PKCE code in query non viene normalizzato', () {
      expect(
        resolvedCleanStartupLocation(
          hash: '#/forgot-password',
          search: 'code=auth-code-1',
          pathname: '/',
        ),
        isNull,
      );
    });

    test('route login/register non toccate', () {
      expect(
        resolvedCleanStartupLocation(
          hash: '#/login',
          search: '',
          pathname: '/',
        ),
        isNull,
      );
      expect(isStaleForgotPasswordFragment('#/login'), isFalse);
    });

    test('helper riconosce fragment stale', () {
      expect(isStaleForgotPasswordFragment('#/forgot-password'), isTrue);
      expect(isStaleForgotPasswordFragment('forgot-password'), isTrue);
      expect(isStaleForgotPasswordFragment('/forgot-password'), isTrue);
      expect(isStaleForgotPasswordFragment('#/login'), isFalse);
      expect(isStaleForgotPasswordPath('/forgot-password'), isTrue);
      expect(isStaleForgotPasswordPath('/'), isFalse);
    });

    test('history target: Back resta nello spazio /#/', () {
      // Prima: / → /#/login → Back → /  (boundary hashless)
      // Dopo:  /#/ → /#/login → Back → /#/ (niente attraversamento)
      expect(
        resolvedCleanStartupLocation(hash: '', search: '', pathname: '/'),
        '/#/',
      );
      expect(
        resolvedCleanStartupLocation(hash: '#/', search: '', pathname: '/'),
        isNull,
      );
      expect(
        resolvedCleanStartupLocation(hash: '#/login', search: '', pathname: '/'),
        isNull,
      );
    });
  });

  group('Welcome CTA production-like', () {
    testWidgets('tester.tap(Accedi) → LoginPage', (tester) async {
      await tester.pumpWidget(_productionWelcomeApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Accedi'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.textContaining('Accedi con le credenziali'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Registrati → StudentRegistrationPage', (tester) async {
      await tester.pumpWidget(_productionWelcomeApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Registrati'));
      await tester.pumpAndSettle();

      expect(find.byType(StudentRegistrationPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Password dimenticata? → ForgotPasswordPage', (tester) async {
      await tester.pumpWidget(_productionWelcomeApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Password dimenticata?'));
      await tester.pumpAndSettle();

      expect(find.byType(ForgotPasswordPage), findsOneWidget);
      expect(find.text('Recupera password'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Welcome back navigation', () {
    testWidgets('Welcome → Accedi → Login → Back → Welcome', (tester) async {
      await tester.pumpWidget(_productionWelcomeApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Accedi'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(WelcomePage), findsOneWidget);
      expect(find.byType(LoginPage), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'Welcome → Password dimenticata → Forgot → Back → Welcome',
      (tester) async {
        await tester.pumpWidget(_productionWelcomeApp());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Password dimenticata?'));
        await tester.pumpAndSettle();
        expect(find.byType(ForgotPasswordPage), findsOneWidget);

        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(find.byType(WelcomePage), findsOneWidget);
        expect(find.byType(ForgotPasswordPage), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });

  testWidgets('cold start root → Welcome (anonimo)', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AppAuthGate()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(WelcomePage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
