/// Errori tipizzati Multischeda (persistenza tentativi).
library;

import 'package:postgrest/postgrest.dart';

class MultiTopicQuizAttemptException implements Exception {
  const MultiTopicQuizAttemptException({
    required this.code,
    required this.message,
    this.cause,
  });

  final String code;
  final String message;
  final Object? cause;

  @override
  String toString() => 'MultiTopicQuizAttemptException($code): $message';
}

abstract final class MultiTopicQuizAttemptErrorCode {
  static const notAuthenticated = 'not_authenticated';
  static const studentNotFound = 'student_not_found';
  static const invalidLicenseCategory = 'invalid_license_category';
  static const invalidLessonNumbers = 'invalid_lesson_numbers';
  static const invalidSheetIndex = 'invalid_sheet_index';
  static const invalidTotalSheets = 'invalid_total_sheets';
  static const invalidAnswerCount = 'invalid_answer_count';
  static const invalidAnswersShape = 'invalid_answers_shape';
  static const invalidAnswerPositions = 'invalid_answer_positions';
  static const invalidQuestionId = 'invalid_question_id';
  static const questionNotFound = 'question_not_found';
  static const questionCategoryMismatch = 'question_category_mismatch';
  static const questionLessonMismatch = 'question_lesson_mismatch';
  static const multiTopicAccessDenied = 'multi_topic_access_denied';
  static const idempotencyConflict = 'idempotency_conflict';
  static const sessionSheetConflict = 'session_sheet_conflict';
  static const multiTopicSubmitConflict = 'multi_topic_submit_conflict';
  static const invalidPayload = 'invalid_payload';
  static const repositoryUnavailable = 'repository_unavailable';
  static const unknown = 'unknown';

  static const List<String> knownCodes = [
    multiTopicAccessDenied,
    multiTopicSubmitConflict,
    questionCategoryMismatch,
    questionLessonMismatch,
    invalidAnswerPositions,
    invalidAnswersShape,
    invalidLessonNumbers,
    invalidTotalSheets,
    invalidAnswerCount,
    invalidSheetIndex,
    invalidQuestionId,
    invalidLicenseCategory,
    sessionSheetConflict,
    idempotencyConflict,
    questionNotFound,
    studentNotFound,
    notAuthenticated,
    repositoryUnavailable,
    invalidPayload,
  ];
}

String multiTopicQuizAttemptErrorMessageIt(String code) {
  switch (code) {
    case MultiTopicQuizAttemptErrorCode.notAuthenticated:
      return 'Sessione non disponibile. Accedi nuovamente.';
    case MultiTopicQuizAttemptErrorCode.studentNotFound:
      return 'Allievo non trovato.';
    case MultiTopicQuizAttemptErrorCode.invalidLicenseCategory:
      return 'Categoria patente non valida per la Multischeda.';
    case MultiTopicQuizAttemptErrorCode.invalidLessonNumbers:
      return 'Selezione argomenti non valida.';
    case MultiTopicQuizAttemptErrorCode.invalidSheetIndex:
    case MultiTopicQuizAttemptErrorCode.invalidTotalSheets:
      return 'Indice scheda non valido.';
    case MultiTopicQuizAttemptErrorCode.invalidAnswerCount:
      return 'Il numero di risposte non è valido.';
    case MultiTopicQuizAttemptErrorCode.invalidAnswersShape:
    case MultiTopicQuizAttemptErrorCode.invalidAnswerPositions:
      return 'Formato delle risposte non valido.';
    case MultiTopicQuizAttemptErrorCode.invalidQuestionId:
    case MultiTopicQuizAttemptErrorCode.questionNotFound:
      return 'Una o più domande non sono state trovate.';
    case MultiTopicQuizAttemptErrorCode.questionCategoryMismatch:
      return 'Una domanda non appartiene alla categoria selezionata.';
    case MultiTopicQuizAttemptErrorCode.questionLessonMismatch:
      return 'Una domanda non appartiene agli argomenti selezionati.';
    case MultiTopicQuizAttemptErrorCode.multiTopicAccessDenied:
      return 'Non hai accesso a uno o più argomenti selezionati.';
    case MultiTopicQuizAttemptErrorCode.idempotencyConflict:
      return 'Il token scheda è già stato usato con dati diversi.';
    case MultiTopicQuizAttemptErrorCode.sessionSheetConflict:
      return 'Conflitto sulla scheda di questa sessione. Riprova.';
    case MultiTopicQuizAttemptErrorCode.multiTopicSubmitConflict:
      return 'Conflitto durante il salvataggio. Riprova.';
    case MultiTopicQuizAttemptErrorCode.repositoryUnavailable:
      return 'Repository Multischeda non disponibile.';
    case MultiTopicQuizAttemptErrorCode.invalidPayload:
      return 'Dati del tentativo non coerenti.';
    default:
      return 'Operazione non riuscita. Riprova più tardi.';
  }
}

String _extractCodeFromText(String text) {
  for (final code in MultiTopicQuizAttemptErrorCode.knownCodes) {
    if (text.contains(code)) return code;
  }
  return MultiTopicQuizAttemptErrorCode.unknown;
}

String extractMultiTopicQuizAttemptErrorCode(Object error) {
  if (error is PostgrestException) {
    final parts = <String>[
      error.message,
      if (error.details != null) error.details.toString(),
      if (error.hint != null) error.hint.toString(),
      if (error.code != null) error.code!,
    ];
    final fromFields = _extractCodeFromText(parts.join(' '));
    if (fromFields != MultiTopicQuizAttemptErrorCode.unknown) return fromFields;
  }
  return _extractCodeFromText(error.toString());
}

MultiTopicQuizAttemptException multiTopicQuizAttemptExceptionFrom(
  Object error,
) {
  if (error is MultiTopicQuizAttemptException) return error;
  final code = extractMultiTopicQuizAttemptErrorCode(error);
  return MultiTopicQuizAttemptException(
    code: code,
    message: multiTopicQuizAttemptErrorMessageIt(code),
    cause: error,
  );
}
