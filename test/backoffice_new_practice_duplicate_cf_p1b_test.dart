import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_form_field/phone_form_field.dart';
import 'package:postgrest/postgrest.dart';
import 'package:scuola_nautica_liana/data/backoffice_mock/backoffice_demo_store.dart';
import 'package:scuola_nautica_liana/domain/anagrafica/codice_fiscale.dart';
import 'package:scuola_nautica_liana/domain/anagrafica/student_fiscal_code_write_error.dart';
import 'package:scuola_nautica_liana/domain/backoffice/backoffice.dart';
import 'package:scuola_nautica_liana/repositories/backoffice/backoffice_repository_mock.dart';
import 'package:scuola_nautica_liana/widgets/backoffice/backoffice_new_practice_dialog.dart';
import 'package:scuola_nautica_liana/widgets/international_phone_field.dart';

class _DuplicateCfCreateRepo extends BackofficeRepositoryMock {
  int createCalls = 0;
  String? lastFiscalCode;
  bool createdDossier = false;
  bool createdAccess = false;
  bool setFee = false;

  @override
  Future<BackofficeNewStudentOutcome> createBackofficeStudent({
    required String firstName,
    required String lastName,
    String? phone,
    String? phoneCountryIso2,
    String? email,
    String? fiscalCode,
    DateTime? birthDate,
    String? birthPlace,
    String? gender,
    String? address,
    String? city,
    String? province,
    String? cap,
    String? enrolledCoursePath,
    String? enrolledLicenseCategory,
    String? notes,
    bool createPracticeDossier = true,
    String? practiceType,
    DateTime? registrationDate,
    bool assignRegistryNumber = true,
  }) async {
    createCalls++;
    lastFiscalCode = fiscalCode;
    throw const PostgrestException(
      message:
          'duplicate key value violates unique constraint '
          '"students_fiscal_code_normalized_uq"',
      code: '23505',
      details: 'Key (...) already exists.',
    );
  }

  @override
  Future<void> setStudentRegistrationFeeCents({
    required StudentId studentId,
    required int registrationFeeCents,
  }) async {
    setFee = true;
  }

  @override
  Future<StudentAppAccessCredentials> createStudentAppAccess({
    required StudentId studentId,
    required String email,
    required String temporaryPassword,
  }) async {
    createdAccess = true;
    return super.createStudentAppAccess(
      studentId: studentId,
      email: email,
      temporaryPassword: temporaryPassword,
    );
  }
}

Future<void> _fillMinimalAnagrafica(WidgetTester tester) async {
  Future<void> fillHint(String hint, String value) async {
    final field = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText == hint,
    );
    expect(field, findsOneWidget, reason: 'hint "$hint"');
    await tester.enterText(field, value);
    await tester.pump();
  }

  await fillHint('Cognome', 'Rossi');
  await fillHint('Nome', 'Mario');
  await tester.tap(find.widgetWithText(FilterChip, 'Maschio'));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Seleziona data'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('15').last);
  await tester.pumpAndSettle();
  final ok = find.text('OK');
  if (ok.evaluate().isNotEmpty) {
    await tester.tap(ok);
    await tester.pumpAndSettle();
  } else {
    final confirm = find.text('Conferma');
    if (confirm.evaluate().isNotEmpty) {
      await tester.tap(confirm);
      await tester.pumpAndSettle();
    }
  }

  final birthHints = ['Comune o stato estero', 'Cerca il Comune italiano'];
  Finder? birthPlace;
  for (final h in birthHints) {
    final f = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText == h,
    );
    if (f.evaluate().isNotEmpty) {
      birthPlace = f.first;
      break;
    }
  }
  expect(birthPlace, isNotNull);
  await tester.enterText(birthPlace!, 'Napoli');
  await tester.pump();

  await fillHint('Sigla provincia', 'NA');
  // Lowercase senza spazi (formatter CF strippa whitespace in UI).
  await fillHint('Codice fiscale', 'rssmra85t10a562s');
  await fillHint('Via e numero civico', 'Via Roma 1');

  final cityExact = find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.hintText == 'Città',
  );
  if (cityExact.evaluate().isNotEmpty) {
    await tester.enterText(cityExact, 'Napoli');
  } else {
    final citySearch = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          w.decoration?.hintText == 'Cerca il Comune italiano',
    );
    await tester.enterText(citySearch.last, 'Napoli');
  }
  await tester.pump();

  await fillHint('Prov.', 'NA');
  await fillHint('CAP', '80100');

  final glassesNo = find.descendant(
    of: find.byType(AlertDialog),
    matching: find.widgetWithText(FilterChip, 'No'),
  );
  await tester.ensureVisible(glassesNo.last);
  await tester.pumpAndSettle();
  await tester.tap(glassesNo.last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    '12-17. Nuova pratica duplicate CF → friendly, no side effects',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      final spy = _DuplicateCfCreateRepo();
      final profilesBefore = backofficeDemoStore.profiles.length;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(430, 932)),
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
                  onPressed: () => showBackofficeNewPracticeDialog(
                    context,
                    repository: spy,
                  ),
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

      await _fillMinimalAnagrafica(tester);
      await tester.enterText(find.byType(PhoneFormField), '3331234567');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Crea pratica'));
      await tester.tap(find.text('Crea pratica'));
      await tester.pumpAndSettle();

      expect(spy.createCalls, 1);
      expect(spy.lastFiscalCode, CodiceFiscale.normalizza('rssmra85t10a562s'));
      expect(spy.lastFiscalCode, 'RSSMRA85T10A562S');
      expect(
        find.text(StudentFiscalCodeWriteError.userMessage),
        findsOneWidget,
      );
      expect(find.textContaining('students_fiscal_code_normalized_uq'), findsNothing);
      expect(find.textContaining('23505'), findsNothing);
      expect(find.text('Nuova pratica'), findsOneWidget);
      expect(backofficeDemoStore.profiles.length, profilesBefore);
      expect(spy.setFee, isFalse);
      expect(spy.createdAccess, isFalse);
      expect(spy.createdDossier, isFalse);
    },
  );
}
