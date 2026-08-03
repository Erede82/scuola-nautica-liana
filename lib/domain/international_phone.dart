import 'dart:math' as math;

import 'package:phone_numbers_parser/metadata.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

/// Valore telefono internazionale canonico (indipendente da UI/Supabase).
class InternationalPhoneValue {
  const InternationalPhoneValue({
    required this.countryIso2,
    required this.countryCallingCode,
    required this.nationalNumber,
    required this.e164,
    required this.displayInternational,
  });

  /// ISO 3166-1 alpha-2 maiuscolo (es. `IT`).
  final String countryIso2;

  /// Prefisso numerico senza `+` (es. `39`).
  final String countryCallingCode;

  /// Numero nazionale (NSN), sole cifre.
  final String nationalNumber;

  /// Canonico E.164 (`+393331234567`).
  final String e164;

  /// Presentazione UI (`+39 333 123 4567`).
  final String displayInternational;

  @override
  bool operator ==(Object other) {
    return other is InternationalPhoneValue &&
        other.e164 == e164 &&
        other.countryIso2 == countryIso2;
  }

  @override
  int get hashCode => Object.hash(e164, countryIso2);

  @override
  String toString() =>
      'InternationalPhoneValue($e164, $countryIso2, $displayInternational)';
}

enum InternationalPhoneValidationCode {
  empty,
  invalidItaly,
  invalidForCountry,
  landlineRejected,
  ambiguousStored,
  parseError,
}

/// Esito strutturato di validazione/parsing (niente stringhe sparse nei widget).
class InternationalPhoneValidationResult {
  const InternationalPhoneValidationResult._({
    required this.isValid,
    this.value,
    this.code,
    this.message,
    this.rawPreserved,
  });

  final bool isValid;
  final InternationalPhoneValue? value;
  final InternationalPhoneValidationCode? code;
  final String? message;

  /// Valore grezzo da non perdere (es. storico ambiguo) finché l’utente non conferma.
  final String? rawPreserved;

  factory InternationalPhoneValidationResult.valid(InternationalPhoneValue v) =>
      InternationalPhoneValidationResult._(isValid: true, value: v);

  factory InternationalPhoneValidationResult.invalid({
    required InternationalPhoneValidationCode code,
    required String message,
    String? rawPreserved,
  }) => InternationalPhoneValidationResult._(
    isValid: false,
    code: code,
    message: message,
    rawPreserved: rawPreserved,
  );

  static const emptyMessage = 'Inserisci il numero di cellulare.';
  static const italyMessage =
      'Inserisci un cellulare italiano di 10 cifre che inizi con 3.';
  static const foreignMessage =
      'Il numero non è valido per il Paese selezionato.';
  static const ambiguousMessage =
      'Il numero esistente non può essere riconosciuto automaticamente. '
      'Seleziona il Paese e inseriscilo nuovamente.';
  static const reenterMessage =
      'Seleziona il Paese e inserisci nuovamente il numero.';
}

/// Messaggi e regole condivise per cellulari internazionali.
///
/// Tipologia cellulare (API `phone_numbers_parser`):
/// - si usa [PhoneNumber.isValid] / [PhoneNumber.isValid] con [PhoneNumberType];
/// - se il metadata classifica chiaramente come solo `fixedLine`, si rifiuta;
/// - se `mobile` è valido, si accetta;
/// - se fisso/mobile non sono distinguibili (entrambi o nessuno), si accetta
///   una numerazione generica valida per evitare falsi rifiuti.
abstract final class InternationalPhoneRules {
  static const defaultCountryIso2 = 'IT';

  static IsoCode isoCodeFromString(String iso2) {
    final upper = iso2.trim().toUpperCase();
    return IsoCode.values.firstWhere(
      (c) => c.name == upper,
      orElse: () => IsoCode.IT,
    );
  }

  static String? _digitsOnly(String raw) => raw.replaceAll(RegExp(r'\D'), '');

  static bool isItalianMobileNational(String nationalDigits) =>
      RegExp(r'^3[0-9]{9}$').hasMatch(nationalDigits);

  /// Massimo cifre nazionali digitabili per il Paese (limite input, non sola UI).
  ///
  /// Italia: sempre 10 (cellulare). Altri Paesi: max lunghezza `mobile` dai
  /// metadati `phone_numbers_parser`; se assente, max tra mobile/fixedLine;
  /// fallback sicuro E.164 rispetto al calling code.
  static int maxNationalDigits(String countryIso2) {
    final iso = isoCodeFromString(countryIso2);
    if (iso == IsoCode.IT) return 10;

    final lengths = metadataLenghtsByIsoCode[iso];
    if (lengths != null) {
      final mobileMax = _maxOf(lengths.mobile);
      if (mobileMax != null) return mobileMax;
      final candidates = <int>[
        ...lengths.mobile,
        ...lengths.fixedLine,
        ...lengths.general,
        ...lengths.voip,
      ];
      final anyMax = _maxOf(candidates);
      if (anyMax != null) return anyMax;
    }

    // Fallback: 15 cifre E.164 totali meno lunghezza calling code.
    final calling = PhoneNumber(isoCode: iso, nsn: '').countryCode;
    final maxNsn = 15 - calling.length;
    return math.max(8, maxNsn);
  }

