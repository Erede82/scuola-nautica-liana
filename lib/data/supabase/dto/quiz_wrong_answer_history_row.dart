import 'question_row.dart';
import 'quiz_result_row.dart';

/// Riga storico risposta errata con join `questions` e metadati scheda lezione.
class QuizWrongAnswerHistoryRow {
  const QuizWrongAnswerHistoryRow({
    required this.id,
    required this.quizResultId,
    required this.userId,
    required this.questionId,
    required this.selectedOption,
    required this.correctOption,
    required this.isCorrect,
    required this.answeredAt,
    required this.quizSetId,
    required this.completedAt,
    required this.resultCreatedAt,
    required this.kind,
    required this.licenseCategory,
    required this.lessonNumber,
    required this.sheetNumber,
    this.sheetTitle,
    required this.prompt,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.questionCorrectOption,
    this.explanation,
    this.imagePath,
    required this.questionLessonNumber,
    required this.questionLicenseCategory,
    this.examTopicCode,
    this.sourceTopicText,
  });

  final String id;
  final String quizResultId;
  final String userId;
  final String questionId;
  final String? selectedOption;
  final String? correctOption;
  final bool isCorrect;
  final DateTime? answeredAt;

  final String quizSetId;
  final DateTime? completedAt;
  final DateTime? resultCreatedAt;

  final String kind;
  final String licenseCategory;
  final int lessonNumber;
  final int sheetNumber;
  final String? sheetTitle;

  final String prompt;
  final String optionA;
  final String optionB;
  final String optionC;
  final String questionCorrectOption;
  final String? explanation;
  final String? imagePath;
  final int questionLessonNumber;
  final String questionLicenseCategory;
  final String? examTopicCode;
  final String? sourceTopicText;

  /// Parse risposta + domanda; metadati scheda da [result] già filtrato lesson/categoria.
  factory QuizWrongAnswerHistoryRow.fromAnswerJson(
    Map<String, dynamic> json, {
    required QuizResultRow result,
  }) {
    final question = _nestedQuestion(json['questions']);

    return QuizWrongAnswerHistoryRow(
      id: json['id']?.toString() ?? '',
      quizResultId: json['quiz_result_id']?.toString() ?? result.id,
      userId: json['user_id']?.toString() ?? '',
      questionId: json['question_id']?.toString() ?? '',
      selectedOption: json['selected_option']?.toString(),
      correctOption: json['correct_option']?.toString(),
      isCorrect: json['is_correct'] as bool? ?? false,
      answeredAt: _parseTs(json['answered_at']),
      quizSetId: result.quizSetId,
      completedAt: result.completedAt,
      resultCreatedAt: result.createdAt,
      kind: result.kind,
      licenseCategory: result.licenseCategory,
      lessonNumber: result.lessonNumber,
      sheetNumber: result.sheetNumber,
      sheetTitle: null,
      prompt: question?['prompt']?.toString() ?? '',
      optionA: question?['option_a']?.toString() ?? '',
      optionB: question?['option_b']?.toString() ?? '',
      optionC: question?['option_c']?.toString() ?? '',
      questionCorrectOption: question?['correct_option']?.toString() ?? '',
      explanation: question?['explanation']?.toString(),
      imagePath: question?['image_path']?.toString(),
      questionLessonNumber: (question?['lesson_number'] as num?)?.toInt() ?? 0,
      questionLicenseCategory: question?['license_category']?.toString() ?? '',
      examTopicCode: question?['exam_topic_code']?.toString(),
      sourceTopicText: question?['source_topic_text']?.toString(),
    );
  }

  /// Costruzione diretta per test/in-memory.
  factory QuizWrongAnswerHistoryRow.fromParts({
    required String id,
    required String quizResultId,
    required String userId,
    required String questionId,
    required String selectedOption,
    required String correctOption,
    required DateTime answeredAt,
    required QuizResultRow result,
    required QuestionRow question,
  }) {
    return QuizWrongAnswerHistoryRow(
      id: id,
      quizResultId: quizResultId,
      userId: userId,
      questionId: questionId,
      selectedOption: selectedOption,
      correctOption: correctOption,
      isCorrect: false,
      answeredAt: answeredAt,
      quizSetId: result.quizSetId,
      completedAt: result.completedAt,
      resultCreatedAt: result.createdAt,
      kind: result.kind,
      licenseCategory: result.licenseCategory,
      lessonNumber: result.lessonNumber,
      sheetNumber: result.sheetNumber,
      prompt: question.prompt,
      optionA: question.optionA,
      optionB: question.optionB,
      optionC: question.optionC,
      questionCorrectOption: question.correctOption,
      explanation: question.explanation,
      imagePath: question.imagePath,
      questionLessonNumber: question.lessonNumber,
      questionLicenseCategory: question.licenseCategory,
      examTopicCode: question.examTopicCode,
      sourceTopicText: question.sourceTopicText,
    );
  }
}

Map<String, dynamic>? _nestedQuestion(Object? raw) {
  if (raw is Map) return Map<String, dynamic>.from(raw);
  if (raw is List && raw.isNotEmpty && raw.first is Map) {
    return Map<String, dynamic>.from(raw.first as Map);
  }
  return null;
}

DateTime? _parseTs(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
