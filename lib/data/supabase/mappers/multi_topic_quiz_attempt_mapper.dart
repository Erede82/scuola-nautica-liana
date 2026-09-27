import '../../../domain/multi_topic_quiz_attempt_exception.dart';
import '../../../domain/multi_topic_quiz_attempt_result.dart';
import '../../../domain/multi_topic_quiz_history_models.dart';
import '../../../domain/quiz_license_category.dart';
import '../../../models/quiz_question.dart';

DateTime? parseMultiTopicDateTime(Object? raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw.toUtc();
  if (raw is String) {
    final parsed = DateTime.tryParse(raw);
    return parsed?.toUtc();
  }
  return null;
}

DateTime requireMultiTopicDateTime(Object? raw, {String field = 'timestamp'}) {
  final parsed = parseMultiTopicDateTime(raw);
  if (parsed == null) {
    throw MultiTopicQuizAttemptException(
      code: MultiTopicQuizAttemptErrorCode.invalidPayload,
      message: 'Campo $field non valido: $raw',
    );
  }
  return parsed;
}

int? parseMultiTopicInt(Object? raw) {
  if (raw == null) return null;
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw);
  return null;
}

int requireMultiTopicNonNegativeInt(Object? raw, {required String field}) {
  final value = parseMultiTopicInt(raw);
  if (value == null || value < 0) {
    throw MultiTopicQuizAttemptException(
      code: MultiTopicQuizAttemptErrorCode.invalidPayload,
      message: 'Campo $field non valido: $raw',
    );
  }
  return value;
}

