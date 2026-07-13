/// Riga `quiz_results` con metadati scheda da join `quiz_sets`.
class QuizResultRow {
  const QuizResultRow({
    required this.id,
    required this.quizSetId,
    required this.totalQuestions,
    required this.correctCount,
    required this.wrongCount,
    required this.unansweredCount,
    required this.lessonNumber,
    required this.sheetNumber,
    required this.licenseCategory,
    required this.kind,
    this.wrongQuestionIds = const [],
    this.startedAt,
    this.completedAt,
    this.createdAt,
    this.durationSeconds,
  });

  final String id;
  final String quizSetId;
  final int totalQuestions;
  final int correctCount;
  final int wrongCount;
  final int unansweredCount;
  final List<String> wrongQuestionIds;
  final int lessonNumber;
  final int sheetNumber;
  final String licenseCategory;
  final String kind;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? createdAt;
  final int? durationSeconds;

  factory QuizResultRow.fromJson(Map<String, dynamic> json) {
    final set = _nestedQuizSet(json['quiz_sets']);

    return QuizResultRow(
      id: json['id']?.toString() ?? '',
      quizSetId: json['quiz_set_id']?.toString() ?? '',
      totalQuestions: (json['total_questions'] as num?)?.toInt() ?? 0,
      correctCount: (json['correct_count'] as num?)?.toInt() ?? 0,
      wrongCount: (json['wrong_count'] as num?)?.toInt() ?? 0,
      unansweredCount: (json['unanswered_count'] as num?)?.toInt() ?? 0,
      wrongQuestionIds: _parseWrongQuestionIds(json['wrong_question_ids']),
      lessonNumber: (set?['lesson_number'] as num?)?.toInt() ?? 0,
      sheetNumber: (set?['sheet_number'] as num?)?.toInt() ?? 0,
      licenseCategory: set?['license_category']?.toString() ?? '',
      kind: set?['kind']?.toString() ?? '',
      startedAt: _parseTs(json['started_at']),
      completedAt: _parseTs(json['completed_at']),
      createdAt: _parseTs(json['created_at']),
      durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
    );
  }
}

Map<String, dynamic>? _nestedQuizSet(Object? raw) {
  if (raw is Map) return Map<String, dynamic>.from(raw);
  if (raw is List && raw.isNotEmpty && raw.first is Map) {
    return Map<String, dynamic>.from(raw.first as Map);
  }
  return null;
}

List<String> _parseWrongQuestionIds(Object? raw) {
  if (raw is! List) return const [];
  return raw.map((e) => e.toString()).where((id) => id.isNotEmpty).toList();
}

DateTime? _parseTs(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
