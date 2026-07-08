/// Conferma uscita solo se l'allievo ha già risposto ad almeno una domanda.
bool shouldConfirmExitBeforeSummary(List<Object?> answers) =>
    answers.any((answer) => answer != null);

/// Uscita immediata (es. `PopScope.canPop`) senza dialog di conferma.
bool allowsImmediateQuizSheetExit(List<Object?> answers) =>
    !shouldConfirmExitBeforeSummary(answers);