bool? parseMultiTopicBool(Object? raw) {
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

bool requireMultiTopicBool(Object? raw, {required String field}) {
  final value = parseMultiTopicBool(raw);
  if (value == null) {
    throw MultiTopicQuizAttemptException(
      code: MultiTopicQuizAttemptErrorCode.invalidPayload,
      message: 'Campo $field non valido: $raw',
    );
  }
  return value;
}

Map<String, dynamic> requireMultiTopicMap(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  throw MultiTopicQuizAttemptException(
    code: MultiTopicQuizAttemptErrorCode.invalidPayload,
    message: 'Payload JSON non valido: $raw',
  );
}

Map<String, dynamic> requireMultiTopicSingleJsonb(Object? raw) {
  if (raw == null) {
    throw const MultiTopicQuizAttemptException(
      code: MultiTopicQuizAttemptErrorCode.invalidPayload,
      message: 'Payload JSONB assente.',
    );
  }
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  if (raw is List) {
    if (raw.isEmpty) {
      throw const MultiTopicQuizAttemptException(
        code: MultiTopicQuizAttemptErrorCode.invalidPayload,
        message: 'Payload JSONB lista vuota.',
      );
    }
    if (raw.length != 1) {
      throw MultiTopicQuizAttemptException(
        code: MultiTopicQuizAttemptErrorCode.invalidPayload,
        message: 'Payload JSONB lista con ${raw.length} elementi (atteso 1).',
      );
    }
    return requireMultiTopicMap(raw.first);
  }
  throw MultiTopicQuizAttemptException(
    code: MultiTopicQuizAttemptErrorCode.invalidPayload,
    message: 'Payload JSONB di tipo sconosciuto: $raw',
  );
}

List<int> requireMultiTopicIntList(Object? raw, {required String field}) {
  if (raw is! List) {
    throw MultiTopicQuizAttemptException(
      code: MultiTopicQuizAttemptErrorCode.invalidPayload,
      message: 'Campo $field non è una lista.',
    );
  }
  final out = <int>[];
  for (final item in raw) {
    final value = parseMultiTopicInt(item);
    if (value == null) {
      throw MultiTopicQuizAttemptException(
        code: MultiTopicQuizAttemptErrorCode.invalidPayload,
        message: 'Campo $field contiene un valore non intero: $item',
      );
    }
    out.add(value);
  }
  return out;
}

MultiTopicQuizAttemptResult parseMultiTopicQuizAttemptSubmitResult(
  Object? raw,
) {
  final map = requireMultiTopicSingleJsonb(raw);
  final categoryRaw = map['license_category']?.toString();
  final category = licenseCategoryIdFromDb(categoryRaw);
  if (category == null) {
    throw MultiTopicQuizAttemptException(
      code: MultiTopicQuizAttemptErrorCode.invalidLicenseCategory,
      message: 'Categoria patente non valida: $categoryRaw',
    );
  }

  final attemptId = map['attempt_id']?.toString() ?? '';
  final sessionId = map['session_id']?.toString() ?? '';
  if (attemptId.isEmpty || sessionId.isEmpty) {
    throw const MultiTopicQuizAttemptException(
      code: MultiTopicQuizAttemptErrorCode.invalidPayload,
      message: 'attempt_id / session_id mancanti nel risultato RPC.',
    );
  }

  return MultiTopicQuizAttemptResult(
    attemptId: attemptId,
    sessionId: sessionId,
    sheetIndex: requireMultiTopicNonNegativeInt(
      map['sheet_index'],
      field: 'sheet_index',
    ),
    totalSheets: requireMultiTopicNonNegativeInt(
      map['total_sheets'],
      field: 'total_sheets',
    ),
    licenseCategory: category,
    lessonNumbers: requireMultiTopicIntList(
      map['lesson_numbers'],
      field: 'lesson_numbers',
    ),
    completedAt: requireMultiTopicDateTime(
      map['completed_at'],
      field: 'completed_at',
    ),
    durationSeconds: requireMultiTopicNonNegativeInt(
      map['duration_seconds'],
      field: 'duration_seconds',
    ),
    totalQuestions: requireMultiTopicNonNegativeInt(
      map['total_questions'],
      field: 'total_questions',
    ),
    correctCount: requireMultiTopicNonNegativeInt(
      map['correct_count'],
      field: 'correct_count',
    ),
    wrongCount: requireMultiTopicNonNegativeInt(
      map['wrong_count'],
      field: 'wrong_count',
    ),
    unansweredCount: requireMultiTopicNonNegativeInt(
      map['unanswered_count'],
      field: 'unanswered_count',
    ),
    idempotent: requireMultiTopicBool(map['idempotent'], field: 'idempotent'),
  );
}

MultiTopicQuizAttemptSummary parseMultiTopicQuizAttemptSummary(
  Map<String, dynamic> map,
) {
  final id = map['id']?.toString() ?? '';
  final sessionId = map['session_id']?.toString() ?? '';
  if (id.isEmpty || sessionId.isEmpty) {
    throw const MultiTopicQuizAttemptException(
      code: MultiTopicQuizAttemptErrorCode.invalidPayload,
      message: 'id / session_id mancanti nel riepilogo Multischeda.',
    );
  }
  final categoryRaw = map['license_category']?.toString();
  final category = licenseCategoryIdFromDb(categoryRaw);
  if (category == null) {
    throw MultiTopicQuizAttemptException(
      code: MultiTopicQuizAttemptErrorCode.invalidLicenseCategory,
      message: 'Categoria patente non valida: $categoryRaw',
    );
  }
  return MultiTopicQuizAttemptSummary(
    id: id,
    sessionId: sessionId,
    licenseCategory: category,
    lessonNumbers: requireMultiTopicIntList(
      map['lesson_numbers'],
      field: 'lesson_numbers',
    ),
    sheetIndex: requireMultiTopicNonNegativeInt(
      map['sheet_index'],
      field: 'sheet_index',
    ),
    totalSheets: requireMultiTopicNonNegativeInt(
      map['total_sheets'],
      field: 'total_sheets',
    ),
    completedAt: requireMultiTopicDateTime(
      map['completed_at'],
      field: 'completed_at',
    ),
    durationSeconds: requireMultiTopicNonNegativeInt(
      map['duration_seconds'],
      field: 'duration_seconds',
    ),
    totalQuestions: requireMultiTopicNonNegativeInt(
      map['total_questions'],
      field: 'total_questions',
    ),
    correctCount: requireMultiTopicNonNegativeInt(
      map['correct_count'],
      field: 'correct_count',
    ),
    wrongCount: requireMultiTopicNonNegativeInt(
      map['wrong_count'],
      field: 'wrong_count',
    ),
    unansweredCount: requireMultiTopicNonNegativeInt(
      map['unanswered_count'],
      field: 'unanswered_count',
    ),
  );
}

MultiTopicQuizAttemptAnswerSnapshot parseMultiTopicQuizAttemptAnswerSnapshot(
  Map<String, dynamic> map,
) {
  final questionId = map['question_id']?.toString() ?? '';
  if (questionId.isEmpty) {
    throw const MultiTopicQuizAttemptException(
      code: MultiTopicQuizAttemptErrorCode.invalidPayload,
      message: 'question_id mancante nello snapshot Multischeda.',
    );
  }
  final correctRaw = map['correct_option']?.toString();
  final correct = QuizAnswerOptionX.tryParse(correctRaw);
  if (correct == null) {
    throw MultiTopicQuizAttemptException(
      code: MultiTopicQuizAttemptErrorCode.invalidPayload,
      message: 'correct_option non valido: $correctRaw',
    );
  }
  return MultiTopicQuizAttemptAnswerSnapshot(
    position: requireMultiTopicNonNegativeInt(
      map['position'],
      field: 'position',
    ),
    questionId: questionId,
    prompt: map['prompt_snapshot']?.toString() ?? '',
    optionA: map['option_a_snapshot']?.toString() ?? '',
    optionB: map['option_b_snapshot']?.toString() ?? '',
    optionC: map['option_c_snapshot']?.toString() ?? '',
    selectedOption: QuizAnswerOptionX.tryParse(
      map['selected_option']?.toString(),
    ),
    correctOption: correct,
    isCorrect: requireMultiTopicBool(map['is_correct'], field: 'is_correct'),
    lessonNumber: requireMultiTopicNonNegativeInt(
      map['lesson_number_snapshot'],
      field: 'lesson_number_snapshot',
    ),
    imagePath: map['image_path_snapshot']?.toString(),
    explanation: map['explanation_snapshot']?.toString(),
  );
}

MultiTopicQuizAttemptDetail parseMultiTopicQuizAttemptDetail({
  required Map<String, dynamic> attemptRow,
  required List<dynamic> answerRows,
}) {
  final summary = parseMultiTopicQuizAttemptSummary(attemptRow);
  final answers =
      answerRows
          .map(
            (row) => parseMultiTopicQuizAttemptAnswerSnapshot(
              requireMultiTopicMap(row),
            ),
          )
          .toList(growable: false)
        ..sort((a, b) => a.position.compareTo(b.position));
  return MultiTopicQuizAttemptDetail(summary: summary, answers: answers);
}
