import '../models/license_models.dart';
import '../models/quiz_question.dart';
import 'lesson_quiz_rules.dart';
import 'quiz_license_category.dart';

/// Submission immutabile Multischeda (congelata prima della prima RPC).
class MultiTopicQuizAttemptSubmission {
  const MultiTopicQuizAttemptSubmission({
    required this.clientSubmissionId,
    required this.sessionId,
    required this.licenseCategory,
    required this.lessonNumbers,
    required this.sheetIndex,
    required this.totalSheets,
    required this.startedAt,
    required this.durationSeconds,
    required this.answers,
  });

  final String clientSubmissionId;
  final String sessionId;
  final LicenseCategoryId licenseCategory;
  final List<int> lessonNumbers;
  final int sheetIndex;
  final int totalSheets;
  final DateTime startedAt;
  final int durationSeconds;
  final List<MultiTopicQuizSubmissionAnswer> answers;

  Map<String, dynamic> toRpcParams() {
    final sortedLessons = List<int>.from(lessonNumbers)..sort();
    return {
      'p_client_submission_id': clientSubmissionId,
      'p_session_id': sessionId,
      'p_license_category': dbLicenseCategoryFor(licenseCategory),
      'p_lesson_numbers': sortedLessons,
      'p_sheet_index': sheetIndex,
      'p_total_sheets': totalSheets,
      'p_started_at': startedAt.toUtc().toIso8601String(),
      'p_duration_seconds': durationSeconds,
      'p_answers': answers.map((a) => a.toJson()).toList(growable: false),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is MultiTopicQuizAttemptSubmission &&
      other.clientSubmissionId == clientSubmissionId &&
      other.sessionId == sessionId &&
      other.licenseCategory == licenseCategory &&
      _intsEqual(other.lessonNumbers, lessonNumbers) &&
      other.sheetIndex == sheetIndex &&
      other.totalSheets == totalSheets &&
      other.startedAt == startedAt &&
      other.durationSeconds == durationSeconds &&
      _answersEqual(other.answers, answers);

  @override
  int get hashCode => Object.hash(
    clientSubmissionId,
    sessionId,
    licenseCategory,
    Object.hashAll(lessonNumbers),
    sheetIndex,
    totalSheets,
    startedAt,
    durationSeconds,
    Object.hashAll(answers),
  );
}

class MultiTopicQuizSubmissionAnswer {
  const MultiTopicQuizSubmissionAnswer({
    required this.position,
    required this.questionId,
    required this.selectedOption,
  });

  final int position;
  final String questionId;
  final QuizAnswerOption? selectedOption;

  Map<String, dynamic> toJson() => {
    'position': position,
    'question_id': questionId,
    'selected_option': selectedOption?.letter,
  };

  @override
  bool operator ==(Object other) =>
      other is MultiTopicQuizSubmissionAnswer &&
      other.position == position &&
      other.questionId == questionId &&
      other.selectedOption == selectedOption;

  @override
  int get hashCode => Object.hash(position, questionId, selectedOption);
}

/// Costruisce la submission immutabile. Non genera UUID né ricalcola dopo.
MultiTopicQuizAttemptSubmission buildMultiTopicQuizAttemptSubmission({
  required String clientSubmissionId,
  required String sessionId,
  required LicenseCategoryId licenseCategory,
  required List<int> lessonNumbers,
  required int sheetIndex,
  required int totalSheets,
  required DateTime startedAt,
  required DateTime completedAt,
  required List<QuizQuestion> questions,
  required List<QuizAnswerOption?> userAnswers,
}) {
  if (clientSubmissionId.trim().isEmpty) {
    throw ArgumentError.value(
      clientSubmissionId,
      'clientSubmissionId',
      'client_submission_id obbligatorio.',
    );
  }
  if (sessionId.trim().isEmpty) {
    throw ArgumentError.value(
      sessionId,
      'sessionId',
      'session_id obbligatorio.',
    );
  }
  if (lessonNumbers.length < 2) {
    throw ArgumentError.value(
      lessonNumbers,
      'lessonNumbers',
      'Servono almeno 2 argomenti.',
    );
  }
  if (sheetIndex < 1 || totalSheets < sheetIndex) {
    throw ArgumentError(
      'sheetIndex ($sheetIndex) / totalSheets ($totalSheets) non validi.',
    );
  }
  final rules = lessonQuizRulesForCategory(licenseCategory);
  if (rules == null) {
    throw ArgumentError.value(
      licenseCategory,
      'licenseCategory',
      'Categoria Multischeda non supportata.',
    );
  }
  if (questions.length != rules.questionsPerSheet) {
    throw ArgumentError.value(
      questions.length,
      'questions',
      'La scheda richiede esattamente ${rules.questionsPerSheet} domande.',
    );
  }
  if (userAnswers.length != questions.length) {
    throw ArgumentError(
      'Risposte (${userAnswers.length}) non allineate alle domande '
      '(${questions.length}).',
    );
  }

  final durationSeconds = completedAt.difference(startedAt).inSeconds;
  if (durationSeconds < 0) {
    throw ArgumentError.value(
      durationSeconds,
      'durationSeconds',
      'Durata non può essere negativa.',
    );
  }

  final seenIds = <String>{};
  final rows = <MultiTopicQuizSubmissionAnswer>[];
  for (var i = 0; i < questions.length; i++) {
    final question = questions[i];
    if (question.id.trim().isEmpty) {
      throw ArgumentError('Domanda in posizione ${i + 1} senza id.');
    }
    if (!seenIds.add(question.id)) {
      throw ArgumentError('Domanda duplicata nella scheda: ${question.id}.');
    }
    rows.add(
      MultiTopicQuizSubmissionAnswer(
        position: i + 1,
        questionId: question.id,
        selectedOption: userAnswers[i],
      ),
    );
  }

  final sortedLessons = List<int>.from(lessonNumbers)..sort();
  return MultiTopicQuizAttemptSubmission(
    clientSubmissionId: clientSubmissionId,
    sessionId: sessionId,
    licenseCategory: licenseCategory,
    lessonNumbers: List.unmodifiable(sortedLessons),
    sheetIndex: sheetIndex,
    totalSheets: totalSheets,
    startedAt: startedAt.toUtc(),
    durationSeconds: durationSeconds,
    answers: List.unmodifiable(rows),
  );
}

bool _intsEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _answersEqual(
  List<MultiTopicQuizSubmissionAnswer> a,
  List<MultiTopicQuizSubmissionAnswer> b,
) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
