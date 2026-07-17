/// Errori tipizzati del modulo Quiz assegnati dalla scuola.
library;

import 'package:postgrest/postgrest.dart';

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

/// Codici RPC noti (messaggi `RAISE EXCEPTION` lato DB) utili alla UI.
abstract final class AssignedQuizErrorCode {
  static const notAuthenticated = 'not_authenticated';
  static const notAuthorized = 'not_authorized';
  static const studentNotFound = 'student_not_found';
  static const unsupportedLicensePath = 'unsupported_license_path';
  static const assignedQuizStudentUserMismatch =
      'assigned_quiz_student_user_mismatch';
  static const assignedQuizLicenseCategoryMismatch =
      'assigned_quiz_license_category_mismatch';
  static const noErrorQuestions = 'no_error_questions';
  static const insufficientErrorQuestions = 'insufficient_error_questions';
  static const idempotencyConflict = 'idempotency_conflict';
  static const assignedQuizPublicCodeExhausted =
      'assigned_quiz_public_code_exhausted';
  static const assignedQuizItemsIncomplete = 'assigned_quiz_items_incomplete';
  static const assignedQuizItemsFrozen = 'assigned_quiz_items_frozen';
  static const invalidAssignedQuizStatusTransition =
      'invalid_assigned_quiz_status_transition';
  static const assignedQuizDeleteNotAllowed =
      'assigned_quiz_delete_not_allowed';
  static const assignmentNotAvailable = 'assignment_not_available';
  static const assignmentCategoryMismatch = 'assignment_category_mismatch';
  static const attemptLimitReached = 'attempt_limit_reached';
  static const attemptStartConflict = 'attempt_start_conflict';
  static const attemptNotInProgress = 'attempt_not_in_progress';
  static const invalidSelectedOption = 'invalid_selected_option';
  static const assignedQuizAttemptAnswersIncomplete =
      'assigned_quiz_attempt_answers_incomplete';
  static const invalidParameters = 'invalid_parameters';
  static const titleRequired = 'title_required';
  static const assignmentExpired = 'assignment_expired';
  static const validationFailed = 'validation_failed';
  static const unknown = 'unknown';

  /// Codici riconosciuti dall’estrattore (ordine: stringhe più lunghe prima).
  static const List<String> knownCodes = [
    assignedQuizAttemptAnswersIncomplete,
    assignedQuizLicenseCategoryMismatch,
    assignedQuizStudentUserMismatch,
    assignedQuizPublicCodeExhausted,
    invalidAssignedQuizStatusTransition,
    assignedQuizDeleteNotAllowed,
    assignedQuizItemsIncomplete,
    assignedQuizItemsFrozen,
    insufficientErrorQuestions,
    unsupportedLicensePath,
    assignmentCategoryMismatch,
    assignmentNotAvailable,
    attemptStartConflict,
    attemptNotInProgress,
    attemptLimitReached,
    invalidSelectedOption,
    idempotencyConflict,
    noErrorQuestions,
    notAuthenticated,
    notAuthorized,
    studentNotFound,
    invalidParameters,
    titleRequired,
    assignmentExpired,
    'assignment_not_found',
    'attempt_not_found',
    'answer_not_found',
    'invalid_question_count',
    'invalid_max_attempts',
    'max_attempts_must_be_null_for_unlimited',
    'expires_at_must_be_future',
    'student_id_required',
    'student_user_id_missing',
    'assignment_id_required',
    'invalid_lesson_filter_mode',
    'invalid_lesson_numbers',
    'invalid_repeat_policy',
    'invalid_sort_mode',
  ];
}

