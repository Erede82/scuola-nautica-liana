import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_form_field/phone_form_field.dart';
import 'package:scuola_nautica_liana/data/backoffice_mock/backoffice_demo_store.dart';
import 'package:scuola_nautica_liana/domain/anagrafica/codice_fiscale.dart';
import 'package:scuola_nautica_liana/domain/backoffice/backoffice.dart';
import 'package:scuola_nautica_liana/pages/backoffice/student_360_direct_page.dart';
import 'package:scuola_nautica_liana/repositories/backoffice/backoffice_repository_mock.dart';
import 'package:scuola_nautica_liana/widgets/backoffice/edit_student_anagrafica_dialog.dart';
import 'package:scuola_nautica_liana/widgets/international_phone_field.dart';

const _studentId = 'stu-demo-lucia-001';
const _validCf = 'BNCLCU98D52F205T';

Future<void> _restoreLucia() async {
  final p = backofficeDemoStore.profiles.firstWhere((x) => x.id == _studentId);
  // Restore via known seed-ish values if already mutated mid-suite elsewhere.
  backofficeDemoStore.updateStudentAnagrafica(
    studentId: _studentId,
    firstName: 'Lucia',
    lastName: 'Bianchi',
    fiscalCode: p.taxCode ?? 'BNCLCU98D52F205X',
    birthDate: p.birthDate ?? DateTime(1998, 4, 12),
    birthPlace: p.birthPlace ?? 'Milano',
    gender: p.gender ?? 'Femmina',
    address: 'Via del Porto 12',
    city: 'Milano',
    province: 'MI',
    cap: '20100',
    phoneE164: p.phone ?? '+393200000001',
    phoneCountryIso2: p.phoneCountryIso2 ?? 'IT',
    email: p.email ?? 'lucia.bianchi@example.com',
  );
}

Widget _app({
  required Size size,
  required Widget home,
}) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: MaterialApp(
      locale: const Locale('it', 'IT'),
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        ...InternationalPhoneField.localizationsDelegates,
      ],
      home: home,
      scaffoldMessengerKey: GlobalKey<ScaffoldMessengerState>(),
    ),
  );
}

