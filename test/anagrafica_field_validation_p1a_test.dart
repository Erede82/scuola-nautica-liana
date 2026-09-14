import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/anagrafica/anagrafica_field_validation.dart';
import 'package:scuola_nautica_liana/domain/anagrafica/anagrafica_format.dart';
import 'package:scuola_nautica_liana/domain/anagrafica/codice_fiscale.dart';
import 'package:scuola_nautica_liana/domain/international_phone.dart';

void main() {
  late InternationalPhoneValue validPhone;
  const validCf = 'BNCLCU98D52F205T';
  final birth = DateTime(1998, 4, 12);

  setUp(() {
    final r = InternationalPhoneRules.validateInput(
      rawInput: '3331234567',
      countryIso2: 'IT',
    );
    expect(r.isValid, isTrue);
    validPhone = r.value!;
  });

  String? ok({
    String lastName = 'Bianchi',
    String firstName = 'Lucia',
    String? gender = 'Femmina',
    DateTime? birthDate,
    String birthPlace = 'Milano',
    String fiscalCode = validCf,
    String address = 'Via Roma 1',
    String city = 'Milano',
    String province = 'MI',
    String cap = '20100',
    InternationalPhoneValue? phoneValue,
    String email = 'lucia@example.com',
  }) {
    return AnagraficaFieldValidation.validateEditableAnagrafica(
      lastName: lastName,
      firstName: firstName,
      gender: gender,
      birthDate: birthDate ?? birth,
      birthPlace: birthPlace,
      fiscalCode: fiscalCode,
      address: address,
      city: city,
      province: province,
      cap: cap,
      phoneValue: phoneValue ?? validPhone,
      email: email,
    );
  }

  group('ALLIEVI.P1A validation', () {
    test('1. nome required', () {
      expect(ok(firstName: '  '), isNotNull);
    });

    test('2. cognome required', () {
      expect(ok(lastName: ''), isNotNull);
    });

    test('3. CF trim + uppercase', () {
      expect(
        AnagraficaFieldValidation.normalizeFiscalCode('  bnclcu98d52f205t  '),
        validCf,
      );
      expect(CodiceFiscale.isFormalmenteValido('  bnclcu98d52f205t  '), isTrue);
    });

    test('4. CF invalido respinto', () {
      expect(ok(fiscalCode: 'ABCDEF'), isNotNull);
      expect(ok(fiscalCode: 'BNCLCU98D52F205X'), isNotNull);
    });

    test('5. email valida', () {
      expect(ok(email: 'ok@example.com'), isNull);
    });

    test('6. email invalida respinta', () {
      expect(ok(email: 'senza-chiocciola'), isNotNull);
    });

    test('7. CAP/provincia', () {
      expect(AnagraficaFieldValidation.validateItalianCap('20100'), isNull);
      expect(AnagraficaFieldValidation.validateItalianCap('20 100'), isNull);
      expect(AnagraficaFieldValidation.validateItalianCap('2010'), isNotNull);
      expect(ok(province: ''), isNotNull);
      expect(ok(cap: 'abcde'), isNotNull);
    });

    test('8. telefono E.164', () {
      expect(
        AnagraficaFieldValidation.validateEditableAnagrafica(
          lastName: 'Bianchi',
          firstName: 'Lucia',
          gender: 'Femmina',
          birthDate: birth,
          birthPlace: 'Milano',
          fiscalCode: validCf,
          address: 'Via Roma 1',
          city: 'Milano',
          province: 'MI',
          cap: '20100',
          phoneValue: null,
          email: 'a@b.it',
        ),
        isNotNull,
      );
      expect(validPhone.e164, startsWith('+'));
      expect(ok(), isNull);
    });

    test('9. normalizzazione testi', () {
      expect(AnagraficaFormat.titleCase('  lucia  '), 'Lucia');
      expect(
        AnagraficaFormat.titleCase('castellammare di stabia'),
        'Castellammare di Stabia',
      );
    });

    test('10. date valide', () {
      expect(
        AnagraficaFieldValidation.validateEditableAnagrafica(
          lastName: 'Bianchi',
          firstName: 'Lucia',
          gender: 'Femmina',
          birthDate: null,
          birthPlace: 'Milano',
          fiscalCode: validCf,
          address: 'Via Roma 1',
          city: 'Milano',
          province: 'MI',
          cap: '20100',
          phoneValue: validPhone,
          email: 'a@b.it',
        ),
        isNotNull,
      );
      expect(ok(birthDate: birth), isNull);
    });
  });
}
