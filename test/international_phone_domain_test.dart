import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/international_phone.dart';

void main() {
  group('InternationalPhoneRules limiti nazionali', () {
    test('IT=10, FR=9, GB da metadata', () {
      expect(InternationalPhoneRules.maxNationalDigits('IT'), 10);
      expect(InternationalPhoneRules.maxNationalDigits('FR'), 9);
      expect(
        InternationalPhoneRules.maxNationalDigits('GB'),
        greaterThanOrEqualTo(10),
      );
      expect(
        InternationalPhoneRules.clampNationalDigits('333123456789999', 'IT'),
        '3331234567',
      );
    });
  });

  group('InternationalPhoneRules Italia', () {
    test('validi → E.164', () {
      for (final entry in [
        ('3331234567', '+393331234567'),
        ('3200000001', '+393200000001'),
        ('3887654321', '+393887654321'),
      ]) {
        final r = InternationalPhoneRules.validateInput(
          rawInput: entry.$1,
          countryIso2: 'IT',
        );
        expect(r.isValid, isTrue, reason: entry.$1);
        expect(r.value!.e164, entry.$2);
        expect(r.value!.countryIso2, 'IT');
        expect(r.value!.nationalNumber, entry.$1);
      }
    });

    test('invalidi', () {
      for (final raw in [
        '331123456', // 9
        '33312345678', // 11
        '0811234567', // fisso
        '33312A4567',
        '',
        '+393331234567', // prefisso nel nazionale con paese già IT → parse ok as e164
      ]) {
        if (raw == '+393331234567') {
          // Incolla E.164 completo: accettato e normalizzato.
          final ok = InternationalPhoneRules.validateInput(
            rawInput: raw,
            countryIso2: 'IT',
          );
          expect(ok.isValid, isTrue);
          expect(ok.value!.e164, '+393331234567');
          continue;
        }
        final r = InternationalPhoneRules.validateInput(
          rawInput: raw,
          countryIso2: 'IT',
        );
        expect(r.isValid, isFalse, reason: 'atteso invalido: $raw');
        if (raw.isEmpty) {
          expect(r.code, InternationalPhoneValidationCode.empty);
        } else {
          expect(r.message, InternationalPhoneValidationResult.italyMessage);
        }
      }
    });

    test('display internazionale', () {
      final r = InternationalPhoneRules.validateInput(
        rawInput: '3331234567',
        countryIso2: 'IT',
      );
      expect(r.value!.displayInternational, '+39 333 123 4567');
      expect(
        InternationalPhoneRules.formatForDisplay('+393331234567'),
        '+39 333 123 4567',
      );
    });
  });

  group('InternationalPhoneRules estero', () {
    test('FR mobile valido', () {
      final r = InternationalPhoneRules.validateInput(
        rawInput: '612345678',
        countryIso2: 'FR',
      );
      expect(r.isValid, isTrue);
      expect(r.value!.e164, '+33612345678');
      expect(r.value!.countryIso2, 'FR');
    });

    test('DE mobile valido', () {
      final r = InternationalPhoneRules.validateInput(
        rawInput: '15123456789',
        countryIso2: 'DE',
      );
      expect(r.isValid, isTrue);
      expect(r.value!.e164, '+4915123456789');
      expect(r.value!.countryIso2, 'DE');
    });

    test('FR lunghezza errata', () {
      final r = InternationalPhoneRules.validateInput(
        rawInput: '61234567',
        countryIso2: 'FR',
      );
      expect(r.isValid, isFalse);
      expect(r.message, InternationalPhoneValidationResult.foreignMessage);
    });
  });

  group('parseStored / ricerca', () {
    test('E.164 e nazionale IT storico', () {
      final e164 = InternationalPhoneRules.parseStored(phone: '+393331234567');
      expect(e164.isValid, isTrue);
      expect(e164.value!.countryIso2, 'IT');

      final national = InternationalPhoneRules.parseStored(phone: '3331234567');
      expect(national.isValid, isTrue);
      expect(national.value!.e164, '+393331234567');
    });

    test('ambiguo non interpretato', () {
      final r = InternationalPhoneRules.parseStored(phone: '12345');
      expect(r.isValid, isFalse);
      expect(r.code, InternationalPhoneValidationCode.ambiguousStored);
      expect(r.rawPreserved, '12345');
    });

    test('ricerca telefono tollera spazi e +', () {
      const phone = '+393331234567';
      for (final q in [
        '3331234567',
        '333 123 4567',
        '+393331234567',
        '+39 333 123 4567',
      ]) {
        expect(
          InternationalPhoneRules.matchesSearch(
            query: q,
            displayName: 'Marco Verdi',
            email: 'm@example.com',
            phone: phone,
          ),
          isTrue,
          reason: q,
        );
      }
      expect(
        InternationalPhoneRules.matchesSearch(
          query: 'Marco',
          displayName: 'Marco Verdi',
          email: 'm@example.com',
          phone: phone,
        ),
        isTrue,
      );
    });
  });
}
