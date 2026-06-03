import 'backoffice_enums.dart';

/// Valore colonna `students.onboarding_status` (snake_case SQL).
String studentOnboardingStatusDbValue(StudentOnboardingStatus s) {
  switch (s) {
    case StudentOnboardingStatus.pendingReview:
      return 'pending_review';
    case StudentOnboardingStatus.awaitingContact:
      return 'awaiting_contact';
    case StudentOnboardingStatus.awaitingDocuments:
      return 'awaiting_documents';
    case StudentOnboardingStatus.approved:
      return 'approved';
    case StudentOnboardingStatus.activeCourse:
      return 'active_course';
    case StudentOnboardingStatus.suspended:
      return 'suspended';
    case StudentOnboardingStatus.completed:
      return 'completed';
  }
}

/// Etichette italiane per UI staff (segreteria / onboarding).
String studentOnboardingStatusLabelIt(StudentOnboardingStatus s) {
  switch (s) {
    case StudentOnboardingStatus.pendingReview:
      return 'Da definire / in attesa';
    case StudentOnboardingStatus.awaitingContact:
      return 'Da contattare';
    case StudentOnboardingStatus.awaitingDocuments:
      return 'Documenti mancanti';
    case StudentOnboardingStatus.approved:
      return 'Approvato';
    case StudentOnboardingStatus.activeCourse:
      return 'Attivo (in corso)';
    case StudentOnboardingStatus.suspended:
      return 'Sospeso (onboarding)';
    case StudentOnboardingStatus.completed:
      return 'Completato';
  }
}

/// Stato onboarding dopo aver chiuso «da contattare» / «documenti mancanti» (senza nuovi campi DB).
StudentOnboardingStatus onboardingStatusAfterFollowUpCleared(
  StudentRegistrationStatus registration,
) {
  switch (registration) {
    case StudentRegistrationStatus.active:
      return StudentOnboardingStatus.activeCourse;
    case StudentRegistrationStatus.suspended:
      return StudentOnboardingStatus.suspended;
    case StudentRegistrationStatus.completed:
      return StudentOnboardingStatus.completed;
    case StudentRegistrationStatus.withdrawn:
      return StudentOnboardingStatus.pendingReview;
    case StudentRegistrationStatus.pending:
      return StudentOnboardingStatus.pendingReview;
  }
}

StudentOnboardingStatus studentOnboardingStatusFromDb(String raw) {
  switch (raw) {
    case 'pending_review':
      return StudentOnboardingStatus.pendingReview;
    case 'awaiting_contact':
      return StudentOnboardingStatus.awaitingContact;
    case 'awaiting_documents':
      return StudentOnboardingStatus.awaitingDocuments;
    case 'approved':
      return StudentOnboardingStatus.approved;
    case 'active_course':
      return StudentOnboardingStatus.activeCourse;
    case 'suspended':
      return StudentOnboardingStatus.suspended;
    case 'completed':
      return StudentOnboardingStatus.completed;
    default:
      return StudentOnboardingStatus.pendingReview;
  }
}
