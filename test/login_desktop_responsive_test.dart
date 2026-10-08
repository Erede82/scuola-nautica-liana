import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/pages/forgot_password_page.dart';
import 'package:scuola_nautica_liana/pages/login_page.dart';

Future<void> _pumpLogin(
  WidgetTester tester, {
  required Size size,
  double textScale = 1.0,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });

  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        );
      },
      home: const LoginPage(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('AUTH.LOGIN.DESKTOP.1 — responsive layout', () {
    testWidgets('A. 390 mobile → single column, no desktop split', (
      tester,
    ) async {
      await _pumpLogin(tester, size: const Size(390, 844));
      expect(find.byKey(const Key('login_mobile_column')), findsOneWidget);
      expect(find.byKey(const Key('login_desktop_split')), findsNothing);
      expect(find.byKey(const Key('login_brand_panel')), findsNothing);
      expect(find.byKey(const Key('login_email_field')), findsOneWidget);
      expect(find.byKey(const Key('login_submit')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('B. 600 tablet → centered card, no split', (tester) async {
      await _pumpLogin(tester, size: const Size(600, 900));
      expect(find.byKey(const Key('login_form_card')), findsOneWidget);
      expect(find.byKey(const Key('login_desktop_split')), findsNothing);
      expect(find.byKey(const Key('login_mobile_column')), findsNothing);
      final card = tester.getSize(find.byKey(const Key('login_form_card')));
      expect(card.width, lessThanOrEqualTo(LoginPage.loginCardMaxWidth + 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('C. 768 tablet → controlled card width', (tester) async {
      await _pumpLogin(tester, size: const Size(768, 1024));
      expect(find.byKey(const Key('login_form_card')), findsOneWidget);
      expect(find.byKey(const Key('login_desktop_split')), findsNothing);
      final card = tester.getSize(find.byKey(const Key('login_form_card')));
      expect(card.width, lessThanOrEqualTo(LoginPage.loginCardMaxWidth + 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('D–F. 1024/1280/1440 desktop split', (tester) async {
      for (final width in const [1024.0, 1280.0, 1440.0]) {
        await _pumpLogin(tester, size: Size(width, 900));
        expect(find.byKey(const Key('login_desktop_split')), findsOneWidget);
        expect(find.byKey(const Key('login_brand_panel')), findsOneWidget);
        expect(find.byKey(const Key('login_form_card')), findsOneWidget);
        expect(find.byKey(const Key('login_mobile_column')), findsNothing);
        expect(find.text('Il tuo percorso, sempre con te.'), findsOneWidget);
        final card = tester.getSize(find.byKey(const Key('login_form_card')));
        expect(card.width, lessThanOrEqualTo(LoginPage.loginCardMaxWidth + 1));
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('G. 1920 → card not stretched', (tester) async {
      await _pumpLogin(tester, size: const Size(1920, 1080));
      expect(find.byKey(const Key('login_desktop_split')), findsOneWidget);
      final card = tester.getSize(find.byKey(const Key('login_form_card')));
      expect(card.width, lessThanOrEqualTo(LoginPage.loginCardMaxWidth + 1));
      expect(card.width, lessThan(600));
      expect(tester.takeException(), isNull);
    });

    testWidgets('H. 1366×768 → no overflow, CTA reachable', (tester) async {
      await _pumpLogin(tester, size: const Size(1366, 768));
      expect(find.byKey(const Key('login_desktop_split')), findsOneWidget);
      expect(find.byKey(const Key('login_submit')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('login_submit')));
      expect(tester.takeException(), isNull);
    });

    testWidgets('I–J. textScale 1.3 / 1.5 mobile + desktop', (tester) async {
      for (final scale in const [1.3, 1.5]) {
        await _pumpLogin(tester, size: const Size(390, 844), textScale: scale);
        expect(find.byKey(const Key('login_mobile_column')), findsOneWidget);
        await tester.ensureVisible(find.byKey(const Key('login_submit')));
        expect(tester.takeException(), isNull);

        await _pumpLogin(tester, size: const Size(1440, 900), textScale: scale);
        expect(find.byKey(const Key('login_desktop_split')), findsOneWidget);
        await tester.ensureVisible(find.byKey(const Key('login_submit')));
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('K. validation empty submit shows field errors', (
      tester,
    ) async {
      await _pumpLogin(tester, size: const Size(390, 844));
      await tester.tap(find.byKey(const Key('login_submit')));
      await tester.pumpAndSettle();
      expect(find.text('Inserisci l’email.'), findsOneWidget);
      expect(find.text('Inserisci la password.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('L. password visibility toggle invariato', (tester) async {
      await _pumpLogin(tester, size: const Size(1024, 768));
      final editable = find.descendant(
        of: find.byKey(const Key('login_password_field')),
        matching: find.byType(EditableText),
      );
      expect(tester.widget<EditableText>(editable).obscureText, isTrue);

      await tester.tap(find.byKey(const Key('login_password_visibility')));
      await tester.pump();
      expect(tester.widget<EditableText>(editable).obscureText, isFalse);

      await tester.tap(find.byKey(const Key('login_password_visibility')));
      await tester.pump();
      expect(tester.widget<EditableText>(editable).obscureText, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('M. forgot password wiring invariato', (tester) async {
      await _pumpLogin(tester, size: const Size(390, 844));
      await tester.tap(find.byKey(const Key('login_forgot_password')));
      await tester.pumpAndSettle();
      expect(find.byType(ForgotPasswordPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('N. submit button present on all breakpoints', (tester) async {
      for (final size in const [
        Size(390, 844),
        Size(600, 900),
        Size(768, 1024),
        Size(1024, 768),
        Size(1440, 900),
      ]) {
        await _pumpLogin(tester, size: size);
        expect(find.byKey(const Key('login_submit')), findsOneWidget);
        expect(find.byKey(const Key('login_email_field')), findsOneWidget);
        expect(find.byKey(const Key('login_password_field')), findsOneWidget);
        expect(find.byKey(const Key('login_create_account')), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('O. mobile regression no horizontal overflow', (tester) async {
      await _pumpLogin(tester, size: const Size(320, 568));
      expect(find.byKey(const Key('login_mobile_column')), findsOneWidget);
      expect(find.byKey(const Key('login_desktop_split')), findsNothing);
      final bodyWidth = tester.getSize(find.byType(LoginPage)).width;
      expect(bodyWidth, lessThanOrEqualTo(320 + 1));
      expect(tester.takeException(), isNull);
    });

    test('breakpoints constants', () {
      expect(LoginPage.desktopSplitMinWidth, 1024);
      expect(LoginPage.tabletMinWidth, 600);
      expect(LoginPage.loginCardMaxWidth, 440);
    });
  });
}
