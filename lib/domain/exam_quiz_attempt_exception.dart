/// Errori tipizzati del modulo Quiz Esame (persistenza tentativi).
library;

import 'package:postgrest/postgrest.dart';

/// Errore tipizzato del modulo Quiz Esame.
class ExamQuizAttemptException implements Exception {
  const ExamQuizAttemptException({
    required this.code,
    required this.message,
    this.cause,
  });

  final String code;
  final String message;
  final Object? cause;

  @override
  String toString() => 'ExamQuizAttemptException($code): $message';
}

/// Codici RPC / validazione noti (messaggi `RAISE EXCEPTION` lato DB).
abstract final class ExamQuizAttemptErrorCode {
  static const notAuthenticated = 'not_authenticated';
  static const studentNotFound = 'student_not_found';
  static const examAccessDenied = 'exam_access_denied';
  static const invalidClientAttemptToken = 'invalid_client_attempt_token';
  static const clientAttemptTokenRequired = 'client_attempt_token_required';
  static const invalidLicenseCategory = 'invalid_license_category';
  static const invalidDuration = 'invalid_duration';
  static const invalidDurationSeconds = 'invalid_duration_seconds';
  static const timeExpiredRequired = 'time_expired_required';
  static const invalidAnswersPayload = 'invalid_answers_payload';
  static const invalidAnswerCount = 'invalid_answer_count';
  static const invalidAnswerPositions = 'invalid_answer_positions';
  static const invalidQuestionId = 'invalid_question_id';
  static const invalidAnswersShape = 'invalid_answers_shape';
  static const questionNotFound = 'question_not_found';
  static const questionCategoryMismatch = 'question_category_mismatch';
  static const invalidExamQuestion = 'invalid_exam_question';
  static const questionNotValidForExam = 'question_not_valid_for_exam';
  static const invalidExamTopicQuotas = 'invalid_exam_topic_quotas';
  static const idempotencyConflict = 'idempotency_conflict';
  static const examSubmitConflict = 'exam_submit_conflict';
  static const attemptNotFound = 'attempt_not_found';
  static const invalidPayload = 'invalid_payload';
  static const repositoryUnavailable = 'repository_unavailable';
  static const unknown = 'unknown';

  /// Codici riconosciuti dall’estrattore (stringhe più lunghe prima).
  static const List<String> knownCodes = [
    questionNotValidForExam,
    invalidExamTopicQuotas,
    questionCategoryMismatch,
    invalidClientAttemptToken,
    clientAttemptTokenRequired,
    invalidDurationSeconds,
    invalidAnswerPositions,
    invalidAnswersPayload,
    invalidAnswersShape,
    invalidAnswerCount,
    invalidQuestionId,
    invalidLicenseCategory,
    invalidExamQuestion,
    invalidDuration,
    timeExpiredRequired,
    examAccessDenied,
    examSubmitConflict,
    idempotencyConflict,
    questionNotFound,
    studentNotFound,
    notAuthenticated,
    attemptNotFound,
    repositoryUnavailable,
    invalidPayload,
  ];
}

/// Messaggi IT di dominio (nessun SQL grezzo in UI).
String examQuizAttemptErrorMessageIt(String code) {
  switch (code) {
    case ExamQuizAttemptErrorCode.notAuthenticated:
      return 'Sessione non disponibile. Accedi nuovamente.';
    case ExamQuizAttemptErrorCode.studentNotFound:
      return 'Allievo non trovato.';
    case ExamQuizAttemptErrorCode.examAccessDenied:
      return 'Non hai accesso alla simulazione esame.';
    case ExamQuizAttemptErrorCode.invalidClientAttemptToken:
    case ExamQuizAttemptErrorCode.clientAttemptTokenRequired:
      return 'Token tentativo non valido.';
    case ExamQuizAttemptErrorCode.invalidLicenseCategory:
      return 'Categoria patente non valida per l’esame.';
    case ExamQuizAttemptErrorCode.invalidDuration:
    case ExamQuizAttemptErrorCode.invalidDurationSeconds:
      return 'Durata del tentativo non valida.';
    case ExamQuizAttemptErrorCode.timeExpiredRequired:
      return 'Indicatore di timer scaduto mancante.';
    case ExamQuizAttemptErrorCode.invalidAnswersPayload:
      return 'Payload risposte non valido.';
    case ExamQuizAttemptErrorCode.invalidAnswerCount:
      return 'Il numero di risposte non è valido.';
    case ExamQuizAttemptErrorCode.invalidAnswerPositions:
      return 'Le posizioni delle risposte non sono valide.';
    case ExamQuizAttemptErrorCode.invalidQuestionId:
      return 'Identificativo domanda non valido.';
    case ExamQuizAttemptErrorCode.invalidAnswersShape:
      return 'Formato delle risposte non valido.';
    case ExamQuizAttemptErrorCode.questionNotFound:
      return 'Una o più domande non sono state trovate.';
    case ExamQuizAttemptErrorCode.questionCategoryMismatch:
      return 'Una domanda non appartiene alla categoria selezionata.';
    case ExamQuizAttemptErrorCode.invalidExamQuestion:
    case ExamQuizAttemptErrorCode.questionNotValidForExam:
      return 'Una domanda non è valida per la simulazione esame.';
    case ExamQuizAttemptErrorCode.invalidExamTopicQuotas:
      return 'La composizione delle domande non rispetta le quote d’esame.';
    case ExamQuizAttemptErrorCode.idempotencyConflict:
      return 'Il token tentativo è già stato usato con dati diversi.';
    case ExamQuizAttemptErrorCode.examSubmitConflict:
      return 'Conflitto durante il salvataggio del tentativo. Riprova.';
    case ExamQuizAttemptErrorCode.attemptNotFound:
      return 'Tentativo esame non trovato.';
    case ExamQuizAttemptErrorCode.invalidPayload:
      return 'Dati del tentativo non coerenti.';
    case ExamQuizAttemptErrorCode.repositoryUnavailable:
      return 'Repository Quiz Esame non disponibile.';
    default:
      return 'Operazione non riuscita. Riprova più tardi.';
  }
}

String _extractCodeFromText(String text) {
  for (final code in ExamQuizAttemptErrorCode.knownCodes) {
    if (text.contains(code)) return code;
  }
  return ExamQuizAttemptErrorCode.unknown;
}

/// Estrae il codice da messaggi Postgrest / RAISE EXCEPTION.
String extractExamQuizAttemptErrorCode(Object error) {
  if (error is PostgrestException) {
    final parts = <String>[
      error.message,
      if (error.details != null) error.details.toString(),
      if (error.hint != null) error.hint.toString(),
      if (error.code != null) error.code!,
    ];
    final fromFields = _extractCodeFromText(parts.join(' '));
    if (fromFields != ExamQuizAttemptErrorCode.unknown) return fromFields;
  }
  return _extractCodeFromText(error.toString());
}

ExamQuizAttemptException examQuizAttemptExceptionFrom(Object error) {
  if (error is ExamQuizAttemptException) return error;
  final code = extractExamQuizAttemptErrorCode(error);
  return ExamQuizAttemptException(
    code: code,
    message: examQuizAttemptErrorMessageIt(code),
    cause: error,
  );
}