  static int? _maxOf(List<int> values) {
    if (values.isEmpty) return null;
    return values.reduce(math.max);
  }

  /// Sole cifre nazionali se entro il limite del Paese; altrimenti `null`.
  ///
  /// Non tronca: un prefisso può essere un altro numero valido.
  static String? nationalDigitsWithinLimit(String raw, String countryIso2) {
    final digits = _digitsOnly(raw) ?? '';
    final max = maxNationalDigits(countryIso2);
    if (digits.length > max) return null;
    return digits;
  }

  /// `true` se le cifre nazionali non superano il limite del Paese.
  static bool fitsNationalDigitLimit(String raw, String countryIso2) =>
      nationalDigitsWithinLimit(raw, countryIso2) != null;

  static InternationalPhoneValue _fromParsed(PhoneNumber parsed) {
    final nsn = _digitsOnly(parsed.nsn) ?? parsed.nsn;
    final formattedNsn = parsed.formatNsn();
    final display = '+${parsed.countryCode} $formattedNsn'.trim();
    return InternationalPhoneValue(
      countryIso2: parsed.isoCode.name,
      countryCallingCode: parsed.countryCode,
      nationalNumber: nsn,
      e164: parsed.international,
      displayInternational: display,
    );
  }

  static bool _acceptMobileOrAmbiguous(PhoneNumber parsed) {
    if (!parsed.isValid()) return false;
    final mobileOk = parsed.isValid(type: PhoneNumberType.mobile);
    final fixedOk = parsed.isValid(type: PhoneNumberType.fixedLine);
    if (mobileOk) return true;
    if (fixedOk && !mobileOk) return false;
    // Tipologia non distinguibile: accetta numerazione valida.
    return true;
  }

  /// Valida input nazionale (o E.164 completo) per il Paese selezionato.
  static InternationalPhoneValidationResult validateInput({
    required String? rawInput,
    required String countryIso2,
  }) {
    final raw = rawInput?.trim() ?? '';
    if (raw.isEmpty) {
      return InternationalPhoneValidationResult.invalid(
        code: InternationalPhoneValidationCode.empty,
        message: InternationalPhoneValidationResult.emptyMessage,
      );
    }

    final iso = isoCodeFromString(countryIso2);

    // Rifiuta lettere / simboli anomali (oltre separatori telefonici ammessi).
    if (RegExp(r'[A-Za-z]').hasMatch(raw)) {
      return InternationalPhoneValidationResult.invalid(
        code: iso == IsoCode.IT
            ? InternationalPhoneValidationCode.invalidItaly
            : InternationalPhoneValidationCode.invalidForCountry,
        message: iso == IsoCode.IT
            ? InternationalPhoneValidationResult.italyMessage
            : InternationalPhoneValidationResult.foreignMessage,
      );
    }

    PhoneNumber parsed;
    try {
      parsed = PhoneNumber.parse(
        raw,
        destinationCountry: iso,
        callerCountry: iso,
      );
    } catch (_) {
      return InternationalPhoneValidationResult.invalid(
        code: InternationalPhoneValidationCode.parseError,
        message: iso == IsoCode.IT
            ? InternationalPhoneValidationResult.italyMessage
            : InternationalPhoneValidationResult.foreignMessage,
      );
    }

    // Incolla internazionale (+… o 00…): usa il Paese rilevato dal numero
    // completo e non lascia un doppio prefisso nel nazionale.
    final looksInternational =
        raw.startsWith('+') || RegExp(r'^00[1-9]').hasMatch(raw);
    if (looksInternational) {
      return _validateParsed(parsed, enforceSelectedCountry: false);
    }

    return _validateParsed(parsed, enforceSelectedCountry: true, selected: iso);
  }

