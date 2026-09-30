import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_form_field/phone_form_field.dart';
import 'package:scuola_nautica_liana/data/backoffice_mock/backoffice_demo_store.dart';
import 'package:scuola_nautica_liana/domain/backoffice/backoffice.dart';
import 'package:scuola_nautica_liana/repositories/backoffice/backoffice_repository.dart';
import 'package:scuola_nautica_liana/repositories/backoffice/backoffice_repository_mock.dart';
import 'package:scuola_nautica_liana/utils/app_access_password_generator.dart';
import 'package:scuola_nautica_liana/widgets/backoffice/edit_student_anagrafica_dialog.dart';
import 'package:scuola_nautica_liana/widgets/international_phone_field.dart';

const _studentId = 'stu-demo-lucia-001';

Widget _app({required Widget home}) {
  return MediaQuery(
    data: const MediaQueryData(size: Size(800, 1200)),
    child: MaterialApp(
      locale: const Locale('it', 'IT'),
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        ...InternationalPhoneField.localizationsDelegates,
      ],
      home: home,
    ),
  );
}

StudentProfile _lucia({String? linkedAuthUserId}) {
  final p = backofficeDemoStore.profiles.firstWhere((x) => x.id == _studentId);
  if (linkedAuthUserId == null) return p;
  return p.copyWith(linkedAuthUserId: linkedAuthUserId);
}

