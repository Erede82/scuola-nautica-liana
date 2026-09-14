/// Mapping errori write anagrafica — ALLIEVI.P1B (duplicate CF normalizzato).
///
/// DB authority: index `students_fiscal_code_normalized_uq`
/// (`upper(regexp_replace(fiscal_code, '\s+', '', 'g'))`).
///
/// Messaggio utente frozen: senza PII, senza nome constraint in UI.
abstract final class StudentFiscalCodeWriteError {
  StudentFiscalCodeWriteError._();

  /// Messaggio ESATTO da mostrare in create/edit su duplicate CF.
  static const String userMessage =
      'Esiste già un allievo con questo codice fiscale.';

  /// Nome index UNIQUE normalizzato (SQLSTATE 23505 / PostgREST).
  static const String normalizedUniqueIndexName =
      'students_fiscal_code_normalized_uq';

  /// Riconosce violazione UNIQUE CF normalizzata da campi PostgREST.
  ///
  /// Richiede `code == 23505` **e** il nome index in [message] e/o [details].
  /// Altri 23505 non matchano.
  static bool matchesViolation({
    required String? code,
    required String message,
    Object? details,
  }) {
    if (code != '23505') return false;
    final hay = '$message\n${details ?? ''}'.toLowerCase();
    return hay.contains(normalizedUniqueIndexName.toLowerCase());
  }
}
