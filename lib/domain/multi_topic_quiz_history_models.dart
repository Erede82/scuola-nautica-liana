import '../models/license_models.dart';
import '../models/quiz_question.dart';

/// Riepilogo storico Multischeda (lista, senza snapshot risposte).
class MultiTopicQuizAttemptSummary {
  const MultiTopicQuizAttemptSummary({
    required this.id,
    required this.sessionId,
    required this.licenseCategory,
    required this.lessonNumbers,
    required this.sheetIndex,
    required this.totalSheets,
    required this.completedAt,
    required this.durationSeconds,
    required this.totalQuestions,
    required this.correctCount,
    required this.wrongCount,
    required this.unansweredCount,
  });

  final String id;
  final String sessionId;
  final LicenseCategoryId licenseCategory;
  final List<int> lessonNumbers;
  final int sheetIndex;
  final int totalSheets;
  final DateTime completedAt;
  final int durationSeconds;
  final int totalQuestions;
  final int correctCount;
  final int wrongCount;
  final int unansweredCount;

  String get progressLabel => 'Scheda $sheetIndex di $totalSheets';

  @override
  bool operator ==(Object other) =>
      other is MultiTopicQuizAttemptSummary &&
      other.id == id &&
      other.sessionId == sessionId &&
      other.licenseCategory == licenseCategory &&
      _intsEqual(other.lessonNumbers, lessonNumbers) &&
      other.sheetIndex == sheetIndex &&
      other.totalSheets == totalSheets &&
      other.completedAt == completedAt &&
      other.durationSeconds == durationSeconds &&
      other.totalQuestions == totalQuestions &&
      other.correctCount == correctCount &&
      other.wrongCount == wrongCount &&
      other.unansweredCount == unansweredCount;

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    licenseCategory,
    Object.hashAll(lessonNumbers),
    sheetIndex,
    totalSheets,
    completedAt,
    durationSeconds,
    totalQuestions,
    correctCount,
    wrongCount,
    unansweredCount,
  );
}

/// Snapshot risposta storico (da `multi_topic_quiz_attempt_answers`).
class MultiTopicQuizAttemptAnswerSnapshot {
  const MultiTopicQuizAttemptAnswerSnapshot({
    required this.position,
    required this.questionId,
    required this.prompt,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.selectedOption,
    required this.correctOption,
    required this.isCorrect,
    required this.lessonNumber,
    this.imagePath,
    this.explanation,
  });

  final int position;
  final String questionId;
  final String prompt;
  final String optionA;
  final String optionB;
  final String optionC;
  final QuizAnswerOption? selectedOption;
  final QuizAnswerOption correctOption;
  final bool isCorrect;
  final int lessonNumber;
  final String? imagePath;
  final String? explanation;
}

/// Dettaglio storico completo (header + snapshot).
class MultiTopicQuizAttemptDetail {
  const MultiTopicQuizAttemptDetail({
    required this.summary,
    required this.answers,
  });

  final MultiTopicQuizAttemptSummary summary;
  final List<MultiTopicQuizAttemptAnswerSnapshot> answers;
}

bool _intsEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
