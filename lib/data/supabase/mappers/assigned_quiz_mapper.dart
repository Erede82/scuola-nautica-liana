import '../../../models/assigned_quiz_models.dart';
import '../../../models/quiz_question.dart';

/// Parsing JSON/RPC → modelli Assigned Quiz.
///
/// Le chiavi snake_case seguono le RPC SQL della migration foundation.

DateTime? parseAssignedQuizDateTime(Object? raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw.toUtc();
  if (raw is String) {
    final parsed = DateTime.tryParse(raw);
    return parsed?.toUtc();
  }
  return null;
}

DateTime requireAssignedQuizDateTime(
  Object? raw, {
  String field = 'timestamp',
}) {
  final parsed = parseAssignedQuizDateTime(raw);
  if (parsed == null) {
    throw FormatException('Campo $field non valido: $raw');
  }
  return parsed;
}

int? parseAssignedQuizInt(Object? raw) {
  if (raw == null) return null;
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw);
  return null;
}

double? parseAssignedQuizDouble(Object? raw) {
  if (raw == null) return null;
  if (raw is double) return raw;
  if (raw is num) return raw.toDouble();
  if (raw is String) return double.tryParse(raw);
  return null;
}

bool? parseAssignedQuizBool(Object? raw) {
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

Map<String, dynamic> requireAssignedQuizMap(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  throw FormatException('Payload JSON non valido: $raw');
}

/// Parsing prudente di RPC JSONB a oggetto singolo.
///
/// Accetta `Map` oppure `List` con esattamente un elemento Map.
/// Rifiuta null, lista vuota, lista multipla, tipi sconosciuti.
Map<String, dynamic> requireAssignedQuizSingleJsonb(Object? raw) {
  if (raw == null) {
    throw const FormatException('Payload JSONB assente.');
  }
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  if (raw is List) {
    if (raw.isEmpty) {
      throw const FormatException('Payload JSONB lista vuota.');
    }
    if (raw.length != 1) {
      throw FormatException(
        'Payload JSONB lista con ${raw.length} elementi (atteso 1).',
      );
    }
    return requireAssignedQuizMap(raw.first);
  }
  throw FormatException('Payload JSONB di tipo sconosciuto: $raw');
}

/// Normalizza opzione DB A/B/C (o null). Rifiuta valori non ammessi.
String? normalizeAssignedQuizSelectedOption(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final option = QuizAnswerOptionX.tryParse(trimmed);
  if (option == null) {
    throw const AssignedQuizException(
      code: AssignedQuizErrorCode.invalidSelectedOption,
      message: 'Opzione di risposta non valida.',
    );
  }
  return option.letter;
}

/// Marker UI 1/2/3 ↔ [QuizAnswerOption] (riuso pattern player esistente).
int assignedQuizOptionToMarkerNumber(QuizAnswerOption option) =>
    option.index + 1;

QuizAnswerOption? assignedQuizMarkerNumberToOption(int number) {
  switch (number) {
    case 1:
      return QuizAnswerOption.a;
    case 2:
      return QuizAnswerOption.b;
    case 3:
      return QuizAnswerOption.c;
    default:
      return null;
  }
}

AssignedQuizSummary parseAssignedQuizSummary(Map<String, dynamic> json) {
  final status = AssignedQuizStatus.tryParse(json['status']?.toString());
  final repeat = AssignedQuizRepeatPolicy.tryParse(
    json['repeat_policy']?.toString(),
  );
  if (status == null || repeat == null) {
    throw FormatException('Stato o policy non validi: $json');
  }

  return AssignedQuizSummary(
    id: json['id']?.toString() ?? '',
    publicCode: json['public_code']?.toString() ?? '',
    studentId: json['student_id']?.toString() ?? '',
    studentUserId: json['student_user_id']?.toString() ?? '',
    licenseCategory: json['license_category']?.toString() ?? '',
    title: json['title']?.toString() ?? '',
    staffNote: json['staff_note']?.toString(),
    status: status,
    questionCount: parseAssignedQuizInt(json['question_count']) ?? 0,
    repeatPolicy: repeat,
    maxAttempts: parseAssignedQuizInt(json['max_attempts']),
    createdAt: requireAssignedQuizDateTime(
      json['created_at'],
      field: 'created_at',
    ),
    assignedAt: parseAssignedQuizDateTime(json['assigned_at']),
    expiresAt: parseAssignedQuizDateTime(json['expires_at']),
    archivedAt: parseAssignedQuizDateTime(json['archived_at']),
    attemptsCount: parseAssignedQuizInt(json['attempts_count']),
    submittedAttemptsCount: parseAssignedQuizInt(
      json['submitted_attempts_count'],
    ),
    latestAttemptAt: parseAssignedQuizDateTime(json['latest_attempt_at']),
    bestScorePercentage: parseAssignedQuizDouble(json['best_score_percentage']),
    averageScorePercentage: parseAssignedQuizDouble(
      json['average_score_percentage'],
    ),
    hasInProgressAttempt: parseAssignedQuizBool(
      json['has_in_progress_attempt'],
    ),
    attemptsUsedCount: parseAssignedQuizInt(json['attempts_used_count']),
  );
}

/// Aggrega tentativi per assignment e popola i campi summary usati dalla lista.
///
/// - [AssignedQuizSummary.hasInProgressAttempt]: esiste `in_progress`
/// - [AssignedQuizSummary.submittedAttemptsCount]: solo `submitted`
/// - [AssignedQuizSummary.attemptsUsedCount]: `in_progress` + `submitted` +
///   `abandoned` (stessa semantica del limite RPC)
List<AssignedQuizSummary> enrichAssignedQuizSummariesWithAttemptRows(
  List<AssignedQuizSummary> summaries,
  Iterable<Map<String, dynamic>> attemptRows,
) {
  final byAssignment = <String, List<AssignedQuizAttemptStatus>>{};
  for (final row in attemptRows) {
    final assignmentId = row['assignment_id']?.toString() ?? '';
    if (assignmentId.isEmpty) continue;
    final status = AssignedQuizAttemptStatus.tryParse(
      row['status']?.toString(),
    );
    if (status == null) continue;
    (byAssignment[assignmentId] ??= <AssignedQuizAttemptStatus>[]).add(status);
  }

  return summaries
      .map((summary) {
        final statuses = byAssignment[summary.id] ?? const [];
        final submitted = statuses
            .where((s) => s == AssignedQuizAttemptStatus.submitted)
            .length;
        final inProgress = statuses.any(
          (s) => s == AssignedQuizAttemptStatus.inProgress,
        );
        return summary.copyWith(
          hasInProgressAttempt: inProgress,
          submittedAttemptsCount: submitted,
          attemptsUsedCount: statuses.length,
          attemptsCount: statuses.length,
        );
      })
      .toList(growable: false);
}

/// Variante tipizzata per Fake / test a partire da [AssignedQuizAttemptSummary].
List<AssignedQuizSummary> enrichAssignedQuizSummariesWithAttempts(
  List<AssignedQuizSummary> summaries,
  Iterable<AssignedQuizAttemptSummary> attempts,
) {
  return enrichAssignedQuizSummariesWithAttemptRows(
    summaries,
    attempts.map(
      (a) => <String, dynamic>{
        'assignment_id': a.assignmentId,
        'status': a.status.dbValue,
        'attempt_number': a.attemptNumber,
      },
    ),
  );
}

AssignedQuizGenerationResult parseAssignedQuizGenerationResult(Object? raw) {
  final json = requireAssignedQuizSingleJsonb(raw);
  final status = AssignedQuizStatus.tryParse(json['status']?.toString());
  if (status == null) {
    throw FormatException('Status generazione non valido: $json');
  }
  return AssignedQuizGenerationResult(
    assignmentId: json['assignment_id']?.toString() ?? '',
    publicCode: json['public_code']?.toString() ?? '',
    itemCount: parseAssignedQuizInt(json['item_count']) ?? 0,
    status: status,
    licenseCategory: json['license_category']?.toString() ?? '',
    idempotent: parseAssignedQuizBool(json['idempotent']) ?? false,
  );
}

AssignedQuizAttemptStartResult parseAssignedQuizAttemptStartResult(
  Object? raw,
) {
  final json = requireAssignedQuizSingleJsonb(raw);
  return AssignedQuizAttemptStartResult(
    attemptId: json['attempt_id']?.toString() ?? '',
    attemptNumber: parseAssignedQuizInt(json['attempt_number']) ?? 0,
    resumed: parseAssignedQuizBool(json['resumed']) ?? false,
    questionCount: parseAssignedQuizInt(json['question_count']) ?? 0,
    maxAttempts: parseAssignedQuizInt(json['max_attempts']),
    attemptsUsed: parseAssignedQuizInt(json['attempts_used']) ?? 0,
  );
}

/// Parsing domanda player: rifiuta payload che espongono la soluzione.
AssignedQuizQuestion parseAssignedQuizQuestion(Map<String, dynamic> json) {
  const forbidden = {
    'correct_option',
    'correctOption',
    'explanation',
    'is_correct',
    'isCorrect',
    'historical_error_count',
    'historicalErrorCount',
  };
  for (final key in forbidden) {
    if (json.containsKey(key) && json[key] != null) {
      throw const FormatException(
        'Payload domande player contiene campi riservati alla review.',
      );
    }
  }

  return AssignedQuizQuestion(
    assignmentItemId: json['assignment_item_id']?.toString() ?? '',
    position: parseAssignedQuizInt(json['position']) ?? 0,
    prompt: json['prompt']?.toString() ?? '',
    optionA: json['option_a']?.toString() ?? '',
    optionB: json['option_b']?.toString() ?? '',
    optionC: json['option_c']?.toString() ?? '',
    imagePath: json['image_path']?.toString(),
    lessonNumber: parseAssignedQuizInt(json['lesson_number']) ?? 0,
    selectedOption: json['selected_option']?.toString(),
  );
}

AssignedQuizAnswerSaveResult parseAssignedQuizAnswerSaveResult(Object? raw) {
  final json = requireAssignedQuizSingleJsonb(raw);
  return AssignedQuizAnswerSaveResult(
    assignmentItemId: json['assignment_item_id']?.toString() ?? '',
    selectedOption: json['selected_option']?.toString(),
    answeredAt: parseAssignedQuizDateTime(json['answered_at']),
  );
}

AssignedQuizSubmitResult parseAssignedQuizSubmitResult(Object? raw) {
  final json = requireAssignedQuizSingleJsonb(raw);
  return AssignedQuizSubmitResult(
    attemptId: json['attempt_id']?.toString() ?? '',
    attemptNumber: parseAssignedQuizInt(json['attempt_number']) ?? 0,
    correctCount: parseAssignedQuizInt(json['correct_count']) ?? 0,
    wrongCount: parseAssignedQuizInt(json['wrong_count']) ?? 0,
    unansweredCount: parseAssignedQuizInt(json['unanswered_count']) ?? 0,
    scorePercentage: parseAssignedQuizDouble(json['score_percentage']) ?? 0,
    submittedAt: parseAssignedQuizDateTime(json['submitted_at']),
    alreadySubmitted: parseAssignedQuizBool(json['already_submitted']) ?? false,
  );
}

AssignedQuizReviewItem parseAssignedQuizReviewItem(Map<String, dynamic> json) {
  return AssignedQuizReviewItem(
    position: parseAssignedQuizInt(json['position']) ?? 0,
    prompt: json['prompt']?.toString() ?? '',
    optionA: json['option_a']?.toString() ?? '',
    optionB: json['option_b']?.toString() ?? '',
    optionC: json['option_c']?.toString() ?? '',
    imagePath: json['image_path']?.toString(),
    selectedOption: json['selected_option']?.toString(),
    correctOption: json['correct_option']?.toString() ?? '',
    isCorrect: parseAssignedQuizBool(json['is_correct']),
    explanation: json['explanation']?.toString(),
    lessonNumber: parseAssignedQuizInt(json['lesson_number']) ?? 0,
  );
}

AssignedQuizAttemptSummary parseAssignedQuizAttemptSummary(
  Map<String, dynamic> json,
) {
  final status = AssignedQuizAttemptStatus.tryParse(json['status']?.toString());
  if (status == null) {
    throw FormatException('Stato tentativo non valido: $json');
  }
  return AssignedQuizAttemptSummary(
    id: json['id']?.toString() ?? '',
    assignmentId: json['assignment_id']?.toString() ?? '',
    attemptNumber: parseAssignedQuizInt(json['attempt_number']) ?? 0,
    status: status,
    startedAt: requireAssignedQuizDateTime(
      json['started_at'],
      field: 'started_at',
    ),
    submittedAt: parseAssignedQuizDateTime(json['submitted_at']),
    abandonedAt: parseAssignedQuizDateTime(json['abandoned_at']),
    correctCount: parseAssignedQuizInt(json['correct_count']) ?? 0,
    wrongCount: parseAssignedQuizInt(json['wrong_count']) ?? 0,
    unansweredCount: parseAssignedQuizInt(json['unanswered_count']) ?? 0,
    scorePercentage: parseAssignedQuizDouble(json['score_percentage']),
    durationSeconds: parseAssignedQuizInt(json['duration_seconds']),
  );
}

/// Dedup + sort crescente delle lezioni selezionate.
List<int> normalizeAssignedQuizLessonNumbers(Iterable<int> raw) {
  final unique = raw.toSet().toList()..sort();
  return List<int>.unmodifiable(unique);
}

/// Parametri RPC `generate_assigned_quiz_from_errors` (senza license_category).
Map<String, dynamic> assignedQuizGenerateRpcParams(
  AssignedQuizGenerationRequest request,
) {
  request.ensureValid();
  return <String, dynamic>{
    'p_student_id': request.studentId.trim(),
    'p_title': request.title.trim(),
    'p_staff_note': request.staffNote?.trim().isEmpty == true
        ? null
        : request.staffNote?.trim(),
    'p_question_count': request.questionCount,
    'p_lesson_filter_mode': request.lessonFilterMode.dbValue,
    'p_lesson_numbers':
        request.lessonFilterMode == AssignedQuizLessonFilterMode.selectedLessons
        ? normalizeAssignedQuizLessonNumbers(request.lessonNumbers)
        : null,
    'p_sort_mode': request.sortMode.dbValue,
    'p_repeat_policy': request.repeatPolicy.dbValue,
    'p_max_attempts': request.maxAttempts,
    'p_expires_at': request.expiresAt?.toUtc().toIso8601String(),
    'p_allow_partial': request.allowPartial,
    'p_assign_immediately': request.assignImmediately,
    'p_idempotency_key': request.idempotencyKey?.trim().isEmpty == true
        ? null
        : request.idempotencyKey?.trim(),
  };
}

List<AssignedQuizQuestion> parseAssignedQuizQuestionList(Object? raw) {
  if (raw == null) return const [];
  if (raw is! List) {
    throw FormatException('Lista domande non valida: $raw');
  }
  return raw
      .map((item) => parseAssignedQuizQuestion(requireAssignedQuizMap(item)))
      .toList(growable: false);
}

List<AssignedQuizReviewItem> parseAssignedQuizReviewList(Object? raw) {
  if (raw == null) return const [];
  if (raw is! List) {
    throw FormatException('Lista review non valida: $raw');
  }
  return raw
      .map((item) => parseAssignedQuizReviewItem(requireAssignedQuizMap(item)))
      .toList(growable: false);
}
