import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/models/student_registration.dart';
import 'package:scuola_nautica_liana/pages/forgot_password_page.dart';
import 'package:scuola_nautica_liana/pages/login_page.dart';
import 'package:scuola_nautica_liana/pages/student_registration_page.dart';
import 'package:scuola_nautica_liana/repositories/student_auth_repository.dart';

class _FakeAuth implements StudentAuthRepository {
  _FakeAuth({
    this.result,
    this.delay,
  });

  StudentLoginResult? result;
  Duration? delay;
  int signInCalls = 0;
  final signInStarted = Completer<void>();

  @override
  Future<StudentLoginResult> signIn({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    if (!signInStarted.isCompleted) signInStarted.complete();
    final wait = delay;
    if (wait != null) await Future<void>.delayed(wait);
    return result ?? StudentLoginResult.error('Email o password non corrette');
  }

  @override
  Future<StudentRegistrationResult> register(
    StudentRegistrationRequest request,
  ) async =>
      StudentRegistrationResult.error('unused');

  @override
  Future<void> restoreSessionIfAvailable() async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<String?> requestPasswordReset({required String email}) async => null;

  @override
  Future<void> signInWithGoogle() async {}
}

Future<void> _pumpLogin(
  WidgetTester tester, {
  required _FakeAuth auth,
  Size size = const Size(1366, 768),
  bool pushRoute = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final login = LoginPage(authRepository: auth);

  if (!pushRoute) {
    await tester.pumpWidget(MaterialApp(home: login));
    await tester.pumpAndSettle();
    return;
  }

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => login),
                );
              },
              child: const Text('OpenLogin'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('OpenLogin'));
  await tester.pumpAndSettle();
}

Future<void> _fillValidCredentials(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('login_email_field')),
    'allieva@test.com',
  );
  await tester.enterText(
    find.byKey(const Key('login_password_field')),
    'Password1!',
  );
  await tester.pump();
}

Future<void> _focusPassword(WidgetTester tester) async {
  final editable = find.descendant(
    of: find.byKey(const Key('login_password_field')),
    matching: find.byType(EditableText),
  );
  await tester.tap(editable);
  await tester.pump();
}

Future<void> _focusEmail(WidgetTester tester) async {
  final editable = find.descendant(
    of: find.byKey(const Key('login_email_field')),
    matching: find.byType(EditableText),
  );
  await tester.tap(editable);
  await tester.pump();
}

Future<void> _pressEnter(
  WidgetTester tester, {
  LogicalKeyboardKey key = LogicalKeyboardKey.enter,
}) async {
  await tester.sendKeyDownEvent(key);
  await tester.pump();
  await tester.sendKeyUpEvent(key);
  await tester.pump();
}

Future<void> _pressEnterWithRepeat(
  WidgetTester tester, {
  LogicalKeyboardKey key = LogicalKeyboardKey.enter,
}) async {
  await tester.sendKeyDownEvent(key);
  await tester.pump();
  await tester.sendKeyRepeatEvent(key);
  await tester.pump();
  await tester.sendKeyUpEvent(key);
  await tester.pump();
}

