/// Stato completamento schede lezione da `quiz_results` + `quiz_attempt_answers`.
class LessonSheetCompletionSnapshot {
  const LessonSheetCompletionSnapshot({
    required this.quizSetIdBySheet,
    required this.completedSheetNumbers,
  });

  final Map<int, String> quizSetIdBySheet;
  final Set<int> completedSheetNumbers;

  bool isSheetCompleted(int sheetNumber) =>
      completedSheetNumbers.contains(sheetNumber);

  static const empty = LessonSheetCompletionSnapshot(
    quizSetIdBySheet: {},
    completedSheetNumbers: {},
  );
}

/// Riga minima di `quiz_results` per valutare completamento scheda.
class LessonQuizResultAttempt {
  const LessonQuizResultAttempt({
    required this.id,
    required this.quizSetId,
    required this.totalQuestions,
  });

  final String id;
  final String quizSetId;
  final int totalQuestions;
}

/// Tentativo completo: risposte salvate == domande totali (> 0).
bool isLessonQuizResultComplete({
  required int answerCount,
  required int totalQuestions,
}) => totalQuestions > 0 && answerCount == totalQuestions;

/// `quiz_set_id` con almeno un tentativo completo e coerente.
Set<String> completedQuizSetIdsFromAttempts({
  required Iterable<LessonQuizResultAttempt> results,
  required Map<String, int> answerCountByResultId,
}) {
  final completed = <String>{};
  for (final result in results) {
    if (isLessonQuizResultComplete(
      answerCount: answerCountByResultId[result.id] ?? 0,
      totalQuestions: result.totalQuestions,
    )) {
      completed.add(result.quizSetId);
    }
  }
  return completed;
}

/// Sheet numbers con almeno un tentativo completo per il set corrispondente.
Set<int> completedSheetNumbers({
  required Map<int, String> quizSetIdBySheet,
  required Set<String> completedQuizSetIds,
}) {
  return quizSetIdBySheet.entries
      .where((entry) => completedQuizSetIds.contains(entry.value))
      .map((entry) => entry.key)
      .toSet();
}

/// Costruisce snapshot da mappe quiz_set e risultati salvati.
LessonSheetCompletionSnapshot buildLessonSheetCompletionSnapshot({
  required Map<int, String> quizSetIdBySheet,
  required Set<String> completedQuizSetIds,
}) {
  return LessonSheetCompletionSnapshot(
    quizSetIdBySheet: quizSetIdBySheet,
    completedSheetNumbers: completedSheetNumbers(
      quizSetIdBySheet: quizSetIdBySheet,
      completedQuizSetIds: completedQuizSetIds,
    ),
  );
}

bool isLessonSheetPlayable({
  required int sheetNumber,
  required LessonSheetCompletionSnapshot completion,
}) => !completion.isSheetCompleted(sheetNumber);
