/// Errori tipizzati del modulo Quiz assegnati dalla scuola.
library;

/// Errore tipizzato del modulo Quiz assegnati dalla scuola.
class AssignedQuizException implements Exception {
  const AssignedQuizException({
    required this.code,
    required this.message,
    this.cause,
  });

  final String code;
  final String message;
  final Object? cause;

  @override
  String toString() => 'AssignedQuizException($code): $message';
}

/// Codici RPC noti (messaggi `RAISE EXCEPTION` lato DB).
abstract final class AssignedQuizErrorCode {
  static const notAuthenticated = 'not_authenticated';
  static const notAuthorized = 'not_authorized';
  static const unsupportedLicensePath = 'unsupported_license_path';
  static const assignedQuizStudentUserMismatch =
      'assigned_quiz_student_user_mismatch';
  static const assignedQuizLicenseCategoryMismatch =
      'assigned_quiz_license_category_mismatch';
  static const noErrorQuestions = 'no_error_questions';
  static const insufficientErrorQuestions = 'insufficient_error_questions';
  static const idempotencyConflict = 'idempotency_conflict';
  static const assignmentNotAvailable = 'assignment_not_available';
  static const assignmentCategoryMismatch = 'assignment_category_mismatch';
  static const attemptLimitReached = 'attempt_limit_reached';
  static const attemptStartConflict = 'attempt_start_conflict';
  static const attemptNotInProgress = 'attempt_not_in_progress';
  static const invalidSelectedOption = 'invalid_selected_option';
  static const assignedQuizAttemptAnswersIncomplete =
      'assigned_quiz_attempt_answers_incomplete';
  static const assignedQuizDeleteNotAllowed =
      'assigned_quiz_delete_not_allowed';
  static const validationFailed = 'validation_failed';
  static const unknown = 'unknown';
}

/// Messaggi IT di dominio (UI futura; niente snackbar in questa fase).
String assignedQuizErrorMessageIt(String code) {
  switch (code) {
    case AssignedQuizErrorCode.notAuthenticated:
      return 'Sessione non disponibile. Accedi nuovamente.';
    case AssignedQuizErrorCode.notAuthorized:
      return 'Non sei autorizzato a eseguire questa operazione.';
    case AssignedQuizErrorCode.unsupportedLicensePath:
      return 'Il percorso iscrizione non supporta i quiz assegnati.';
    case AssignedQuizErrorCode.assignedQuizStudentUserMismatch:
      return 'L’allievo non ha un account utente collegato coerente.';
    case AssignedQuizErrorCode.assignedQuizLicenseCategoryMismatch:
      return 'La categoria patente dell’allievo non è coerente.';
    case AssignedQuizErrorCode.noErrorQuestions:
      return 'Non ci sono errori storici sufficienti per generare il quiz.';
    case AssignedQuizErrorCode.insufficientErrorQuestions:
      return 'Gli errori disponibili non bastano per il numero richiesto.';
    case AssignedQuizErrorCode.idempotencyConflict:
      return 'Generazione già in corso o in conflitto. Riprova.';
    case AssignedQuizErrorCode.assignmentNotAvailable:
      return 'Il quiz assegnato non è disponibile.';
    case AssignedQuizErrorCode.assignmentCategoryMismatch:
      return 'Il percorso patente è cambiato rispetto all’assegnazione.';
    case AssignedQuizErrorCode.attemptLimitReached:
      return 'Hai raggiunto il numero massimo di tentativi.';
    case AssignedQuizErrorCode.attemptStartConflict:
      return 'Non è stato possibile avviare il tentativo. Riprova.';
    case AssignedQuizErrorCode.attemptNotInProgress:
      return 'Il tentativo non è più in corso.';
    case AssignedQuizErrorCode.invalidSelectedOption:
      return 'Opzione di risposta non valida.';
    case AssignedQuizErrorCode.assignedQuizAttemptAnswersIncomplete:
      return 'Il tentativo non è completo. Contatta la scuola.';
    case AssignedQuizErrorCode.assignedQuizDeleteNotAllowed:
      return 'L’assegnazione non può essere eliminata in questo stato.';
    case AssignedQuizErrorCode.validationFailed:
      return 'I dati inseriti non sono validi.';
    default:
      return 'Operazione non riuscita. Riprova più tardi.';
  }
}

/// Estrae il codice da messaggi Postgrest / RAISE EXCEPTION.
String extractAssignedQuizErrorCode(Object error) {
  final text = error.toString();
  const known = <String>[
    AssignedQuizErrorCode.notAuthenticated,
    AssignedQuizErrorCode.notAuthorized,
    AssignedQuizErrorCode.unsupportedLicensePath,
    AssignedQuizErrorCode.assignedQuizStudentUserMismatch,
    AssignedQuizErrorCode.assignedQuizLicenseCategoryMismatch,
    AssignedQuizErrorCode.noErrorQuestions,
    AssignedQuizErrorCode.insufficientErrorQuestions,
    AssignedQuizErrorCode.idempotencyConflict,
    AssignedQuizErrorCode.assignmentNotAvailable,
    AssignedQuizErrorCode.assignmentCategoryMismatch,
    AssignedQuizErrorCode.attemptLimitReached,
    AssignedQuizErrorCode.attemptStartConflict,
    AssignedQuizErrorCode.attemptNotInProgress,
    AssignedQuizErrorCode.invalidSelectedOption,
    AssignedQuizErrorCode.assignedQuizAttemptAnswersIncomplete,
    AssignedQuizErrorCode.assignedQuizDeleteNotAllowed,
    'assignment_expired',
    'assignment_not_found',
    'attempt_not_found',
    'answer_not_found',
    'title_required',
    'invalid_question_count',
    'invalid_max_attempts',
    'max_attempts_must_be_null_for_unlimited',
    'expires_at_must_be_future',
    'student_id_required',
  ];
  for (final code in known) {
    if (text.contains(code)) return code;
  }
  return AssignedQuizErrorCode.unknown;
}

AssignedQuizException assignedQuizExceptionFrom(Object error) {
  if (error is AssignedQuizException) return error;
  final code = extractAssignedQuizErrorCode(error);
  return AssignedQuizException(
    code: code,
    message: assignedQuizErrorMessageIt(code),
    cause: error,
  );
}