Future<void> _openDialog(
  WidgetTester tester, {
  required BackofficeRepository repository,
  required StudentProfile profile,
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 1200));
  await tester.pumpWidget(
    _app(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () {
              showEditStudentAnagraficaDialog(
                context: context,
                repository: repository,
                profile: profile,
              );
            },
            child: const Text('Apri'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Apri'));
  await tester.pumpAndSettle();
}

Future<void> _tapCreateAppAccess(WidgetTester tester) async {
  final btn = find.byKey(const ValueKey('edit-anagrafica-create-app-access'));
  await tester.ensureVisible(btn);
  await tester.pumpAndSettle();
  await tester.tap(btn);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    backofficeDemoStore.clearStudentAppAccessLink(_studentId);
  });

  tearDown(() {
    backofficeDemoStore.clearStudentAppAccessLink(_studentId);
  });

  test('generateReadableAppAccessPassword length >= 8 (secure)', () {
    final pw = generateReadableAppAccessPassword();
    expect(pw.length, greaterThanOrEqualTo(8));
    expect(pw.length, 14);
  });

  test('generator source uses Random.secure and is shared util', () {
    final util = File(
      'lib/utils/app_access_password_generator.dart',
    ).readAsStringSync();
    expect(util, contains('Random.secure()'));
    expect(util, isNot(contains('Random()')));

    final edit = File(
      'lib/widgets/backoffice/edit_student_anagrafica_dialog.dart',
    ).readAsStringSync();
    expect(edit, contains('app_access_password_generator.dart'));
    expect(edit, isNot(contains("show generateReadableAppAccessPassword")));

    final practice = File(
      'lib/widgets/backoffice/backoffice_new_practice_dialog.dart',
    ).readAsStringSync();
    expect(practice, contains('app_access_password_generator.dart'));
    expect(
      practice,
      isNot(contains('String generateReadableAppAccessPassword')),
    );
  });

  testWidgets('user_id null → sezione Accesso app visibile e prefill email', (
    tester,
  ) async {
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    final profile = _lucia();
    expect(profile.linkedAuthUserId, isNull);

    await _openDialog(
      tester,
      repository: BackofficeRepositoryMock(),
      profile: profile,
    );

    expect(
      find.byKey(const ValueKey('edit-anagrafica-app-access-section')),
      findsOneWidget,
    );
    expect(find.text('Accesso app'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('edit-anagrafica-create-app-access')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('edit-anagrafica-app-access-active')),
      findsNothing,
    );

    final appEmail = tester.widget<TextField>(
      find.byKey(const ValueKey('edit-anagrafica-app-email')),
    );
    expect(appEmail.controller!.text, profile.email ?? '');
  });

  testWidgets('email accesso app modificabile indipendentemente', (
    tester,
  ) async {
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await _openDialog(
      tester,
      repository: BackofficeRepositoryMock(),
      profile: _lucia(),
    );

    await tester.enterText(
      find.byKey(const ValueKey('edit-anagrafica-app-email')),
      'altro.accesso@example.com',
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('edit-anagrafica-email')),
      'anagrafica@example.com',
    );
    await tester.pump();

    final appEmail = tester.widget<TextField>(
      find.byKey(const ValueKey('edit-anagrafica-app-email')),
    );
    final anagEmail = tester.widget<TextField>(
      find.byKey(const ValueKey('edit-anagrafica-email')),
    );
    expect(appEmail.controller!.text, 'altro.accesso@example.com');
    expect(anagEmail.controller!.text, 'anagrafica@example.com');
  });

  testWidgets('password nascosta di default; toggle mostra/nascondi', (
    tester,
  ) async {
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await _openDialog(
      tester,
      repository: BackofficeRepositoryMock(),
      profile: _lucia(),
    );

    final pwField = tester.widget<TextField>(
      find.byKey(const ValueKey('edit-anagrafica-app-password')),
    );
    expect(pwField.obscureText, isTrue);

    await tester.ensureVisible(
      find.byKey(const ValueKey('edit-anagrafica-app-password-toggle')),
    );
    await tester.tap(
      find.byKey(const ValueKey('edit-anagrafica-app-password-toggle')),
    );
    await tester.pump();
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('edit-anagrafica-app-password')),
          )
          .obscureText,
      isFalse,
    );
  });

  testWidgets(
    'password <8 rifiutata; >=8 accettata con createStudentAppAccess',
    (tester) async {
      addTearDown(() async => tester.binding.setSurfaceSize(null));

      final spy = _SpyAppAccessRepo();
      await _openDialog(tester, repository: spy, profile: _lucia());

      await tester.ensureVisible(
        find.byKey(const ValueKey('edit-anagrafica-app-password')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('edit-anagrafica-app-password')),
        'short',
      );
      await _tapCreateAppAccess(tester);

      expect(spy.createCalls, 0);
      expect(
        find.byKey(const ValueKey('edit-anagrafica-error')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('edit-anagrafica-error')))
            .data,
        contains('8 caratteri'),
      );

      await tester.enterText(
        find.byKey(const ValueKey('edit-anagrafica-app-email')),
        'lucia.app@example.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey('edit-anagrafica-app-password')),
        'SecurePass1',
      );
      await _tapCreateAppAccess(tester);

      expect(spy.createCalls, 1);
      expect(spy.lastStudentId, _studentId);
      expect(spy.lastEmail, 'lucia.app@example.com');
      expect(spy.lastPassword, 'SecurePass1');
      expect(find.text('Accesso app creato'), findsOneWidget);
      expect(find.textContaining('SecurePass1'), findsOneWidget);

      await tester.tap(find.text('Chiudi'));
      await tester.pumpAndSettle();
      expect(find.text('Modifica anagrafica'), findsNothing);

      final after = backofficeDemoStore.profiles.firstWhere(
        (p) => p.id == _studentId,
      );
      expect(after.linkedAuthUserId, isNotNull);
    },
  );

  testWidgets('Genera password produce valore valido >= 8', (tester) async {
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await _openDialog(
      tester,
      repository: BackofficeRepositoryMock(),
      profile: _lucia(),
    );

    final gen = find.byKey(
      const ValueKey('edit-anagrafica-app-generate-password'),
    );
    await tester.ensureVisible(gen);
    await tester.tap(gen);
    await tester.pump();

    final pw = tester
        .widget<TextField>(
          find.byKey(const ValueKey('edit-anagrafica-app-password')),
        )
        .controller!
        .text;
    expect(pw.length, greaterThanOrEqualTo(8));
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('edit-anagrafica-app-password')),
          )
          .obscureText,
      isFalse,
    );
  });

  testWidgets('user_id presente → Accesso app attivo, no password/create', (
    tester,
  ) async {
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    final profile = _lucia(linkedAuthUserId: 'auth-user-already');
    await _openDialog(
      tester,
      repository: BackofficeRepositoryMock(),
      profile: profile,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('edit-anagrafica-app-access-active')),
    );
    expect(
      find.byKey(const ValueKey('edit-anagrafica-app-access-active')),
      findsOneWidget,
    );
    expect(find.text('Accesso app attivo'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('edit-anagrafica-app-password')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('edit-anagrafica-create-app-access')),
      findsNothing,
    );
  });

  testWidgets('Salva anagrafica NON crea Auth automaticamente', (tester) async {
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    final spy = _SpyAppAccessRepo();
    final profile = _lucia();
    await _openDialog(tester, repository: spy, profile: profile);

    // Ensure CF formally valid (demo seed may use a non-checkdigit value).
    await tester.enterText(
      find.byKey(const ValueKey('edit-anagrafica-fiscal-code')),
      'BNCLCU98D52F205T',
    );
    await tester.tap(
      find.byKey(const ValueKey('edit-anagrafica-gender-female')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('edit-anagrafica-birth-place')),
      'Milano',
    );
    await tester.enterText(
      find.byKey(const ValueKey('edit-anagrafica-address')),
      'Via del Porto 12',
    );
    await tester.enterText(
      find.byKey(const ValueKey('edit-anagrafica-city')),
      'Milano',
    );
    await tester.enterText(
      find.byKey(const ValueKey('edit-anagrafica-cap')),
      '20100',
    );
    await tester.enterText(
      find.byKey(const ValueKey('edit-anagrafica-province')),
      'MI',
    );
    await tester.enterText(find.byType(PhoneFormField), '3200000001');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('edit-anagrafica-last-name')),
      'Bianchi',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('edit-anagrafica-save')),
    );
    await tester.tap(find.byKey(const ValueKey('edit-anagrafica-save')));
    await tester.pumpAndSettle();

    expect(spy.createCalls, 0);
    expect(spy.updateCalls, 1);
  });

  testWidgets('errore Auth → dialog resta aperto, accesso non attivo', (
    tester,
  ) async {
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    final spy = _FailingAppAccessRepo();
    await _openDialog(tester, repository: spy, profile: _lucia());

    await tester.ensureVisible(
      find.byKey(const ValueKey('edit-anagrafica-app-email')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('edit-anagrafica-app-email')),
      'dup@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('edit-anagrafica-app-password')),
      'SecurePass1',
    );
    await _tapCreateAppAccess(tester);

    expect(find.text('Modifica anagrafica'), findsOneWidget);
    expect(find.byKey(const ValueKey('edit-anagrafica-error')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('edit-anagrafica-app-access-active')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('edit-anagrafica-create-app-access')),
      findsOneWidget,
    );

    final after = backofficeDemoStore.profiles.firstWhere(
      (p) => p.id == _studentId,
    );
    expect(after.linkedAuthUserId, isNull);
  });

  testWidgets('double tap Crea accesso app → una sola createStudentAppAccess', (
    tester,
  ) async {
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    final spy = _SlowSpyAppAccessRepo();
    await _openDialog(tester, repository: spy, profile: _lucia());

    await tester.ensureVisible(
      find.byKey(const ValueKey('edit-anagrafica-app-email')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('edit-anagrafica-app-email')),
      'double.tap@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('edit-anagrafica-app-password')),
      'SecurePass1',
    );

    final btn = find.byKey(const ValueKey('edit-anagrafica-create-app-access'));
    await tester.ensureVisible(btn);
    await tester.pumpAndSettle();
    await tester.tap(btn);
    await tester.pump(); // start loading; do not settle yet
    await tester.tap(btn, warnIfMissed: false);
    await tester.pump();
    expect(spy.createCalls, 1);

    // Button should be disabled while in-flight (onPressed null).
    final tonal = tester.widget<FilledButton>(btn);
    expect(tonal.onPressed, isNull);

    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(spy.createCalls, 1);
    expect(find.text('Accesso app creato'), findsOneWidget);
    await tester.tap(find.text('Chiudi'));
    await tester.pumpAndSettle();
  });

  testWidgets('retry dopo errore Auth: password resta e seconda create OK', (
    tester,
  ) async {
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    final spy = _FailThenSucceedAppAccessRepo();
    await _openDialog(tester, repository: spy, profile: _lucia());

    await tester.ensureVisible(
      find.byKey(const ValueKey('edit-anagrafica-app-email')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('edit-anagrafica-app-email')),
      'retry@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('edit-anagrafica-app-password')),
      'RetryPass12',
    );
    await _tapCreateAppAccess(tester);

    expect(find.text('Modifica anagrafica'), findsOneWidget);
    expect(find.byKey(const ValueKey('edit-anagrafica-error')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('edit-anagrafica-app-access-active')),
      findsNothing,
    );
    final pwAfterFail = tester
        .widget<TextField>(
          find.byKey(const ValueKey('edit-anagrafica-app-password')),
        )
        .controller!
        .text;
    expect(pwAfterFail, 'RetryPass12');
    expect(spy.createCalls, 1);

    await _tapCreateAppAccess(tester);
    expect(spy.createCalls, 2);
    expect(spy.lastPassword, 'RetryPass12');
    expect(find.text('Accesso app creato'), findsOneWidget);
    await tester.tap(find.text('Chiudi'));
    await tester.pumpAndSettle();

    final after = backofficeDemoStore.profiles.firstWhere(
      (p) => p.id == _studentId,
    );
    expect(after.linkedAuthUserId, isNotNull);
  });

  testWidgets('reopen dopo link → Accesso app attivo, no seconda creazione', (
    tester,
  ) async {
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    final spy = _SpyAppAccessRepo();
    await _openDialog(tester, repository: spy, profile: _lucia());
    await tester.ensureVisible(
      find.byKey(const ValueKey('edit-anagrafica-app-email')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('edit-anagrafica-app-email')),
      'reopen@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('edit-anagrafica-app-password')),
      'ReopenPass1',
    );
    await _tapCreateAppAccess(tester);
    expect(find.text('Accesso app creato'), findsOneWidget);
    await tester.tap(find.text('Chiudi'));
    await tester.pumpAndSettle();

    final linked = backofficeDemoStore.profiles.firstWhere(
      (p) => p.id == _studentId,
    );
    expect(linked.linkedAuthUserId, isNotNull);

    // Re-open dialog with linked profile (post-refresh state).
    await _openDialog(tester, repository: spy, profile: linked);
    await tester.ensureVisible(
      find.byKey(const ValueKey('edit-anagrafica-app-access-active')),
    );
    expect(find.text('Accesso app attivo'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('edit-anagrafica-app-password')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('edit-anagrafica-create-app-access')),
      findsNothing,
    );
    final createCallsAfterReopen = spy.createCalls;
    // No create button → no further Auth creation possible from UI.
    expect(createCallsAfterReopen, 1);
  });
}

