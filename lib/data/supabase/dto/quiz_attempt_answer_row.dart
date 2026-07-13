/// Riga `quiz_attempt_answers` (lettura read-only per validazione tentativi).
class QuizAttemptAnswerRow {
  const QuizAttemptAnswerRow({
    required this.id,
    required this.quizResultId,
    required this.questionId,
    required this.isCorrect,
    this.selectedOption,
    this.correctOption,
    this.answeredAt,
  });

  final String id;
  final String quizResultId;
  final String questionId;
  final bool isCorrect;
  final String? selectedOption;
  final String? correctOption;
  final DateTime? answeredAt;

  factory QuizAttemptAnswerRow.fromJson(Map<String, dynamic> json) {
    return QuizAttemptAnswerRow(
      id: json['id']?.toString() ?? '',
      quizResultId: json['quiz_result_id']?.toString() ?? '',
      questionId: json['question_id']?.toString() ?? '',
      isCorrect: json['is_correct'] as bool? ?? false,
      selectedOption: json['selected_option']?.toString(),
      correctOption: json['correct_option']?.toString(),
      answeredAt: _parseTs(json['answered_at']),
    );
  }
}

DateTime? _parseTs(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