  static InternationalPhoneValidationResult _validateParsed(
    PhoneNumber parsed, {
    required bool enforceSelectedCountry,
    IsoCode? selected,
  }) {
    if (enforceSelectedCountry &&
        selected != null &&
        parsed.isoCode != selected) {
      // Prefisso duplicato / paese incoerente nel campo nazionale.
      final isIt = selected == IsoCode.IT;
      return InternationalPhoneValidationResult.invalid(
        code: isIt
            ? InternationalPhoneValidationCode.invalidItaly
            : InternationalPhoneValidationCode.invalidForCountry,
        message: isIt
            ? InternationalPhoneValidationResult.italyMessage
            : InternationalPhoneValidationResult.foreignMessage,
      );
    }

    final nsn = _digitsOnly(parsed.nsn) ?? '';

    if (parsed.isoCode == IsoCode.IT) {
      if (!isItalianMobileNational(nsn)) {
        return InternationalPhoneValidationResult.invalid(
          code: InternationalPhoneValidationCode.invalidItaly,
          message: InternationalPhoneValidationResult.italyMessage,
        );
      }
      final value = _fromParsed(PhoneNumber(isoCode: IsoCode.IT, nsn: nsn));
      return InternationalPhoneValidationResult.valid(value);
    }

    if (!_acceptMobileOrAmbiguous(parsed)) {
      final fixedOnly =
          parsed.isValid(type: PhoneNumberType.fixedLine) &&
          !parsed.isValid(type: PhoneNumberType.mobile);
      return InternationalPhoneValidationResult.invalid(
        code: fixedOnly
            ? InternationalPhoneValidationCode.landlineRejected
            : InternationalPhoneValidationCode.invalidForCountry,
        message: InternationalPhoneValidationResult.foreignMessage,
      );
    }

    return InternationalPhoneValidationResult.valid(_fromParsed(parsed));
  }

  /// Interpreta un telefono già persistito (lettura storica / E.164).
  static InternationalPhoneValidationResult parseStored({
    String? phone,
    String? phoneCountryIso2,
  }) {
    final raw = phone?.trim() ?? '';
    if (raw.isEmpty) {
      return InternationalPhoneValidationResult.invalid(
        code: InternationalPhoneValidationCode.empty,
        message: InternationalPhoneValidationResult.emptyMessage,
      );
    }

    final isoHint = phoneCountryIso2?.trim().toUpperCase();
    final compact = raw.replaceAll(RegExp(r'[\s().-]'), '');
    final digits = _digitsOnly(compact) ?? '';

    // Nazionale IT storico inequivocabile.
    if (!compact.startsWith('+') && isItalianMobileNational(digits)) {
      final value = _fromParsed(PhoneNumber(isoCode: IsoCode.IT, nsn: digits));
      return InternationalPhoneValidationResult.valid(value);
    }

    // E.164 / internazionale.
    if (compact.startsWith('+') || (isoHint != null && isoHint.isNotEmpty)) {
      try {
        final parsed = PhoneNumber.parse(
          compact.startsWith('+') ? compact : raw,
          destinationCountry: isoHint != null && isoHint.isNotEmpty
              ? isoCodeFromString(isoHint)
              : null,
        );
        if (parsed.isoCode == IsoCode.IT) {
          final nsn = _digitsOnly(parsed.nsn) ?? '';
          if (isItalianMobileNational(nsn)) {
            return InternationalPhoneValidationResult.valid(
              _fromParsed(PhoneNumber(isoCode: IsoCode.IT, nsn: nsn)),
            );
          }
        } else if (parsed.isValid()) {
          return InternationalPhoneValidationResult.valid(_fromParsed(parsed));
        }
      } catch (_) {
        // fall through → ambiguous
      }
    }

    return InternationalPhoneValidationResult.invalid(
      code: InternationalPhoneValidationCode.ambiguousStored,
      message: InternationalPhoneValidationResult.ambiguousMessage,
      rawPreserved: raw,
    );
  }

  /// Display UI: formatta se riconoscibile, altrimenti lascia il grezzo.
  static String formatForDisplay(String? phone, {String? phoneCountryIso2}) {
    final raw = phone?.trim() ?? '';
    if (raw.isEmpty) return '—';
    final parsed = parseStored(phone: raw, phoneCountryIso2: phoneCountryIso2);
    if (parsed.isValid && parsed.value != null) {
      return parsed.value!.displayInternational;
    }
    return raw;
  }

  /// Normalizza un token di ricerca telefonica (spazi/trattini/parentesi).
  static String normalizeForSearch(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '';
    final compact = t.replaceAll(RegExp(r'[\s().-]'), '');
    return compact;
  }

  /// Match ricerca: nome/email sul testo originale; telefono sulla variante normalizzata.
  static bool matchesSearch({
    required String query,
    required String displayName,
    String? email,
    String? phone,
  }) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (displayName.toLowerCase().contains(q)) return true;
    if (email != null && email.toLowerCase().contains(q)) return true;

    final phoneNorm = normalizeForSearch(phone ?? '').toLowerCase();
    final qPhone = normalizeForSearch(query).toLowerCase();
    if (phoneNorm.isEmpty || qPhone.isEmpty) return false;

    if (phoneNorm.contains(qPhone)) return true;

    // Confronto anche sulle sole cifre (ignora +).
    final phoneDigits = phoneNorm.replaceAll('+', '');
    final qDigits = qPhone.replaceAll('+', '');
    if (qDigits.isEmpty) return false;
    return phoneDigits.contains(qDigits);
  }
}
