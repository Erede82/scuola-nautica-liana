import '../models/quiz_question.dart';

/// Voce review locale post-simulazione esame (nessun salvataggio DB).
class ExamErrorReviewEntry {
  const ExamErrorReviewEntry({
    required this.questionNumber,
    required this.question,
    required this.userAnswer,
  });

  final int questionNumber;
  final QuizQuestion question;

  /// `null` se la domanda non è stata risposta.
  final QuizAnswerOption? userAnswer;

  bool get isUnanswered => userAnswer == null;
}

/// Domande errate o non risposte da mostrare nella review locale.
List<ExamErrorReviewEntry> buildExamErrorReviewEntries({
  required List<QuizQuestion> questions,
  required List<QuizAnswerOption?> userAnswers,
}) {
  final entries = <ExamErrorReviewEntry>[];
  for (var i = 0; i < questions.length; i++) {
    final question = questions[i];
    final answer = i < userAnswers.length ? userAnswers[i] : null;
    if (answer == null || answer != question.correctOption) {
      entries.add(
        ExamErrorReviewEntry(
          questionNumber: i + 1,
          question: question,
          userAnswer: answer,
        ),
      );
    }
  }
  return entries;
}

String formatExamReviewUserAnswer(QuizAnswerOption? answer) {
  if (answer == null) return 'Non risposta';
  return '${answer.letter} — opzione ${answer.index + 1}';
}

String formatExamReviewCorrectAnswer(QuizAnswerOption answer) {
  return '${answer.letter} — opzione ${answer.index + 1}';
}
