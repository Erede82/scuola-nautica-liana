import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_form_field/phone_form_field.dart';
import 'package:postgrest/postgrest.dart';
import 'package:scuola_nautica_liana/data/backoffice_mock/backoffice_demo_store.dart';
import 'package:scuola_nautica_liana/domain/anagrafica/codice_fiscale.dart';
import 'package:scuola_nautica_liana/domain/anagrafica/student_fiscal_code_write_error.dart';
import 'package:scuola_nautica_liana/domain/backoffice/backoffice.dart';
import 'package:scuola_nautica_liana/repositories/backoffice/backoffice_repository.dart';
import 'package:scuola_nautica_liana/repositories/backoffice/backoffice_repository_mock.dart';
import 'package:scuola_nautica_liana/widgets/backoffice/edit_student_anagrafica_dialog.dart';
import 'package:scuola_nautica_liana/widgets/international_phone_field.dart';

const _studentId = 'stu-demo-lucia-001';
const _validCf = 'BNCLCU98D52F205T';
const _otherCf = 'RSSMRA85T10A562S';

class _DuplicateCfEditRepo extends BackofficeRepositoryMock {
  int updateCalls = 0;
  int refreshCalls = 0;

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
    throw const PostgrestException(
      message:
          'duplicate key value violates unique constraint '
          '"students_fiscal_code_normalized_uq"',
      code: '23505',
      details: 'Key already exists.',
    );
  }

  @override
  Future<StudentAdmin360View?> getStudentAdmin360(StudentId studentId) async {
    refreshCalls++;
    return super.getStudentAdmin360(studentId);
  }
}

Future<void> _openDialog(
  WidgetTester tester, {
  required BackofficeRepository repository,
  required StudentProfile profile,
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(size: Size(390, 844)),
      child: MaterialApp(
        locale: const Locale('it', 'IT'),
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          ...InternationalPhoneField.localizationsDelegates,
        ],
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
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Apri'));
  await tester.pumpAndSettle();
}

Future<void> _fillRequired(WidgetTester tester, {required String cf}) async {
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
    cf,
  );
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
}

void main() {
  setUp(() {
    final i = backofficeDemoStore.profiles.indexWhere((p) => p.id == _studentId);
    final p = backofficeDemoStore.profiles[i];
    backofficeDemoStore.updateStudentAnagrafica(
      studentId: _studentId,
      firstName: p.firstName,
      lastName: p.lastName,
      fiscalCode: CodiceFiscale.isFormalmenteValido(p.taxCode ?? '')
          ? CodiceFiscale.normalizza(p.taxCode!)
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
  });

  testWidgets('18-22. edit CF occupato → friendly, dialog aperto, no refresh', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final spy = _DuplicateCfEditRepo();
    final profile = backofficeDemoStore.profiles.firstWhere(
      (p) => p.id == _studentId,
    );
    final beforeCf = profile.taxCode;

    await _openDialog(tester, repository: spy, profile: profile);
    await _fillRequired(tester, cf: _otherCf);
    await tester.tap(find.byKey(const ValueKey('edit-anagrafica-save')));
    await tester.pumpAndSettle();

    expect(spy.updateCalls, 1);
    expect(spy.refreshCalls, 0);
    expect(find.text('Modifica anagrafica'), findsWidgets);
    expect(find.text(StudentFiscalCodeWriteError.userMessage), findsOneWidget);
    expect(find.text('Anagrafica aggiornata.'), findsNothing);
    expect(find.textContaining('students_fiscal_code'), findsNothing);
    expect(
      backofficeDemoStore.profiles.firstWhere((p) => p.id == _studentId).taxCode,
      beforeCf,
    );
  });

  testWidgets('23. same CF invariato → save OK', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final profile = backofficeDemoStore.profiles.firstWhere(
      (p) => p.id == _studentId,
    );
    final cf = CodiceFiscale.normalizza(profile.taxCode ?? _validCf);

    await _openDialog(
      tester,
      repository: BackofficeRepositoryMock(),
      profile: profile,
    );
    await _fillRequired(tester, cf: cf);
    await tester.tap(find.byKey(const ValueKey('edit-anagrafica-save')));
    await tester.pumpAndSettle();

    expect(find.text('Modifica anagrafica'), findsNothing);
    expect(
      backofficeDemoStore.profiles.firstWhere((p) => p.id == _studentId).taxCode,
      cf,
    );
  });

  testWidgets('24. same CF whitespace/case → save OK dopo normalizzazione', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final profile = backofficeDemoStore.profiles.firstWhere(
      (p) => p.id == _studentId,
    );
    final cf = CodiceFiscale.normalizza(profile.taxCode ?? _validCf);
    // Case only in UI field (formatter strippa spazi); whitespace covered by unit tests.
    final lower = cf.toLowerCase();

    await _openDialog(
      tester,
      repository: BackofficeRepositoryMock(),
      profile: profile,
    );
    await _fillRequired(tester, cf: lower);
    await tester.tap(find.byKey(const ValueKey('edit-anagrafica-save')));
    await tester.pumpAndSettle();

    expect(find.text('Modifica anagrafica'), findsNothing);
    expect(
      backofficeDemoStore.profiles.firstWhere((p) => p.id == _studentId).taxCode,
      cf,
    );
  });
}
