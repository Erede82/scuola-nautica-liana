/// Riga tabella `questions` (legacy app).
class QuestionRow {
  const QuestionRow({
    required this.id,
    required this.prompt,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.correctOption,
    required this.lessonNumber,
    required this.licenseCategory,
    this.examTopicCode,
    this.sourceTopicText,
    this.imagePath,
    this.explanation,
  });

  final String id;
  final String prompt;
  final String optionA;
  final String optionB;
  final String optionC;
  final String correctOption;
  final int lessonNumber;
  final String licenseCategory;
  final String? examTopicCode;
  final String? sourceTopicText;
  final String? imagePath;
  final String? explanation;

  factory QuestionRow.fromJson(Map<String, dynamic> j) {
    return QuestionRow(
      id: j['id']?.toString() ?? '',
      prompt: (j['prompt'] as String?) ?? '',
      optionA: (j['option_a'] as String?) ?? '',
      optionB: (j['option_b'] as String?) ?? '',
      optionC: (j['option_c'] as String?) ?? '',
      correctOption: (j['correct_option'] as String?) ?? '',
      lessonNumber: (j['lesson_number'] as num?)?.toInt() ?? 0,
      licenseCategory: (j['license_category'] as String?) ?? '',
      examTopicCode: j['exam_topic_code'] as String?,
      sourceTopicText: j['source_topic_text'] as String?,
      imagePath: j['image_path'] as String?,
      explanation: j['explanation'] as String?,
    );
  }
}
