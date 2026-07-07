/// Conferma uscita solo se l'allievo ha già risposto ad almeno una domanda.
bool shouldConfirmExitBeforeSummary(List<Object?> answers) =>
    answers.any((answer) => answer != null);
