/// Stato completamento schede lezione da `quiz_results` (read-only).
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

/// Sheet numbers con almeno un [quiz_results] per il set corrispondente.
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
