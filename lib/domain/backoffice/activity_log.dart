import 'ids.dart';

/// Tipologia evento audit lato backoffice (mock / futura tabella `activity_events`).
enum BackofficeActivityType {
  paymentAdded,
  guidanceAppointmentAdded,
  examResultRecorded,
  internalNoteAdded,
  practiceDossierUpdated,
  studyAccessChanged,
  profileInternalNoteUpdated,

  /// Nuovo studente registrato dall’app (onboarding / Supabase Auth in futuro).
  studentRegisteredFromApp,

  /// Nuova anagrafica creata dallo staff dal gestionale (senza Auth).
  backofficeStudentCreated,

  /// Cambio stato onboarding operativo (segreteria).
  onboardingStatusChanged,
}

class BackofficeActivityEvent {
  const BackofficeActivityEvent({
    required this.id,
    required this.studentId,
    required this.occurredAt,
    required this.type,
    required this.title,
    this.description,
  });

  final BackofficeActivityEventId id;
  final StudentId studentId;
  final DateTime occurredAt;
  final BackofficeActivityType type;
  final String title;

  /// Dettaglio opzionale (es. importo, riferimento scheda).
  final String? description;
}
