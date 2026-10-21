import 'quiz_result_row.dart';
import 'quiz_sheet_catalog_row.dart';
import '../student_quiz_statistics_data_source.dart';

/// Payload JSON di `get_staff_student_quiz_statistics_inputs`.
class StaffStudentQuizStatisticsRpcPayload {
  const StaffStudentQuizStatisticsRpcPayload({
    required this.linkedUser,
    required this.category,
    required this.lessonAttempts,
    required this.lessonAnswerCounts,
    required this.multiAttempts,
    required this.multiAnswerEvents,
    required this.examAttempts,
    required this.examAnswerEvents,
    required this.lessonCatalog,
  });

  final bool linkedUser;
  final String category;
  final List<QuizResultRow> lessonAttempts;

  /// `quiz_result_id` → `answer_count` (RPC).
  final Map<String, int> lessonAnswerCounts;
  final List<MultiTopicStatsAttemptRow> multiAttempts;
  final List<MultiTopicStatsAnswerRow> multiAnswerEvents;
  final List<ExamStatsAttemptRow> examAttempts;

  /// Esame: lesson_number già joinato server-side (nullable).
  final List<StaffExamAnswerEvent> examAnswerEvents;
  final List<QuizSheetCatalogRow> lessonCatalog;

  factory StaffStudentQuizStatisticsRpcPayload.fromJson(Object? raw) {
    final map = _requireMap(raw, 'staff stats rpc payload');
    final linked = _asBool(map['linked_user']) ?? false;
    final category = map['category']?.toString() ?? '';

    final lessonAttempts = <QuizResultRow>[];
    final lessonAnswerCounts = <String, int>{};
    for (final item in _asList(map['lesson_attempts'])) {
      final row = _requireMap(item, 'lesson_attempt');
      final parsed = _lessonAttemptFromRpc(row);
      lessonAttempts.add(parsed.result);
      lessonAnswerCounts[parsed.result.id] = parsed.answerCount;
    }

    final multiAttempts = <MultiTopicStatsAttemptRow>[
      for (final item in _asList(map['multi_attempts']))
        _multiAttemptFromRpc(_requireMap(item, 'multi_attempt'), category),
    ];

    final multiAnswers = <MultiTopicStatsAnswerRow>[
      for (final item in _asList(map['multi_answer_events']))
        _multiAnswerFromRpc(_requireMap(item, 'multi_answer_event')),
    ];

    final examAttempts = <ExamStatsAttemptRow>[
      for (final item in _asList(map['exam_attempts']))
        _examAttemptFromRpc(_requireMap(item, 'exam_attempt'), category),
    ];

    final examAnswers = <StaffExamAnswerEvent>[
      for (final item in _asList(map['exam_answer_events']))
        StaffExamAnswerEvent.fromJson(_requireMap(item, 'exam_answer_event')),
    ];

    final catalog = <QuizSheetCatalogRow>[
      for (final item in _asList(map['lesson_catalog']))
        QuizSheetCatalogRow.fromJson(_requireMap(item, 'lesson_catalog')),
    ];

    return StaffStudentQuizStatisticsRpcPayload(
      linkedUser: linked,
      category: category,
      lessonAttempts: lessonAttempts,
      lessonAnswerCounts: lessonAnswerCounts,
      multiAttempts: multiAttempts,
      multiAnswerEvents: multiAnswers,
      examAttempts: examAttempts,
      examAnswerEvents: examAnswers,
      lessonCatalog: catalog,
    );
  }
}

/// Evento risposta esame dallo staff RPC (lesson_number nullable).
class StaffExamAnswerEvent {
  const StaffExamAnswerEvent({
    required this.attemptId,
    required this.lessonNumber,
    required this.isCorrect,
    required this.isUnanswered,
  });

  final String attemptId;
  final int? lessonNumber;
  final bool isCorrect;
  final bool isUnanswered;

  factory StaffExamAnswerEvent.fromJson(Map<String, dynamic> json) {
    final attemptId = json['attempt_id']?.toString() ?? '';
    if (attemptId.isEmpty) {
      throw const FormatException('exam_answer_event.attempt_id missing');
    }
    return StaffExamAnswerEvent(
      attemptId: attemptId,
      lessonNumber: _asNullableInt(json['lesson_number']),
      isCorrect: _asBool(json['is_correct']) ?? false,
      isUnanswered: _asBool(json['is_unanswered']) ?? false,
    );
  }
}