class _SpyAppAccessRepo extends BackofficeRepositoryMock {
  int createCalls = 0;
  int updateCalls = 0;
  String? lastStudentId;
  String? lastEmail;
  String? lastPassword;

  @override
  Future<void> updateStudentAnagrafica({
    required StudentId studentId,
    required String firstName,
    required String lastName,
    required String fiscalCode,
    required DateTime birthDate,
    required String birthPlace,
    required String gender,
    required String address,
    required String city,
    required String province,
    required String cap,
    required String phoneE164,
    required String phoneCountryIso2,
    String? email,
  }) async {
    updateCalls++;
    await super.updateStudentAnagrafica(
      studentId: studentId,
      firstName: firstName,
      lastName: lastName,
      fiscalCode: fiscalCode,
      birthDate: birthDate,
      birthPlace: birthPlace,
      gender: gender,
      address: address,
      city: city,
      province: province,
      cap: cap,
      phoneE164: phoneE164,
      phoneCountryIso2: phoneCountryIso2,
      email: email,
    );
  }

  @override
  Future<StudentAppAccessCredentials> createStudentAppAccess({
    required StudentId studentId,
    required String email,
    required String temporaryPassword,
  }) async {
    createCalls++;
    lastStudentId = studentId;
    lastEmail = email.trim().toLowerCase();
    lastPassword = temporaryPassword;
    return super.createStudentAppAccess(
      studentId: studentId,
      email: email,
      temporaryPassword: temporaryPassword,
    );
  }
}

