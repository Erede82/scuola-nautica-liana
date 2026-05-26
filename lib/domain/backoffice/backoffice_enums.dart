/// Enumerazioni condivise tra app studente, backoffice scuola e future tabelle Supabase.
library;

/// Stato operativo onboarding segreteria (tabella `students.onboarding_status`).
///
/// Complementare a [StudentRegistrationStatus]: gestisce il flusso “nuovo iscritto → attivo”.
enum StudentOnboardingStatus {
  /// Iscrizione da app / da gestire in priorità.
  pendingReview,

  /// Da richiamare / contattare.
  awaitingContact,

  /// Mancano documenti o verifiche documentali.
  awaitingDocuments,

  /// Accettato dalla scuola, prima dell’avvio percorso.
  approved,

  /// Percorso formativo avviato (allineato tipicamente a [StudentRegistrationStatus.active]).
  activeCourse,

  /// Sospeso (onboarding / gestione interna).
  suspended,

  /// Percorso chiuso con esito (onboarding).
  completed,
}

/// Stato anagrafica / iscrizione al corso.
enum StudentRegistrationStatus {
  /// In attesa di documenti o conferma segreteria.
  pending,

  /// Corso attivo, accesso app coerente con regole scuola.
  active,

  /// Sospensione temporanea (morosità, assenze, decisione dirigenza).
  suspended,

  /// Percorso completato con esito positivo.
  completed,

  /// Ritiro / annullamento iscrizione.
  withdrawn,
}

/// Ruoli nel sistema interno (JWT claims / `user_roles` in DB).
enum BackofficeRole {
  /// Account solo app mobile (vista studente).

  student,

  /// Segreteria / direzione con accesso anagrafiche e sblocchi.
  schoolAdmin,

  /// Personale operativo (permessi granulari da definire lato policy).
  staff,

  /// Docente — lezioni in aula / guida (estendibile senza rompere gli altri ruoli).
  instructor,
}

/// Lezione assegnata nel percorso (copre “cosa deve fare lo studente” lato scuola).
enum AssignedLessonStatus {
  planned,
  inProgress,
  completed,
  skipped,
}

/// Promemoria lezione / appuntamento (allineabile a notifiche push).
enum AppointmentReminderStatus {
  none,
  scheduled,
  sent,
  acknowledged,
}

/// Esito partecipazione appuntamento (lezione in aula, pratica, ecc.).
enum AppointmentCompletionOutcome {
  pending,
  attended,
  absent,
  rescheduled,
}

/// Tipologia slot calendario / lezione.
enum GuidanceLessonType {
  theory,
  practiceSea,
  practiceSimulator,
  officeMeeting,
  examPrep,
  other,
}

/// Esito prova (teoria / pratica).
enum ExamAttemptResult {
  pending,
  scheduled,
  passed,
  failed,
  exempt,
  noShow,
}

/// Tipologia prova d’esame nel sistema MM/MY Patente.
enum ExamAttemptType {
  theory,
  practical,
}

/// Metodo incasso (fatturazione semplificata).

enum PaymentMethod {
  card,
  sepaBankTransfer,
  cash,
  check,
  other,
}

/// Stato documentale / fascicolo (patentino, certificati, ecc.).
enum LicenseDocumentStatus {
  notStarted,
  collected,
  submittedToAuthority,
  issued,
  revoked,
  expired,
}

/// Stato pratica presso motorizzazione / porto (se applicabile).
enum PracticeFileStatus {
  notOpen,
  inProgress,
  waitingDocuments,
  submitted,
  closed,
}
