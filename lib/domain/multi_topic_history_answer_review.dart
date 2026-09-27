import '../models/quiz_question.dart';

/// Esito review storico Multischeda (presentazione; i conteggi restano server-side).
enum MultiTopicHistoryAnswerReviewStatus { correct, wrong, unanswered }

/// Deriva lo stato UI da snapshot storico.
///
/// `selectedOption == null` → non risposta (mai «errata»).
MultiTopicHistoryAnswerReviewStatus multiTopicHistoryAnswerReviewStatus({
  required QuizAnswerOption? selectedOption,
  required bool isCorrect,
}) {
  if (selectedOption == null) {
    return MultiTopicHistoryAnswerReviewStatus.unanswered;
  }
  return isCorrect
      ? MultiTopicHistoryAnswerReviewStatus.correct
      : MultiTopicHistoryAnswerReviewStatus.wrong;
}

String multiTopicHistoryAnswerReviewLabel(
  MultiTopicHistoryAnswerReviewStatus status,
) {
  switch (status) {
    case MultiTopicHistoryAnswerReviewStatus.correct:
      return 'Risposta corretta';
    case MultiTopicHistoryAnswerReviewStatus.wrong:
      return 'Risposta errata';
    case MultiTopicHistoryAnswerReviewStatus.unanswered:
      return 'Non risposta';
  }
}
