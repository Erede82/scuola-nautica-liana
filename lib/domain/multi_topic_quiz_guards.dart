/// Gate chiusura scheda Multischeda: evita doppia costruzione submission.
bool multiTopicCloseSheetMayProceed({
  required bool showSummary,
  required bool submitInFlight,
  required bool hasPendingSubmission,
  bool closeInProgress = false,
}) {
  return !showSummary &&
      !submitInFlight &&
      !hasPendingSubmission &&
      !closeInProgress;
}

/// True se uscita/back devono essere bloccati durante salvataggio RPC.
bool multiTopicBlocksExitWhileSaving({required bool isSaving}) => isSaving;

/// Gate start sessione: evita doppio push / doppio sessionId.
bool multiTopicStartSessionMayProceed({
  required bool starting,
  required bool startEnabled,
}) {
  return !starting && startEnabled;
}

/// Congela o riusa la submission immutabile (mai ricostruire se già presente).
T freezeOrReusePendingSubmission<T>({
  required T? pending,
  required T Function() build,
}) {
  if (pending != null) return pending;
  return build();
}
