/// Opzione di risposta quiz (allineata a `questions.correct_option` A/B/C).
enum QuizAnswerOption { a, b, c }

extension QuizAnswerOptionX on QuizAnswerOption {
  String get letter {
    switch (this) {
      case QuizAnswerOption.a:
        return 'A';
      case QuizAnswerOption.b:
        return 'B';
      case QuizAnswerOption.c:
        return 'C';
    }
  }

  static QuizAnswerOption? tryParse(String? raw) {
    if (raw == null) return null;
    switch (raw.trim().toUpperCase()) {
      case 'A':
        return QuizAnswerOption.a;
      case 'B':
        return QuizAnswerOption.b;
      case 'C':
        return QuizAnswerOption.c;
      default:
        return null;
    }
  }
}

/// Domanda quiz per area studente (DTO da tabella `questions`).
class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.prompt,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.correctOption,
    this.imagePath,
    this.explanation,
    required this.lessonNumber,
    required this.licenseCategory,
  });

  final String id;
  final String prompt;
  final String optionA;
  final String optionB;
  final String optionC;
  final QuizAnswerOption correctOption;
  final String? imagePath;
  final String? explanation;
  final int lessonNumber;

  /// Valore DB (`A12`, `D1`, …).
  final String licenseCategory;

  String textForOption(QuizAnswerOption option) {
    switch (option) {
      case QuizAnswerOption.a:
        return optionA;
      case QuizAnswerOption.b:
        return optionB;
      case QuizAnswerOption.c:
        return optionC;
    }
  }

  List<QuizAnswerOption> get options => const [
    QuizAnswerOption.a,
    QuizAnswerOption.b,
    QuizAnswerOption.c,
  ];
}
