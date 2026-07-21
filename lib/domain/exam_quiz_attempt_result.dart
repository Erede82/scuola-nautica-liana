import '../models/license_models.dart';
import '../models/quiz_question.dart';
import 'exam_quiz_rules.dart';

/// Contratto **persistito / read-only** di un tentativo esame concluso, così
/// come verrà restituito dalla futura RPC / repository.
///
/// A differenza di [ExamQuizAttemptSubmission] contiene i dati calcolati dal
/// server (conteggi, esito) e lo snapshot delle domande, sufficiente a
/// ricostruire la pagina di review senza dipendere dallo stato corrente della
/// tabella `questions`.
class ExamQuizAttemptResult {
  const ExamQuizAttemptResult({
    required this.id,
    required this.licenseCategory,
    required this.completedAt,
    required this.duration,
    required this.timeExpired,
    required this.totalQuestions,
    required this.correctCount,
    required this.wrongCount,
    required this.unansweredCount,
    required this.outcome,
    required this.answers,
  });

  final String id;
  final LicenseCategoryId licenseCategory;
  final DateTime completedAt;
  final Duration duration;
  final bool timeExpired;
  final int totalQuestions;
  final int correctCount;
  final int wrongCount;
  final int unansweredCount;
  final ExamQuizOutcome outcome;

  /// Snapshot ordinato per posizione (1..N).
  final List<ExamQuizAttemptAnswerSnapshot> answers;

  bool get passed => outcome == ExamQuizOutcome.passed;

  /// Errori ai fini del superamento: risposte sbagliate + non risposte.
  int get errorCount => wrongCount + unansweredCount;

  @override
  bool operator ==(Object other) =>
      other is ExamQuizAttemptResult &&
      other.id == id &&
      other.licenseCategory == licenseCategory &&
      other.completedAt == completedAt &&
      other.duration == duration &&
      other.timeExpired == timeExpired &&
      other.totalQuestions == totalQuestions &&
      other.correctCount == correctCount &&
      other.wrongCount == wrongCount &&
      other.unansweredCount == unansweredCount &&
      other.outcome == outcome &&
      _snapshotsEqual(other.answers, answers);

  @override
  int get hashCode => Object.hash(
    id,
    licenseCategory,
    completedAt,
    duration,
    timeExpired,
    totalQuestions,
    correctCount,
    wrongCount,
    unansweredCount,
    outcome,
    Object.hashAll(answers),
  );
}

/// Snapshot storico di una singola domanda del tentativo.
///
/// Include il testo della domanda, i testi delle opzioni, l'immagine (quando
/// usata), la risposta scelta e quella corretta: dati sufficienti a ricostruire
/// [QuizExamErrorReviewPage] senza rileggere `questions`.
class ExamQuizAttemptAnswerSnapshot {
  const ExamQuizAttemptAnswerSnapshot({
    required this.position,
    required this.questionId,
    required this.prompt,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.selectedOption,
    required this.correctOption,
    required this.isCorrect,
    this.imagePath,
  });

  /// Posizione 1-based nella simulazione.
  final int position;
  final String questionId;
  final String prompt;
  final String optionA;
  final String optionB;
  final String optionC;

  /// `null` = domanda non risposta.
  final QuizAnswerOption? selectedOption;
  final QuizAnswerOption correctOption;
  final bool isCorrect;
  final String? imagePath;

  bool get isUnanswered => selectedOption == null;

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

  @override
  bool operator ==(Object other) =>
      other is ExamQuizAttemptAnswerSnapshot &&
      other.position == position &&
      other.questionId == questionId &&
      other.prompt == prompt &&
      other.optionA == optionA &&
      other.optionB == optionB &&
      other.optionC == optionC &&
      other.selectedOption == selectedOption &&
      other.correctOption == correctOption &&
      other.isCorrect == isCorrect &&
      other.imagePath == imagePath;

  @override
  int get hashCode => Object.hash(
    position,
    questionId,
    prompt,
    optionA,
    optionB,
    optionC,
    selectedOption,
    correctOption,
    isCorrect,
    imagePath,
  );
}

/// Adapter puro: traduce le risposte del player nel formato richiesto da
/// [buildExamQuizSummary], senza duplicarne soglia/esito/conteggi.
ExamQuizSummary examQuizSummaryFromAnswers({
  required List<QuizQuestion> questions,
  required List<QuizAnswerOption?> userAnswers,
}) {
  if (questions.length != userAnswers.length) {
    throw ArgumentError(
      'Risposte (${userAnswers.length}) non allineate alle domande '
      '(${questions.length}).',
    );
  }

  var correctCount = 0;
  var wrongCount = 0;
  var unansweredCount = 0;
  for (var i = 0; i < questions.length; i++) {
    final answer = userAnswers[i];
    if (answer == null) {
      unansweredCount++;
    } else if (answer == questions[i].correctOption) {
      correctCount++;
    } else {
      wrongCount++;
    }
  }

  return buildExamQuizSummary(
    totalQuestions: questions.length,
    correctCount: correctCount,
    wrongCount: wrongCount,
    unansweredCount: unansweredCount,
  );
}

/// Costruisce gli snapshot storici delle risposte (ordine per posizione).
List<ExamQuizAttemptAnswerSnapshot> buildExamQuizAttemptAnswerSnapshots({
  required List<QuizQuestion> questions,
  required List<QuizAnswerOption?> userAnswers,
}) {
  if (questions.length != userAnswers.length) {
    throw ArgumentError(
      'Risposte (${userAnswers.length}) non allineate alle domande '
      '(${questions.length}).',
    );
  }

  final rows = <ExamQuizAttemptAnswerSnapshot>[];
  for (var i = 0; i < questions.length; i++) {
    final question = questions[i];
    final answer = userAnswers[i];
    rows.add(
      ExamQuizAttemptAnswerSnapshot(
        position: i + 1,
        questionId: question.id,
        prompt: question.prompt,
        optionA: question.optionA,
        optionB: question.optionB,
        optionC: question.optionC,
        selectedOption: answer,
        correctOption: question.correctOption,
        isCorrect: answer != null && answer == question.correctOption,
        imagePath: question.imagePath,
      ),
    );
  }
  return List.unmodifiable(rows);
}

bool _snapshotsEqual(
  List<ExamQuizAttemptAnswerSnapshot> a,
  List<ExamQuizAttemptAnswerSnapshot> b,
) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
