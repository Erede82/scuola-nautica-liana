import '../../../domain/exam_quiz_attempt_exception.dart';
import '../../../domain/exam_quiz_attempt_models.dart';
import '../../../domain/exam_quiz_attempt_result.dart';
import '../../../domain/exam_quiz_rules.dart';
import '../../../domain/quiz_license_category.dart';
import '../../../models/license_models.dart';
import '../../../models/quiz_question.dart';

/// Parsing JSON/RPC → modelli Quiz Esame.
///
/// Le chiavi snake_case seguono la migration `exam_quiz_attempts`.

DateTime? parseExamQuizDateTime(Object? raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw.toUtc();
  if (raw is String) {
    final parsed = DateTime.tryParse(raw);
    return parsed?.toUtc();
  }
  return null;
}

DateTime requireExamQuizDateTime(Object? raw, {String field = 'timestamp'}) {
  final parsed = parseExamQuizDateTime(raw);
  if (parsed == null) {
    throw ExamQuizAttemptException(
      code: ExamQuizAttemptErrorCode.invalidPayload,
      message: 'Campo $field non valido: $raw',
    );
  }
  return parsed;
}

int? parseExamQuizInt(Object? raw) {
  if (raw == null) return null;
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw);
  return null;
}

int requireExamQuizNonNegativeInt(Object? raw, {required String field}) {
  final value = parseExamQuizInt(raw);
  if (value == null || value < 0) {
    throw ExamQuizAttemptException(
      code: ExamQuizAttemptErrorCode.invalidPayload,
      message: 'Campo $field non valido: $raw',
    );
  }
  return value;
}

bool? parseExamQuizBool(Object? raw) {
  if (raw == null) return null;
  if (raw is bool) return raw;
  if (raw is String) {
    switch (raw.trim().toLowerCase()) {
      case 'true':
      case 't':
      case '1':
        return true;
      case 'false':
      case 'f':
      case '0':
        return false;
    }
  }
  return null;
}

bool requireExamQuizBool(Object? raw, {required String field}) {
  final value = parseExamQuizBool(raw);
  if (value == null) {
    throw ExamQuizAttemptException(
      code: ExamQuizAttemptErrorCode.invalidPayload,
      message: 'Campo $field non valido: $raw',
    );
  }
  return value;
}

Map<String, dynamic> requireExamQuizMap(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  throw ExamQuizAttemptException(
    code: ExamQuizAttemptErrorCode.invalidPayload,
    message: 'Payload JSON non valido: $raw',
  );
}

/// Parsing prudente di RPC JSONB a oggetto singolo.
Map<String, dynamic> requireExamQuizSingleJsonb(Object? raw) {
  if (raw == null) {
    throw const ExamQuizAttemptException(
      code: ExamQuizAttemptErrorCode.invalidPayload,
      message: 'Payload JSONB assente.',
    );
  }
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  if (raw is List) {
    if (raw.isEmpty) {
      throw const ExamQuizAttemptException(
        code: ExamQuizAttemptErrorCode.invalidPayload,
        message: 'Payload JSONB lista vuota.',
      );
    }
    if (raw.length != 1) {
      throw ExamQuizAttemptException(
        code: ExamQuizAttemptErrorCode.invalidPayload,
        message: 'Payload JSONB lista con ${raw.length} elementi (atteso 1).',
      );
    }
    return requireExamQuizMap(raw.first);
  }
  throw ExamQuizAttemptException(
    code: ExamQuizAttemptErrorCode.invalidPayload,
    message: 'Payload JSONB di tipo sconosciuto: $raw',
  );
}

String requireExamQuizNonEmptyId(Object? raw, {required String field}) {
  final value = raw?.toString().trim() ?? '';
  if (value.isEmpty) {
    throw ExamQuizAttemptException(
      code: ExamQuizAttemptErrorCode.invalidPayload,
      message: 'Campo $field vuoto.',
    );
  }
  return value;
}

LicenseCategoryId requireExamQuizLicenseCategory(Object? raw) {
  final category = licenseCategoryIdFromDb(raw?.toString());
  if (category == null) {
    throw ExamQuizAttemptException(
      code: ExamQuizAttemptErrorCode.invalidLicenseCategory,
      message: examQuizAttemptErrorMessageIt(
        ExamQuizAttemptErrorCode.invalidLicenseCategory,
      ),
      cause: raw,
    );
  }
  return category;
}

QuizAnswerOption? parseExamQuizSelectedOption(Object? raw) {
  if (raw == null) return null;
  final text = raw.toString().trim();
  if (text.isEmpty) return null;
  final option = QuizAnswerOptionX.tryParse(text);
  if (option == null) {
    throw ExamQuizAttemptException(
      code: ExamQuizAttemptErrorCode.invalidPayload,
      message: 'Opzione selezionata non valida: $raw',
    );
  }
  return option;
}

