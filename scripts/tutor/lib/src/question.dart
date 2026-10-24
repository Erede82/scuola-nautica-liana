/// PostgreSQL `btrim` default: strip only U+0020 from both ends.
String pgBtrim(String? value) {
  if (value == null || value.isEmpty) return '';
  var start = 0;
  var end = value.length;
  while (start < end && value.codeUnitAt(start) == 0x20) {
    start++;
  }
  while (end > start && value.codeUnitAt(end - 1) == 0x20) {
    end--;
  }
  return value.substring(start, end);
}

/// Authoritative question fields used to build a Tutor explanation.
class TutorQuestion {
  const TutorQuestion({
    required this.id,
    required this.licenseCategory,
    required this.lessonNumber,
    required this.examTopicCode,
    required this.sourceTopicText,
    required this.prompt,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.correctOption,
    required this.officialExplanation,
    required this.imagePath,
  });

  final String id;
  final String licenseCategory;
  final int? lessonNumber;
  final String? examTopicCode;
  final String? sourceTopicText;
  final String prompt;
  final String optionA;
  final String optionB;
  final String optionC;
  final String correctOption;
  final String? officialExplanation;
  final String? imagePath;

  String get topicCode => pgBtrim(examTopicCode);

  int get promptLength => pgBtrim(prompt).length;

  bool get hasImage => pgBtrim(imagePath).isNotEmpty;

  String? get trimmedImagePath {
    final path = pgBtrim(imagePath);
    return path.isEmpty ? null : path;
  }

  /// Official answer text. The model is never asked to choose it.
  String get correctAnswerText {
    switch (pgBtrim(correctOption).toUpperCase()) {
      case 'A':
        return optionA;
      case 'B':
        return optionB;
      case 'C':
        return optionC;
      default:
        throw FormatException(
          'correct_option must be A, B, or C for question $id',
        );
    }
  }

  factory TutorQuestion.fromJson(Map<String, Object?> json) {
    return TutorQuestion(
      id: json['id']?.toString() ?? '',
      licenseCategory: json['license_category']?.toString() ?? '',
      lessonNumber: _asInt(json['lesson_number']),
      examTopicCode: json['exam_topic_code']?.toString(),
      sourceTopicText: json['source_topic_text']?.toString(),
      prompt: json['prompt']?.toString() ?? '',
      optionA: json['option_a']?.toString() ?? '',
      optionB: json['option_b']?.toString() ?? '',
      optionC: json['option_c']?.toString() ?? '',
      correctOption: json['correct_option']?.toString() ?? '',
      officialExplanation: json['explanation']?.toString(),
      imagePath: json['image_path']?.toString(),
    );
  }
}

int? _asInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}
