import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/app_auth_gate.dart';
import 'package:scuola_nautica_liana/pages/forgot_password_page.dart';
import 'package:scuola_nautica_liana/pages/welcome_page.dart';
import 'package:scuola_nautica_liana/services/web_startup_route_guard.dart';

void main() {
  group('web startup route guard', () {
    test('stale #/forgot-password senza recovery → root', () {
      expect(
        resolvedCleanStartupLocation(
          hash: '#/forgot-password',
          search: '',
          pathname: '/',
        ),
        '/',
      );
    });

    test('stale forgot-password path → root', () {
      expect(
        resolvedCleanStartupLocation(
          hash: '',
          search: '',
          pathname: '/forgot-password',
        ),
        '/',
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
  });

  testWidgets('cold start root → Welcome (anonimo)', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AppAuthGate()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(WelcomePage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'navigazione manuale Password dimenticata? apre ForgotPasswordPage',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const WelcomePage(),
          routes: {
            '/forgot-password': (_) => const ForgotPasswordPage(),
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Password dimenticata?'));
      await tester.pumpAndSettle();

      expect(find.byType(ForgotPasswordPage), findsOneWidget);
      expect(find.text('Recupera password'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'named route /forgot-password resta raggiungibile manualmente',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed('/forgot-password'),
                child: const Text('go-forgot'),
              ),
            ),
          ),
          routes: {
            '/forgot-password': (_) => const ForgotPasswordPage(),
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('go-forgot'));
      await tester.pumpAndSettle();
      expect(find.byType(ForgotPasswordPage), findsOneWidget);
      expect(find.text('Recupera password'), findsOneWidget);
    },
  );
}