/// Messaggi IT di dominio (snackbar/dialog UI; niente SQL grezzo).
String assignedQuizErrorMessageIt(String code) {
  switch (code) {
    case AssignedQuizErrorCode.notAuthenticated:
      return 'Sessione non disponibile. Accedi nuovamente.';
    case AssignedQuizErrorCode.notAuthorized:
      return 'Non hai i permessi per accedere a questo quiz.';
    case AssignedQuizErrorCode.studentNotFound:
      return 'Allievo non trovato.';
    case AssignedQuizErrorCode.unsupportedLicensePath:
      return 'La generazione non è disponibile per il percorso attuale '
          'dell’allievo.';
    case AssignedQuizErrorCode.assignedQuizStudentUserMismatch:
      return 'L’allievo non ha un account utente collegato coerente.';
    case AssignedQuizErrorCode.assignedQuizLicenseCategoryMismatch:
      return 'La categoria patente dell’allievo non è coerente.';
    case AssignedQuizErrorCode.noErrorQuestions:
      return 'L’allievo non ha ancora errori utilizzabili per generare un quiz.';
    case AssignedQuizErrorCode.insufficientErrorQuestions:
      return 'Non ci sono abbastanza domande sbagliate per creare un quiz '
          'con il numero richiesto. Riduci il numero di domande oppure '
          'attiva la generazione parziale.';
    case AssignedQuizErrorCode.idempotencyConflict:
      return 'La richiesta è già stata utilizzata con parametri differenti. '
          'Riapri il dialog e riprova.';
    case AssignedQuizErrorCode.assignedQuizPublicCodeExhausted:
      return 'Non è stato possibile generare il codice del quiz. '
          'Contatta l’assistenza.';
    case AssignedQuizErrorCode.assignedQuizItemsIncomplete:
      return 'Le domande dell’assegnazione non sono complete.';
    case AssignedQuizErrorCode.assignedQuizItemsFrozen:
      return 'Le domande di questa assegnazione non possono essere modificate.';
    case AssignedQuizErrorCode.invalidAssignedQuizStatusTransition:
      return 'Transizione di stato non consentita per questa assegnazione.';
    case AssignedQuizErrorCode.assignedQuizDeleteNotAllowed:
      return 'L’assegnazione non può essere eliminata in questo stato.';
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
    case AssignedQuizErrorCode.invalidParameters:
      return 'I parametri della richiesta non sono validi.';
    case AssignedQuizErrorCode.titleRequired:
      return 'Il titolo è obbligatorio.';
    case AssignedQuizErrorCode.assignmentExpired:
      return 'Il quiz assegnato è scaduto.';
    case AssignedQuizErrorCode.validationFailed:
      return 'I dati inseriti non sono validi.';
    case 'assignment_not_found':
      return 'Assegnazione non trovata.';
    case 'attempt_not_found':
      return 'Tentativo non trovato.';
    case 'expires_at_must_be_future':
      return 'La scadenza deve essere nel futuro.';
    case 'invalid_question_count':
      return 'Il numero di domande non è valido.';
    case 'invalid_max_attempts':
      return 'Il numero massimo di tentativi non è valido.';
    case 'max_attempts_must_be_null_for_unlimited':
      return 'Con tentativi illimitati non impostare un massimo.';
    case 'student_id_required':
      return 'Lo studente è obbligatorio.';
    case 'student_user_id_missing':
      return 'L’allievo non ha un account utente collegato.';
    case 'invalid_lesson_numbers':
      return 'Selezione lezioni non valida.';
    default:
      return 'Operazione non riuscita. Riprova più tardi.';
  }
}

String _extractCodeFromText(String text) {
  for (final code in AssignedQuizErrorCode.knownCodes) {
    if (text.contains(code)) return code;
  }
  return AssignedQuizErrorCode.unknown;
}

/// Estrae il codice da messaggi Postgrest / RAISE EXCEPTION.
String extractAssignedQuizErrorCode(Object error) {
  if (error is PostgrestException) {
    final parts = <String>[
      error.message,
      if (error.details != null) error.details.toString(),
      if (error.hint != null) error.hint.toString(),
      if (error.code != null) error.code!,
    ];
    final fromFields = _extractCodeFromText(parts.join(' '));
    if (fromFields != AssignedQuizErrorCode.unknown) return fromFields;
  }
  return _extractCodeFromText(error.toString());
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
