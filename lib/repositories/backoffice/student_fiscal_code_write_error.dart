import 'package:postgrest/postgrest.dart';

import '../../domain/anagrafica/student_fiscal_code_write_error.dart';

export '../../domain/anagrafica/student_fiscal_code_write_error.dart';

/// `true` se [error] è un duplicate CF normalizzato (23505 + index P1B).
bool isDuplicateStudentFiscalCodeError(Object error) {
  if (error is StateError &&
      error.message == StudentFiscalCodeWriteError.userMessage) {
    return true;
  }
  if (error is PostgrestException) {
    return StudentFiscalCodeWriteError.matchesViolation(
      code: error.code,
      message: error.message,
      details: error.details,
    );
  }
  // Fallback: stringa/toString con code + index (test / wrap generici).
  final blob = error.toString();
  if (!blob.contains('23505')) return false;
  return blob.toLowerCase().contains(
    StudentFiscalCodeWriteError.normalizedUniqueIndexName.toLowerCase(),
  );
}

/// Messaggio friendly frozen se duplicate CF; altrimenti `null`.
String? friendlyStudentWriteError(Object error) =>
    isDuplicateStudentFiscalCodeError(error)
        ? StudentFiscalCodeWriteError.userMessage
        : null;
