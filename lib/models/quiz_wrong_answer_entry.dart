import '../models/license_models.dart';
import '../models/quiz_question.dart';

/// Voce dominio: domanda con almeno un errore storico su schede lezione.
class QuizWrongAnswerEntry {
  const QuizWrongAnswerEntry({
    required this.questionId,
    required this.prompt,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.latestSelectedOption,
    required this.correctOption,
    this.explanation,
    this.imagePath,
    required this.lessonNumber,
    required this.sheetNumbers,
    required this.licenseCategoryId,
    this.examTopicCode,
    this.sourceTopicText,
    required this.errorCount,
    required this.firstWrongAt,
    required this.lastWrongAt,
  });

  final String questionId;
  final String prompt;
  final String optionA;
  final String optionB;
  final String optionC;
  final QuizAnswerOption latestSelectedOption;
  final QuizAnswerOption correctOption;
  final String? explanation;
  final String? imagePath;
  final int lessonNumber;
  final List<int> sheetNumbers;
  final LicenseCategoryId licenseCategoryId;
  final String? examTopicCode;
  final String? sourceTopicText;
  final int errorCount;
  final DateTime firstWrongAt;
  final DateTime lastWrongAt;

  int get latestSheetNumber =>
      sheetNumbers.isEmpty ? 0 : sheetNumbers.reduce((a, b) => a > b ? a : b);

  String get selectedAnswerText => _textFor(latestSelectedOption);

  String get correctAnswerText => _textFor(correctOption);

  bool get hasExplanation =>
      explanation != null && explanation!.trim().isNotEmpty;

  bool get hasImage => imagePath != null && imagePath!.trim().isNotEmpty;

  bool get isValid =>
      questionId.isNotEmpty &&
      prompt.trim().isNotEmpty &&
      errorCount > 0 &&
      lessonNumber >= 1 &&
      lessonNumber <= 14;

  String? lessonTitleFor(LicenseCategoryId categoryId) {
    // Risoluzione titolo delegata al mapper/catalogo in fase UI; qui solo helper.
    return null;
  }

  String _textFor(QuizAnswerOption option) {
    switch (option) {
      case QuizAnswerOption.a:
        return optionA;
      case QuizAnswerOption.b:
        return optionB;
      case QuizAnswerOption.c:
        return optionC;
    }
  }
}
