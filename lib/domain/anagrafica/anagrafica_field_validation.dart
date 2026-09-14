import '../international_phone.dart';
import 'codice_fiscale.dart';

/// Validazioni anagrafiche condivise tra «Nuova pratica» e «Modifica anagrafica».
///
/// Semantica allineata a `_validateNewPracticeFields` (create): required, CF formale,
/// CAP 5 cifre, telefono E.164, email con `@` se valorizzata.
abstract final class AnagraficaFieldValidation {
  /// Provincia di nascita: obbligatoria, sigla 2 lettere (solo create).
  static String? validateBirthProvince(String raw) {
    final p = raw.trim().toUpperCase();
    if (p.isEmpty) {
      return 'Inserisci la provincia di nascita.';
    }
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(p)) {
      return 'La provincia di nascita deve essere una sigla di 2 lettere (es. NA, SA, RM).';
    }
    return null;
  }

  /// CAP italiano: obbligatorio, esattamente 5 cifre (spazi ignorati).
  static String? validateItalianCap(String raw) {
    final cap = raw.replaceAll(RegExp(r'\s'), '');
    if (cap.isEmpty) {
      return 'Inserisci il CAP.';
    }
    if (!RegExp(r'^\d{5}$').hasMatch(cap)) {
      return 'Il CAP deve essere di 5 cifre (solo numeri).';
    }
    return null;
  }

  /// Email anagrafica: se [requireNonEmpty] e vuota → errore; se valorizzata deve contenere `@`.
  static String? validateEmail(
    String email, {
    required bool requireNonEmpty,
    String emptyMessage = 'Inserisci l’email.',
  }) {
    final em = email.trim();
    if (em.isEmpty) {
      return requireNonEmpty ? emptyMessage : null;
    }
    if (!em.contains('@')) {
      return 'L’email deve contenere il simbolo @.';
    }
    return null;
  }

  /// Blocco identità + residenza + telefono + email (senza provincia nascita / occhiali / percorso).
  ///
  /// Usato da edit anagrafica; il create lo richiama e aggiunge i campi solo-create.
  static String? validateEditableAnagrafica({
    required String lastName,
    required String firstName,
    required String? gender,
    required DateTime? birthDate,
    required String birthPlace,
    required String fiscalCode,
    required String address,
    required String city,
    required String province,
    required String cap,
    required InternationalPhoneValue? phoneValue,
    required String email,
    bool requireEmail = false,
  }) {
    if (lastName.trim().isEmpty) {
      return 'Inserisci il cognome.';
    }
    if (firstName.trim().isEmpty) {
      return 'Inserisci il nome.';
    }
    if (gender == null || gender.trim().isEmpty) {
      return 'Seleziona il sesso.';
    }
    if (birthDate == null) {
      return 'Seleziona la data di nascita.';
    }
    if (birthPlace.trim().isEmpty) {
      return 'Inserisci il luogo di nascita.';
    }
    if (fiscalCode.trim().isEmpty) {
      return 'Inserisci il codice fiscale.';
    }
    if (!CodiceFiscale.isFormalmenteValido(fiscalCode)) {
      return 'Il codice fiscale non è formalmente valido: '
          'verifica formato (16 caratteri) e carattere di controllo.';
    }
    if (address.trim().isEmpty) {
      return 'Inserisci l’indirizzo.';
    }
    if (city.trim().isEmpty) {
      return 'Inserisci la città.';
    }
    if (province.trim().isEmpty) {
      return 'Inserisci la provincia di residenza.';
    }
    if (cap.trim().isEmpty) {
      return 'Inserisci il CAP.';
    }
    final capErr = validateItalianCap(cap);
    if (capErr != null) {
      return capErr;
    }
    if (phoneValue == null) {
      return InternationalPhoneValidationResult.emptyMessage;
    }
    return validateEmail(
      email,
      requireNonEmpty: requireEmail,
      emptyMessage: 'Inserisci l’email per l’accesso app.',
    );
  }

  /// Normalizza CF: trim + uppercase (senza altre trasformazioni).
  static String normalizeFiscalCode(String raw) =>
      CodiceFiscale.normalizza(raw);
}