class _LessonAttemptParsed {
  const _LessonAttemptParsed({
    required this.result,
    required this.answerCount,
  });

  final QuizResultRow result;
  final int answerCount;
}

_LessonAttemptParsed _lessonAttemptFromRpc(Map<String, dynamic> json) {
  final id = json['id']?.toString() ?? '';
  if (id.isEmpty) {
    throw const FormatException('lesson_attempt.id missing');
  }
  final result = QuizResultRow(
    id: id,
    quizSetId: json['quiz_set_id']?.toString() ?? '',
    totalQuestions: _asInt(json['total_questions']),
    correctCount: _asInt(json['correct_count']),
    wrongCount: _asInt(json['wrong_count']),
    unansweredCount: _asInt(json['unanswered_count']),
    lessonNumber: _asInt(json['lesson_number']),
    sheetNumber: _asInt(json['sheet_number']),
    licenseCategory: json['license_category']?.toString() ?? '',
    kind: json['kind']?.toString() ?? '',
    startedAt: _parseTs(json['started_at']),
    completedAt: _parseTs(json['completed_at']),
    createdAt: _parseTs(json['created_at']),
    durationSeconds: _asNullableInt(json['duration_seconds']),
  );
  return _LessonAttemptParsed(
    result: result,
    answerCount: _asInt(json['answer_count']),
  );
}

MultiTopicStatsAttemptRow _multiAttemptFromRpc(
  Map<String, dynamic> json,
  String fallbackCategory,
) {
  final id = json['id']?.toString() ?? '';
  if (id.isEmpty) {
    throw const FormatException('multi_attempt.id missing');
  }
  final completedAt = _parseTs(json['completed_at']);
  if (completedAt == null) {
    throw const FormatException('multi_attempt.completed_at missing');
  }
  return MultiTopicStatsAttemptRow(
    id: id,
    userId: '',
    licenseCategory:
        json['license_category']?.toString() ?? fallbackCategory,
    sessionId: json['session_id']?.toString() ?? '',
    sheetIndex: _asInt(json['sheet_index']),
    completedAt: completedAt,
    totalQuestions: _asInt(json['total_questions']),
    correctCount: _asInt(json['correct_count']),
    wrongCount: _asInt(json['wrong_count']),
    unansweredCount: _asInt(json['unanswered_count']),
  );
}

MultiTopicStatsAnswerRow _multiAnswerFromRpc(Map<String, dynamic> json) {
  final attemptId = json['attempt_id']?.toString() ?? '';
  if (attemptId.isEmpty) {
    throw const FormatException('multi_answer_event.attempt_id missing');
  }
  return MultiTopicStatsAnswerRow(
    attemptId: attemptId,
    lessonNumberSnapshot: _asNullableInt(json['lesson_number']),
    isCorrect: _asBool(json['is_correct']) ?? false,
    isUnanswered: _asBool(json['is_unanswered']) ?? false,
  );
}

ExamStatsAttemptRow _examAttemptFromRpc(
  Map<String, dynamic> json,
  String fallbackCategory,
) {
  final id = json['id']?.toString() ?? '';
  if (id.isEmpty) {
    throw const FormatException('exam_attempt.id missing');
  }
  final completedAt = _parseTs(json['completed_at']);
  if (completedAt == null) {
    throw const FormatException('exam_attempt.completed_at missing');
  }
  return ExamStatsAttemptRow(
    id: id,
    userId: '',
    licenseCategory:
        json['license_category']?.toString() ?? fallbackCategory,
    completedAt: completedAt,
    totalQuestions: _asInt(json['total_questions']),
    correctCount: _asInt(json['correct_count']),
    wrongCount: _asInt(json['wrong_count']),
    unansweredCount: _asInt(json['unanswered_count']),
    passed: _asBool(json['passed']) ?? false,
  );
}

Map<String, dynamic> _requireMap(Object? raw, String label) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  throw FormatException('$label: expected object, got ${raw.runtimeType}');
}

List<Object?> _asList(Object? raw) {
  if (raw == null) return const [];
  if (raw is List) return raw.cast<Object?>();
  throw FormatException('expected array, got ${raw.runtimeType}');
}

int _asInt(Object? value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

int? _asNullableInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

bool? _asBool(Object? value) {
  if (value == null) return null;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final v = value.toLowerCase();
    if (v == 'true' || v == 't' || v == '1') return true;
    if (v == 'false' || v == 'f' || v == '0') return false;
  }
  return null;
}

DateTime? _parseTs(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