Future<void> _fillRequiredAnagrafica(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const ValueKey('edit-anagrafica-first-name')),
    'Lucia',
  );
  await tester.enterText(
    find.byKey(const ValueKey('edit-anagrafica-last-name')),
    'Bianchi',
  );
  await tester.tap(find.byKey(const ValueKey('edit-anagrafica-gender-female')));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey('edit-anagrafica-fiscal-code')),
    _validCf,
  );
  // birth date already prefilled if present; otherwise pick via button is hard — set via profile
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
    find.byKey(const ValueKey('edit-anagrafica-email')),
    'lucia.bianchi@example.com',
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    // Ensure birthDate present for save without date picker.
    final i = backofficeDemoStore.profiles.indexWhere((p) => p.id == _studentId);
    final p = backofficeDemoStore.profiles[i];
    if (p.birthDate == null || p.gender == null || p.birthPlace == null) {
      backofficeDemoStore.updateStudentAnagrafica(
        studentId: _studentId,
        firstName: p.firstName,
        lastName: p.lastName,
        fiscalCode: CodiceFiscale.isFormalmenteValido(p.taxCode ?? '')
            ? p.taxCode!
            : _validCf,
        birthDate: p.birthDate ?? DateTime(1998, 4, 12),
        birthPlace: p.birthPlace ?? 'Milano',
        gender: p.gender ?? 'Femmina',
        address: p.address?.streetLine1 ?? 'Via del Porto 12',
        city: p.address?.city ?? 'Milano',
        province: p.address?.provinceCode ?? 'MI',
        cap: p.address?.postalCode ?? '20100',
        phoneE164: p.phone ?? '+393200000001',
        phoneCountryIso2: p.phoneCountryIso2 ?? 'IT',
        email: p.email,
      );
    }
  });

  testWidgets('16. dialog apre precompilato', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      await _restoreLucia();
    });

    final profile = backofficeDemoStore.profiles.firstWhere(
      (p) => p.id == _studentId,
    );

    await tester.pumpWidget(
      _app(
        size: const Size(390, 844),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                showEditStudentAnagraficaDialog(
                  context: context,
                  repository: BackofficeRepositoryMock(),
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

    expect(find.text('Modifica anagrafica'), findsWidgets);
    expect(
      find.byKey(const ValueKey('edit-anagrafica-first-name')),
      findsOneWidget,
    );
    final first = tester.widget<TextField>(
      find.byKey(const ValueKey('edit-anagrafica-first-name')),
    );
    expect(first.controller!.text, profile.firstName);
    final email = tester.widget<TextField>(
      find.byKey(const ValueKey('edit-anagrafica-email')),
    );
    expect(email.controller!.text, profile.email ?? '');
  });

  testWidgets('17-22. save valido → refresh/snackbar/dialog chiuso', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      await _restoreLucia();
    });

    final messengerKey = GlobalKey<ScaffoldMessengerState>();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(390, 844)),
        child: MaterialApp(
          locale: const Locale('it', 'IT'),
          scaffoldMessengerKey: messengerKey,
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            ...InternationalPhoneField.localizationsDelegates,
          ],
          home: const Student360DirectPage(studentId: _studentId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final editBtn = find.byKey(const ValueKey('student-360-edit-anagrafica'));
    expect(editBtn, findsOneWidget);
    await tester.ensureVisible(editBtn);
    await tester.tap(editBtn);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('edit-anagrafica-last-name')),
      'Verdi',
    );
    await tester.tap(find.byKey(const ValueKey('edit-anagrafica-gender-female')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('edit-anagrafica-fiscal-code')),
      _validCf,
    );
    await tester.enterText(
      find.byKey(const ValueKey('edit-anagrafica-birth-place')),
      'Milano',
    );
    await tester.enterText(find.byType(PhoneFormField), '3200000001');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('edit-anagrafica-save')));
    await tester.pumpAndSettle();

    expect(find.text('Modifica anagrafica'), findsNothing);
    expect(find.text('Anagrafica aggiornata.'), findsOneWidget);
    expect(find.textContaining('Verdi'), findsWidgets);

    final after = backofficeDemoStore.profiles.firstWhere(
      (p) => p.id == _studentId,
    );
    expect(after.lastName, 'Verdi');
    expect(after.taxCode, _validCf);
  });

  testWidgets('18-19. errore → dialog resta aperto, double-submit bloccato', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final spy = _SlowFailAnagraficaRepo();
    final profile = backofficeDemoStore.profiles.firstWhere(
      (p) => p.id == _studentId,
    );

    await tester.pumpWidget(
      _app(
        size: const Size(390, 844),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                showEditStudentAnagraficaDialog(
                  context: context,
                  repository: spy,
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

    await _fillRequiredAnagrafica(tester);

    final save = find.byKey(const ValueKey('edit-anagrafica-save'));
    await tester.tap(save);
    await tester.tap(save);
    await tester.pump(); // busy
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(spy.updateCalls, 1);
    expect(find.text('Modifica anagrafica'), findsWidgets);
    expect(
      find.text('Impossibile aggiornare l’anagrafica. Riprova tra poco.'),
      findsOneWidget,
    );
    expect(find.textContaining('Postgrest'), findsNothing);
  });

  testWidgets('23. Auth linked → disclaimer presente', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final profile = backofficeDemoStore.profiles
        .firstWhere((p) => p.id == _studentId)
        .copyWith(linkedAuthUserId: 'auth-user-linked-1');

    await tester.pumpWidget(
      _app(
        size: const Size(390, 844),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                showEditStudentAnagraficaDialog(
                  context: context,
                  repository: BackofficeRepositoryMock(),
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

    expect(
      find.byKey(const ValueKey('edit-anagrafica-auth-email-disclaimer')),
      findsOneWidget,
    );
    expect(
      find.text('L’email di accesso all’app non viene modificata.'),
      findsOneWidget,
    );
  });

  testWidgets('24. Auth non linked → disclaimer assente', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final profile = backofficeDemoStore.profiles
        .firstWhere((p) => p.id == _studentId)
        .copyWith(clearLinkedAuthUserId: true);

    await tester.pumpWidget(
      _app(
        size: const Size(390, 844),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                showEditStudentAnagraficaDialog(
                  context: context,
                  repository: BackofficeRepositoryMock(),
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

    expect(
      find.byKey(const ValueKey('edit-anagrafica-auth-email-disclaimer')),
      findsNothing,
    );
  });

  testWidgets('25. responsive mobile ~390px', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      _app(
        size: const Size(390, 844),
        home: const Student360DirectPage(studentId: _studentId),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('student-360-edit-anagrafica')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('26-27. foto/firma + shortcut telefono invariati', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      _app(
        size: const Size(390, 844),
        home: const Student360DirectPage(studentId: _studentId),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('student-360-edit-phone')), findsOneWidget);
    expect(find.byKey(const ValueKey('student-360-edit-anagrafica')), findsOneWidget);
    // Photo/signature section still present (labels from existing UI).
    expect(find.textContaining('Foto'), findsWidgets);
  });
}

class _SlowFailAnagraficaRepo extends BackofficeRepositoryMock {
  int updateCalls = 0;

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
    await Future<void>.delayed(const Duration(milliseconds: 80));
    throw StateError('PostgrestException(message: boom)');
  }
}
