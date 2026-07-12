/// Navigazione domanda-per-domanda nelle schede quiz (testabile senza UI).
abstract final class QuizSheetPlayerNavigation {
  static bool canGoForward({
    required int currentIndex,
    required int questionCount,
  }) {
    return currentIndex + 1 < questionCount;
  }

  static String primaryButtonLabel({
    required int currentIndex,
    required int questionCount,
  }) {
    return currentIndex + 1 >= questionCount ? 'Chiudi scheda' : 'Avanti';
  }

  static String examPrimaryButtonLabel({
    required int currentIndex,
    required int questionCount,
  }) {
    return currentIndex + 1 >= questionCount ? 'Vedi riepilogo' : 'Avanti';
  }

  static bool isQuestionAnswered(List<Object?> answers, int index) {
    if (index < 0 || index >= answers.length) return false;
    return answers[index] != null;
  }

  static int? firstUnansweredIndex(List<Object?> answers) {
    for (var i = 0; i < answers.length; i++) {
      if (answers[i] == null) return i;
    }
    return null;
  }
}

/// Gate UI quiz esame: anteprima staff bypassa il blocco accessi.
bool isExamQuizUiAccessible({
  required bool isStaffPreview,
  required bool gateLocked,
}) {
  return isStaffPreview || !gateLocked;
}