QuizAnswerOption requireExamQuizCorrectOption(Object? raw) {
  final option = QuizAnswerOptionX.tryParse(raw?.toString());
  if (option == null) {
    throw ExamQuizAttemptException(
      code: ExamQuizAttemptErrorCode.invalidPayload,
      message: 'Opzione corretta non valida: $raw',
    );
  }
  return option;
}

void validateExamQuizAttemptCounts({
  required LicenseCategoryId licenseCategory,
  required int totalQuestions,
  required int correctCount,
  required int wrongCount,
  required int unansweredCount,
  required bool passed,
}) {
  final rules = examQuizRulesForCategory(licenseCategory);
  if (rules == null) {
    throw ExamQuizAttemptException(
      code: ExamQuizAttemptErrorCode.invalidLicenseCategory,
      message: examQuizAttemptErrorMessageIt(
        ExamQuizAttemptErrorCode.invalidLicenseCategory,
      ),
    );
  }
  if (totalQuestions <= 0) {
    throw const ExamQuizAttemptException(
      code: ExamQuizAttemptErrorCode.invalidPayload,
      message: 'total_questions non valido.',
    );
  }
  if (totalQuestions != rules.totalQuestions) {
    throw ExamQuizAttemptException(
      code: ExamQuizAttemptErrorCode.invalidPayload,
      message:
          'total_questions ($totalQuestions) non valido per la categoria: '
          'atteso ${rules.totalQuestions}.',
    );
  }
  if (correctCount + wrongCount + unansweredCount != totalQuestions) {
    throw ExamQuizAttemptException(
      code: ExamQuizAttemptErrorCode.invalidPayload,
      message:
          'Somma conteggi ($correctCount+$wrongCount+$unansweredCount) '
          'diversa da total_questions ($totalQuestions).',
    );
  }
  final expectedPassed =
      (wrongCount + unansweredCount) <= rules.maxErrorsToPass;
  if (passed != expectedPassed) {
    throw ExamQuizAttemptException(
      code: ExamQuizAttemptErrorCode.invalidPayload,
      message:
          'Campo passed ($passed) incoerente con errori '
          '(${wrongCount + unansweredCount}).',
    );
  }
}

ExamQuizAttemptSummary parseExamQuizAttemptSummary(Map<String, dynamic> json) {
  final id = requireExamQuizNonEmptyId(
    json['id'] ?? json['attempt_id'],
    field: 'id',
  );
  final licenseCategory = requireExamQuizLicenseCategory(
    json['license_category'],
  );
  final completedAt = requireExamQuizDateTime(
    json['completed_at'],
    field: 'completed_at',
  );
  final durationSeconds = requireExamQuizNonNegativeInt(
    json['duration_seconds'],
    field: 'duration_seconds',
  );
  final timeExpired = requireExamQuizBool(
    json['time_expired'],
    field: 'time_expired',
  );
  final totalQuestions = requireExamQuizNonNegativeInt(
    json['total_questions'],
    field: 'total_questions',
  );
  final correctCount = requireExamQuizNonNegativeInt(
    json['correct_count'],
    field: 'correct_count',
  );
  final wrongCount = requireExamQuizNonNegativeInt(
    json['wrong_count'],
    field: 'wrong_count',
  );
  final unansweredCount = requireExamQuizNonNegativeInt(
    json['unanswered_count'],
    field: 'unanswered_count',
  );
  final passed = requireExamQuizBool(json['passed'], field: 'passed');

  validateExamQuizAttemptCounts(
    licenseCategory: licenseCategory,
    totalQuestions: totalQuestions,
    correctCount: correctCount,
    wrongCount: wrongCount,
    unansweredCount: unansweredCount,
    passed: passed,
  );

  return ExamQuizAttemptSummary(
    id: id,
    licenseCategory: licenseCategory,
    completedAt: completedAt,
    duration: Duration(seconds: durationSeconds),
    timeExpired: timeExpired,
    totalQuestions: totalQuestions,
    correctCount: correctCount,
    wrongCount: wrongCount,
    unansweredCount: unansweredCount,
    outcome: passed ? ExamQuizOutcome.passed : ExamQuizOutcome.failed,
  );
}

ExamQuizAttemptSubmitResult parseExamQuizAttemptSubmitResult(Object? raw) {
  final json = requireExamQuizSingleJsonb(raw);
  final attempt = parseExamQuizAttemptSummary(json);
  final idempotent = requireExamQuizBool(
    json['idempotent'],
    field: 'idempotent',
  );
  return ExamQuizAttemptSubmitResult(attempt: attempt, idempotent: idempotent);
}