void main() {
  group('AUTH.LOGIN.ENTER.FIX.1', () {
    testWidgets('email Enter → password focus, 0 auth, 0 navigation', (
      tester,
    ) async {
      final auth = _FakeAuth();
      await _pumpLogin(tester, auth: auth);
      await tester.enterText(
        find.byKey(const Key('login_email_field')),
        'allieva@test.com',
      );
      await _focusEmail(tester);

      await _pressEnter(tester);
      await tester.pump();

      expect(auth.signInCalls, 0);
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.text('OpenLogin'), findsNothing);

      final passwordEditable = find.descendant(
        of: find.byKey(const Key('login_password_field')),
        matching: find.byType(EditableText),
      );
      final editable = tester.widget<EditableText>(passwordEditable);
      expect(editable.focusNode.hasFocus, isTrue);
    });

    testWidgets('password Enter success → exactly 1 signIn + same pop as Accedi', (
      tester,
    ) async {
      final auth = _FakeAuth(result: StudentLoginResult.ok());
      await _pumpLogin(tester, auth: auth);
      await _fillValidCredentials(tester);
      await _focusPassword(tester);

      await _pressEnter(tester);
      await tester.pumpAndSettle();

      expect(auth.signInCalls, 1);
      expect(find.byType(LoginPage), findsNothing);
      expect(find.text('OpenLogin'), findsOneWidget);
    });

    testWidgets('click Accedi and password Enter share submit path', (
      tester,
    ) async {
      final authEnter = _FakeAuth(result: StudentLoginResult.ok());
      await _pumpLogin(tester, auth: authEnter);
      await _fillValidCredentials(tester);
      await _focusPassword(tester);
      await _pressEnter(tester);
      await tester.pumpAndSettle();
      expect(authEnter.signInCalls, 1);
      expect(find.byType(LoginPage), findsNothing);

      final authClick = _FakeAuth(result: StudentLoginResult.ok());
      await _pumpLogin(tester, auth: authClick);
      await _fillValidCredentials(tester);
      await tester.tap(find.byKey(const Key('login_submit')));
      await tester.pumpAndSettle();
      expect(authClick.signInCalls, 1);
      expect(find.byType(LoginPage), findsNothing);
    });

    testWidgets('invalid credentials + Enter → 1 call, stay on login', (
      tester,
    ) async {
      final auth = _FakeAuth(
        result: StudentLoginResult.error('Email o password non corrette'),
      );
      await _pumpLogin(tester, auth: auth);
      await _fillValidCredentials(tester);
      await _focusPassword(tester);

      await _pressEnter(tester);
      await tester.pumpAndSettle();

      expect(auth.signInCalls, 1);
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.text('OpenLogin'), findsNothing);
      expect(find.text('Email o password non corrette'), findsOneWidget);
    });

    testWidgets('empty form + Enter → validation, 0 auth, stay', (tester) async {
      final auth = _FakeAuth();
      await _pumpLogin(tester, auth: auth);
      await _focusPassword(tester);

      await _pressEnter(tester);
      await tester.pumpAndSettle();

      expect(auth.signInCalls, 0);
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.text('Inserisci l’email.'), findsOneWidget);
      expect(find.text('Inserisci la password.'), findsOneWidget);
    });

    testWidgets('double Enter while pending → single signIn', (tester) async {
      final auth = _FakeAuth(
        result: StudentLoginResult.ok(),
        delay: const Duration(milliseconds: 300),
      );
      await _pumpLogin(tester, auth: auth);
      await _fillValidCredentials(tester);
      await _focusPassword(tester);

      await _pressEnter(tester);
      await _pressEnter(tester);
      await tester.pump();
      await auth.signInStarted.future;
      expect(auth.signInCalls, 1);

      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(auth.signInCalls, 1);
    });

    testWidgets('button Accedi regression still works', (tester) async {
      final auth = _FakeAuth(result: StudentLoginResult.ok());
      await _pumpLogin(tester, auth: auth);
      await _fillValidCredentials(tester);
      await tester.tap(find.byKey(const Key('login_submit')));
      await tester.pumpAndSettle();
      expect(auth.signInCalls, 1);
      expect(find.byType(LoginPage), findsNothing);
    });

    testWidgets('password Enter does not open Registrati / Forgot', (
      tester,
    ) async {
      final auth = _FakeAuth(
        result: StudentLoginResult.error('fail'),
      );
      await _pumpLogin(tester, auth: auth);
      await _fillValidCredentials(tester);
      await _focusPassword(tester);
      await _pressEnter(tester);
      await tester.pumpAndSettle();

      expect(find.byType(StudentRegistrationPage), findsNothing);
      expect(find.byType(ForgotPasswordPage), findsNothing);
      expect(find.byType(LoginPage), findsOneWidget);
    });

    testWidgets('IME Done on password also submits once', (tester) async {
      final auth = _FakeAuth(result: StudentLoginResult.ok());
      await _pumpLogin(tester, auth: auth);
      await _fillValidCredentials(tester);
      await _focusPassword(tester);

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(auth.signInCalls, 1);
      expect(find.byType(LoginPage), findsNothing);
    });

    testWidgets('KeyRepeat Enter on password → single signIn', (tester) async {
      final auth = _FakeAuth(result: StudentLoginResult.ok());
      await _pumpLogin(tester, auth: auth);
      await _fillValidCredentials(tester);
      await _focusPassword(tester);

      await _pressEnterWithRepeat(tester);
      await tester.pumpAndSettle();

      expect(auth.signInCalls, 1);
      expect(find.byType(LoginPage), findsNothing);
    });

    testWidgets('invalid form + held Enter → no auth, no Back navigation', (
      tester,
    ) async {
      final auth = _FakeAuth();
      await _pumpLogin(tester, auth: auth);
      await _focusPassword(tester);

      await _pressEnterWithRepeat(tester);
      await tester.pumpAndSettle();

      expect(auth.signInCalls, 0);
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.text('OpenLogin'), findsNothing);
      expect(find.text('Inserisci l’email.'), findsOneWidget);
    });

    testWidgets('Enter during loading after unfocus → still 1 signIn', (
      tester,
    ) async {
      final auth = _FakeAuth(
        result: StudentLoginResult.ok(),
        delay: const Duration(milliseconds: 400),
      );
      await _pumpLogin(tester, auth: auth);
      await _fillValidCredentials(tester);
      await _focusPassword(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await auth.signInStarted.future;
      expect(auth.signInCalls, 1);
      expect(find.byType(LoginPage), findsOneWidget);

      // Dopo unfocus (loading), Enter non deve poppare via Back/ActivateIntent.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(auth.signInCalls, 1);
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.text('OpenLogin'), findsNothing);

      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      expect(auth.signInCalls, 1);
      expect(find.byType(LoginPage), findsNothing);
      expect(find.text('OpenLogin'), findsOneWidget);
    });

    testWidgets('Numpad Enter + repeat → single submit', (tester) async {
      final auth = _FakeAuth(result: StudentLoginResult.ok());
      await _pumpLogin(tester, auth: auth);
      await _fillValidCredentials(tester);
      await _focusPassword(tester);

      await _pressEnterWithRepeat(
        tester,
        key: LogicalKeyboardKey.numpadEnter,
      );
      await tester.pumpAndSettle();

      expect(auth.signInCalls, 1);
      expect(find.byType(LoginPage), findsNothing);
    });

    testWidgets('visibility IconButton Enter toggles, no submit', (
      tester,
    ) async {
      final auth = _FakeAuth();
      await _pumpLogin(tester, auth: auth);
      await _fillValidCredentials(tester);

      final editable = find.descendant(
        of: find.byKey(const Key('login_password_field')),
        matching: find.byType(EditableText),
      );
      expect(tester.widget<EditableText>(editable).obscureText, isTrue);

      final visibility = find.byKey(const Key('login_password_visibility'));
      final visibilityNode =
          tester.widget<IconButton>(visibility).focusNode!;
      visibilityNode.requestFocus();
      await tester.pump();
      expect(visibilityNode.hasFocus, isTrue);

      await _pressEnter(tester);
      await tester.pump();

      expect(auth.signInCalls, 0);
      expect(find.byType(LoginPage), findsOneWidget);
      // Enter su IconButton: ActivateIntent nativo → toggle.
      expect(tester.widget<EditableText>(editable).obscureText, isFalse);
    });

    testWidgets('Accedi button focus + Enter → native 1 submit', (
      tester,
    ) async {
      final auth = _FakeAuth(result: StudentLoginResult.ok());
      await _pumpLogin(tester, auth: auth);
      await _fillValidCredentials(tester);

      final submit = find.byKey(const Key('login_submit'));
      await tester.ensureVisible(submit);
      final submitNode = tester.widget<FilledButton>(submit).focusNode!;
      submitNode.requestFocus();
      await tester.pump();
      expect(submitNode.hasFocus, isTrue);

      await _pressEnter(tester);
      await tester.pumpAndSettle();

      expect(auth.signInCalls, 1);
      expect(find.byType(LoginPage), findsNothing);
    });

    testWidgets('Registrati focus + Enter → only registration route', (
      tester,
    ) async {
      final auth = _FakeAuth();
      await _pumpLogin(tester, auth: auth);

      final register = find.byKey(const Key('login_create_account'));
      await tester.ensureVisible(register);
      final registerNode =
          tester.widget<OutlinedButton>(register).focusNode!;
      registerNode.requestFocus();
      await tester.pump();
      expect(registerNode.hasFocus, isTrue);

      await _pressEnter(tester);
      await tester.pumpAndSettle();

      expect(auth.signInCalls, 0);
      expect(find.byType(StudentRegistrationPage), findsOneWidget);
      expect(find.byType(ForgotPasswordPage), findsNothing);
    });

    testWidgets('Forgot focus + Enter → only forgot route', (tester) async {
      final auth = _FakeAuth();
      await _pumpLogin(tester, auth: auth);

      final forgot = find.byKey(const Key('login_forgot_password'));
      await tester.ensureVisible(forgot);
      final forgotNode = tester.widget<TextButton>(forgot).focusNode!;
      forgotNode.requestFocus();
      await tester.pump();
      expect(forgotNode.hasFocus, isTrue);

      await _pressEnter(tester);
      await tester.pumpAndSettle();

      expect(auth.signInCalls, 0);
      expect(find.byType(ForgotPasswordPage), findsOneWidget);
      expect(find.byType(StudentRegistrationPage), findsNothing);
    });

    for (final size in const [
      Size(390, 844),
      Size(768, 1024),
      Size(1366, 768),
      Size(1440, 900),
    ]) {
      testWidgets('responsive ${size.width.toInt()} no overflow', (
        tester,
      ) async {
        final auth = _FakeAuth();
        await _pumpLogin(tester, auth: auth, size: size, pushRoute: false);
        expect(find.byKey(const Key('login_submit')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
