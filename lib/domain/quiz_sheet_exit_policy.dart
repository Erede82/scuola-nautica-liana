// Policy uscita / conclusione scheda Studio (Schede + Multischeda).
//
// Regole:
// - 0 risposte → uscita immediata senza salvataggio; conclusione vietata.
// - ≥1 risposta → conclusione/salvataggio consentiti; all'uscita si conclude
//   (con conferma se restano non risposte, conteggiate come errori).

/// True se l'allievo ha dato almeno una risposta.
bool quizSheetHasAnyAnswer(List<Object?> answers) =>
    answers.any((answer) => answer != null);

/// Conta le risposte non nulle.
int quizSheetAnsweredCount(List<Object?> answers) =>
    answers.where((answer) => answer != null).length;

/// Attempt persistibile solo con ≥1 risposta (scheda vuota = mai salvare).
bool quizSheetMayPersistAttempt(List<Object?> answers) =>
    quizSheetHasAnyAnswer(answers);

/// Conferma richiesta prima di concludere/uscire se c'è almeno una risposta.
bool shouldConfirmExitBeforeSummary(List<Object?> answers) =>
    quizSheetHasAnyAnswer(answers);

/// Uscita immediata (PopScope.canPop) senza dialog: solo scheda vuota.
bool allowsImmediateQuizSheetExit(List<Object?> answers) =>
    !quizSheetHasAnyAnswer(answers);

/// Gate chiusura scheda normale: evita doppio ingresso in `_closeSheet`.
///
/// Allineato alla filosofia Multischeda (`multiTopicCloseSheetMayProceed`):
/// claim sincrono prima di qualsiasi await; blocco se summary già mostrato,
/// close già in corso, salvataggio in corso, o attempt già salvato.
bool quizSheetCloseMayProceed({
  required bool showSummary,
  required bool closeInProgress,
  required bool isSaving,
  required bool isSaved,
}) {
  return !showSummary && !closeInProgress && !isSaving && !isSaved;
}

/// Gate persistenza: impossibile iniziare una seconda save mentre è in corso.
bool quizSheetSaveMayProceed({required bool isSaving, required bool isSaved}) {
  return !isSaving && !isSaved;
}