ExamQuizAttemptAnswerSnapshot parseExamQuizAttemptAnswerSnapshot(
  Map<String, dynamic> json,
) {
  final position = requireExamQuizNonNegativeInt(
    json['position'],
    field: 'position',
  );
  if (position < 1) {
    throw ExamQuizAttemptException(
      code: ExamQuizAttemptErrorCode.invalidPayload,
      message: 'Posizione non valida: $position',
    );
  }
  final questionId = requireExamQuizNonEmptyId(
    json['question_id'],
    field: 'question_id',
  );
  final prompt = (json['prompt_snapshot'] ?? json['prompt'])?.toString();
  final optionA = (json['option_a_snapshot'] ?? json['option_a'])?.toString();
  final optionB = (json['option_b_snapshot'] ?? json['option_b'])?.toString();
  final optionC = (json['option_c_snapshot'] ?? json['option_c'])?.toString();
  if (prompt == null ||
      prompt.isEmpty ||
      optionA == null ||
      optionA.isEmpty ||
      optionB == null ||
      optionB.isEmpty ||
      optionC == null ||
      optionC.isEmpty) {
    throw const ExamQuizAttemptException(
      code: ExamQuizAttemptErrorCode.invalidPayload,
      message: 'Snapshot domanda incompleto.',
    );
  }

  final imageRaw = json['image_path_snapshot'] ?? json['image_path'];
  final imagePath = imageRaw == null
      ? null
      : (() {
          final text = imageRaw.toString().trim();
          return text.isEmpty ? null : text;
        })();

  final selected = parseExamQuizSelectedOption(json['selected_option']);
  final correct = requireExamQuizCorrectOption(json['correct_option']);
  final isCorrect = requireExamQuizBool(
    json['is_correct'],
    field: 'is_correct',
  );
  final expectedCorrect = selected != null && selected == correct;
  if (isCorrect != expectedCorrect) {
    throw ExamQuizAttemptException(
      code: ExamQuizAttemptErrorCode.invalidPayload,
      message:
          'is_correct ($isCorrect) incoerente con selected/correct '
          'in posizione $position.',
    );
  }

  return ExamQuizAttemptAnswerSnapshot(
    position: position,
    questionId: questionId,
    prompt: prompt,
    optionA: optionA,
    optionB: optionB,
    optionC: optionC,
    selectedOption: selected,
    correctOption: correct,
    isCorrect: isCorrect,
    imagePath: imagePath,
  );
}

void validateExamQuizAnswerSnapshots({
  required int totalQuestions,
  required List<ExamQuizAttemptAnswerSnapshot> answers,
}) {
  if (answers.length != totalQuestions) {
    throw ExamQuizAttemptException(
      code: ExamQuizAttemptErrorCode.invalidPayload,
      message:
          'Numero risposte (${answers.length}) diverso da '
          'total_questions ($totalQuestions).',
    );
  }

  final positions = <int>{};
  final questionIds = <String>{};
  for (var i = 0; i < answers.length; i++) {
    final answer = answers[i];
    final expectedPosition = i + 1;
    if (answer.position != expectedPosition) {
      throw ExamQuizAttemptException(
        code: ExamQuizAttemptErrorCode.invalidPayload,
        message:
            'Posizioni non sequenziali: attesa $expectedPosition, '
            'trovata ${answer.position}.',
      );
    }
    if (!positions.add(answer.position)) {
      throw ExamQuizAttemptException(
        code: ExamQuizAttemptErrorCode.invalidPayload,
        message: 'Posizione duplicata: ${answer.position}.',
      );
    }
    if (!questionIds.add(answer.questionId)) {
      throw ExamQuizAttemptException(
        code: ExamQuizAttemptErrorCode.invalidPayload,
        message: 'question_id duplicato: ${answer.questionId}.',
      );
    }
  }
}

ExamQuizAttemptResult parseExamQuizAttemptResult({
  required Map<String, dynamic> attemptJson,
  required List<Map<String, dynamic>> answerRows,
}) {
  final summary = parseExamQuizAttemptSummary(attemptJson);
  final answers = answerRows.map(parseExamQuizAttemptAnswerSnapshot).toList()
    ..sort((a, b) => a.position.compareTo(b.position));

  validateExamQuizAnswerSnapshots(
    totalQuestions: summary.totalQuestions,
    answers: answers,
  );

  return ExamQuizAttemptResult(
    id: summary.id,
    licenseCategory: summary.licenseCategory,
    completedAt: summary.completedAt,
    duration: summary.duration,
    timeExpired: summary.timeExpired,
    totalQuestions: summary.totalQuestions,
    correctCount: summary.correctCount,
    wrongCount: summary.wrongCount,
    unansweredCount: summary.unansweredCount,
    outcome: summary.outcome,
    answers: List.unmodifiable(answers),
  );
}
