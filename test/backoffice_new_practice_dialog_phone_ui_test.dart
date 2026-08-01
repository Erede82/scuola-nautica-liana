import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_form_field/phone_form_field.dart';
import 'package:scuola_nautica_liana/domain/backoffice/backoffice.dart';
import 'package:scuola_nautica_liana/domain/international_phone.dart';
import 'package:scuola_nautica_liana/repositories/backoffice/backoffice_repository_mock.dart';
import 'package:scuola_nautica_liana/widgets/backoffice/backoffice_new_practice_dialog.dart';
import 'package:scuola_nautica_liana/widgets/international_phone_field.dart';

class _SpyCreateRepo extends BackofficeRepositoryMock {
  int createCalls = 0;
  String? lastPhone;
  String? lastPhoneCountryIso2;

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
    lastPhone = phone;
    lastPhoneCountryIso2 = phoneCountryIso2;
    return super.createBackofficeStudent(
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      phoneCountryIso2: phoneCountryIso2,
      email: email,
      fiscalCode: fiscalCode,
      birthDate: birthDate,
      birthPlace: birthPlace,
      gender: gender,
      address: address,
      city: city,
      province: province,
      cap: cap,
      enrolledCoursePath: enrolledCoursePath,
      enrolledLicenseCategory: enrolledLicenseCategory,
      notes: notes,
      createPracticeDossier: createPracticeDossier,
      practiceType: practiceType,
      registrationDate: registrationDate,
      assignRegistryNumber: assignRegistryNumber,
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
  await fillHint('Codice fiscale', 'RSSMRA85T10A562S');
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
    expect(citySearch.evaluate().length, greaterThanOrEqualTo(1));
    await tester.enterText(citySearch.last, 'Napoli');
  }
  await tester.pump();

  await fillHint('Prov.', 'NA');
  await fillHint('CAP', '80100');

  // Occhiali: scorri al segmento e seleziona "No".
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
  testWidgets('Nuova pratica UI: submit invia E.164 + ISO2 (non nazionale)', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final spy = _SpyCreateRepo();
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
                onPressed: () =>
                    showBackofficeNewPracticeDialog(context, repository: spy),
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

    expect(find.text('Nuova pratica'), findsOneWidget);
    await _fillMinimalAnagrafica(tester);

    await tester.enterText(find.byType(PhoneFormField), '3331234567');
    await tester.pumpAndSettle();

    final createBtn = find.text('Crea pratica');
    await tester.ensureVisible(createBtn);
    await tester.tap(createBtn);
    await tester.pumpAndSettle();

    expect(spy.createCalls, 1);
    expect(spy.lastPhone, '+393331234567');
    expect(spy.lastPhoneCountryIso2, 'IT');
    expect(spy.lastPhone, isNot('3331234567'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Nuova pratica UI: 081… blocco submit e errore italiano', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final spy = _SpyCreateRepo();
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
                onPressed: () =>
                    showBackofficeNewPracticeDialog(context, repository: spy),
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
    await tester.enterText(find.byType(PhoneFormField), '0811234567');
    await tester.pumpAndSettle();

    final createBtn = find.text('Crea pratica');
    await tester.ensureVisible(createBtn);
    await tester.tap(createBtn);
    await tester.pumpAndSettle();

    expect(spy.createCalls, 0);
    expect(
      find.text(InternationalPhoneValidationResult.italyMessage),
      findsWidgets,
    );
    expect(find.text('Nuova pratica'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
