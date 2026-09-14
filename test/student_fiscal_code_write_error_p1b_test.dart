import 'package:flutter_test/flutter_test.dart';
import 'package:postgrest/postgrest.dart';
import 'package:scuola_nautica_liana/domain/anagrafica/codice_fiscale.dart';
import 'package:scuola_nautica_liana/repositories/backoffice/backoffice_supabase_write_helpers.dart';
import 'package:scuola_nautica_liana/repositories/backoffice/student_fiscal_code_write_error.dart';

void main() {
  group('ALLIEVI.P1B normalization', () {
    test('1. lowercase → uppercase', () {
      expect(CodiceFiscale.normalizza('bnclcu98d52f205t'), 'BNCLCU98D52F205T');
    });

    test('2. whitespace esterno rimosso', () {
      expect(
        CodiceFiscale.normalizza('  BNCLCU98D52F205T  '),
        'BNCLCU98D52F205T',
      );
    });

    test('3. whitespace interno rimosso', () {
      expect(
        CodiceFiscale.normalizza('BNCL CU98 D52F 205T'),
        'BNCLCU98D52F205T',
      );
    });

    test('4. tab/newline rimosso', () {
      expect(
        CodiceFiscale.normalizza('BNCL\tCU98\nD52F\r205T'),
        'BNCLCU98D52F205T',
      );
    });

    test('5-6. payload create/edit usa CodiceFiscale.normalizza', () {
      final payload = studentAnagraficaUpdatePayload(
        firstName: 'Lucia',
        lastName: 'Bianchi',
        fiscalCode: '  bncl cu98d52f205t ',
        birthDate: DateTime(1998, 4, 12),
        birthPlace: 'Milano',
        gender: 'Femmina',
        address: 'Via 1',
        city: 'Milano',
        province: 'MI',
        cap: '20100',
        phoneE164: '+393331234567',
        phoneCountryIso2: 'IT',
        email: 'a@b.it',
      );
      expect(payload['fiscal_code'], 'BNCLCU98D52F205T');
      expect(payload.containsKey('tax_code'), isFalse);
    });
  });

  group('ALLIEVI.P1B error mapping', () {
    test('7. 23505 + index → duplicate CF friendly', () {
      const e = PostgrestException(
        message:
            'duplicate key value violates unique constraint '
            '"students_fiscal_code_normalized_uq"',
        code: '23505',
      );
      expect(isDuplicateStudentFiscalCodeError(e), isTrue);
      expect(
        friendlyStudentWriteError(e),
        StudentFiscalCodeWriteError.userMessage,
      );
    });

    test('8. constraint name in message → recognized', () {
      expect(
        StudentFiscalCodeWriteError.matchesViolation(
          code: '23505',
          message:
              'Key (upper(...)) already exists. students_fiscal_code_normalized_uq',
          details: null,
        ),
        isTrue,
      );
    });

    test('9. constraint name in details → recognized', () {
      expect(
        StudentFiscalCodeWriteError.matchesViolation(
          code: '23505',
          message: 'duplicate key value violates unique constraint',
          details: 'Key (...) = (...) students_fiscal_code_normalized_uq',
        ),
        isTrue,
      );
    });

    test('10. 23505 altro UNIQUE → NON duplicate CF', () {
      const e = PostgrestException(
        message:
            'duplicate key value violates unique constraint "students_email_uq"',
        code: '23505',
        details: 'Key (email)=(x@y.it) already exists.',
      );
      expect(isDuplicateStudentFiscalCodeError(e), isFalse);
      expect(friendlyStudentWriteError(e), isNull);
    });

    test('11. errore non-23505 → non CF duplicate', () {
      const e = PostgrestException(
        message: 'RLS policy violation',
        code: '42501',
      );
      expect(isDuplicateStudentFiscalCodeError(e), isFalse);
      expect(friendlyStudentWriteError(e), isNull);
    });
  });
}