class _FailingAppAccessRepo extends BackofficeRepositoryMock {
  @override
  Future<StudentAppAccessCredentials> createStudentAppAccess({
    required StudentId studentId,
    required String email,
    required String temporaryPassword,
  }) async {
    throw StateError(
      'Questa email è già registrata per un altro account. '
      'Usa un’indirizzo diverso o gestisci l’utente da console.',
    );
  }
}

class _SlowSpyAppAccessRepo extends _SpyAppAccessRepo {
  @override
  Future<StudentAppAccessCredentials> createStudentAppAccess({
    required StudentId studentId,
    required String email,
    required String temporaryPassword,
  }) async {
    createCalls++;
    lastStudentId = studentId;
    lastEmail = email.trim().toLowerCase();
    lastPassword = temporaryPassword;
    await Future<void>.delayed(const Duration(milliseconds: 200));
    // Bypass _SpyAppAccessRepo.create (would double-count) → store link only.
    return BackofficeRepositoryMock().createStudentAppAccess(
      studentId: studentId,
      email: email,
      temporaryPassword: temporaryPassword,
    );
  }
}

class _FailThenSucceedAppAccessRepo extends BackofficeRepositoryMock {
  int createCalls = 0;
  String? lastPassword;

  @override
  Future<StudentAppAccessCredentials> createStudentAppAccess({
    required StudentId studentId,
    required String email,
    required String temporaryPassword,
  }) async {
    createCalls++;
    lastPassword = temporaryPassword;
    if (createCalls == 1) {
      throw StateError(
        'Questa email è già registrata per un altro account. '
        'Usa un’indirizzo diverso o gestisci l’utente da console.',
      );
    }
    return super.createStudentAppAccess(
      studentId: studentId,
      email: email,
      temporaryPassword: temporaryPassword,
    );
  }
}
