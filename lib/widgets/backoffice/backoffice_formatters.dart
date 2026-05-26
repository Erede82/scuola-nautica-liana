import '../../domain/backoffice/backoffice.dart';
import '../../domain/course_taxonomy.dart';
import '../../domain/enrollment_content_mapping.dart';
import '../../data/license_catalog.dart';
import '../../models/license_models.dart';

/// Etichette italiane e formattazione per UI backoffice (riusabile da più schermate).
abstract final class BackofficeFormatters {
  static String moneyEur(int cents) => '${(cents / 100).toStringAsFixed(2)} €';

  static String categoryName(LicenseCategoryId id) =>
      LicenseCatalog.byId(id).name;

  static String enrollmentCoursePath(EnrollmentCoursePath p) => p.labelIt;

  static String contentModulesForEnrollmentPath(EnrollmentCoursePath p) =>
      EnrollmentContentMapping.contentModulesJoinedIt(p);

  static String registrationStatus(StudentRegistrationStatus s) {
    switch (s) {
      case StudentRegistrationStatus.pending:
        return 'In attesa';
      case StudentRegistrationStatus.active:
        return 'Attivo';
      case StudentRegistrationStatus.suspended:
        return 'Sospeso';
      case StudentRegistrationStatus.completed:
        return 'Completato';
      case StudentRegistrationStatus.withdrawn:
        return 'Ritirato';
    }
  }

  /// Stato operativo onboarding segreteria (`students.onboarding_status`).
  static String onboardingStatus(StudentOnboardingStatus s) =>
      studentOnboardingStatusLabelIt(s);

  static String examResult(ExamAttemptResult r) {
    switch (r) {
      case ExamAttemptResult.pending:
        return 'In attesa';
      case ExamAttemptResult.scheduled:
        return 'Programmato';
      case ExamAttemptResult.passed:
        return 'Superato';
      case ExamAttemptResult.failed:
        return 'Non superato';
      case ExamAttemptResult.exempt:
        return 'Esente';
      case ExamAttemptResult.noShow:
        return 'Assente';
    }
  }

  static String examType(ExamAttemptType t) {
    switch (t) {
      case ExamAttemptType.theory:
        return 'Teoria';
      case ExamAttemptType.practical:
        return 'Pratica';
    }
  }

  static String paymentMethod(PaymentMethod m) {
    switch (m) {
      case PaymentMethod.card:
        return 'Carta';
      case PaymentMethod.sepaBankTransfer:
        return 'Bonifico';
      case PaymentMethod.cash:
        return 'Contanti';
      case PaymentMethod.check:
        return 'Assegno';
      case PaymentMethod.other:
        return 'Altro';
    }
  }

  static String documentStatus(LicenseDocumentStatus s) {
    switch (s) {
      case LicenseDocumentStatus.notStarted:
        return 'Non avviato';
      case LicenseDocumentStatus.collected:
        return 'Raccolta documenti';
      case LicenseDocumentStatus.submittedToAuthority:
        return 'Inviato pratica';
      case LicenseDocumentStatus.issued:
        return 'Rilasciato';
      case LicenseDocumentStatus.revoked:
        return 'Revocato';
      case LicenseDocumentStatus.expired:
        return 'Scaduto';
    }
  }

  static String practiceStatus(PracticeFileStatus s) {
    switch (s) {
      case PracticeFileStatus.notOpen:
        return 'Non aperta';
      case PracticeFileStatus.inProgress:
        return 'In lavorazione';
      case PracticeFileStatus.waitingDocuments:
        return 'Attenzione doc.';
      case PracticeFileStatus.submitted:
        return 'Inviata';
      case PracticeFileStatus.closed:
        return 'Chiusa';
    }
  }

  static String lessonAssignmentStatus(AssignedLessonStatus s) {
    switch (s) {
      case AssignedLessonStatus.planned:
        return 'Pianificata';
      case AssignedLessonStatus.inProgress:
        return 'In corso';
      case AssignedLessonStatus.completed:
        return 'Completata';
      case AssignedLessonStatus.skipped:
        return 'Saltata';
    }
  }

  static String reminderStatus(AppointmentReminderStatus s) {
    switch (s) {
      case AppointmentReminderStatus.none:
        return 'Nessuno';
      case AppointmentReminderStatus.scheduled:
        return 'Programmato';
      case AppointmentReminderStatus.sent:
        return 'Inviato';
      case AppointmentReminderStatus.acknowledged:
        return 'Confermato';
    }
  }

  static String appointmentOutcome(AppointmentCompletionOutcome o) {
    switch (o) {
      case AppointmentCompletionOutcome.pending:
        return 'Da definire';
      case AppointmentCompletionOutcome.attended:
        return 'Svolta';
      case AppointmentCompletionOutcome.absent:
        return 'Assente';
      case AppointmentCompletionOutcome.rescheduled:
        return 'Riprogrammato';
    }
  }

  static String staffNoteCategory(StaffNoteCategory c) {
    switch (c) {
      case StaffNoteCategory.general:
        return 'Generale';
      case StaffNoteCategory.accounting:
        return 'Contabilità';
      case StaffNoteCategory.study:
        return 'Studio';
      case StaffNoteCategory.exam:
        return 'Esami';
    }
  }

  static String activityType(BackofficeActivityType t) {
    switch (t) {
      case BackofficeActivityType.paymentAdded:
        return 'Pagamento';
      case BackofficeActivityType.guidanceAppointmentAdded:
        return 'Guida';
      case BackofficeActivityType.examResultRecorded:
        return 'Esame';
      case BackofficeActivityType.internalNoteAdded:
        return 'Nota interna';
      case BackofficeActivityType.practiceDossierUpdated:
        return 'Pratica / doc.';
      case BackofficeActivityType.studyAccessChanged:
        return 'Accessi studio';
      case BackofficeActivityType.profileInternalNoteUpdated:
        return 'Note anagrafica';
      case BackofficeActivityType.studentRegisteredFromApp:
        return 'Iscrizione app';
      case BackofficeActivityType.backofficeStudentCreated:
        return 'Nuova pratica';
      case BackofficeActivityType.onboardingStatusChanged:
        return 'Onboarding';
    }
  }

  static String lessonType(GuidanceLessonType t) {
    switch (t) {
      case GuidanceLessonType.theory:
        return 'Teoria';
      case GuidanceLessonType.practiceSea:
        return 'Pratica in mare';
      case GuidanceLessonType.practiceSimulator:
        return 'Simulatore';
      case GuidanceLessonType.officeMeeting:
        return 'Segreteria';
      case GuidanceLessonType.examPrep:
        return 'Pre-esame';
      case GuidanceLessonType.other:
        return 'Altro';
    }
  }

  static String dateUi(DateTime? d) {
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  static String dateTimeUi(DateTime? d) {
    if (d == null) return '—';
    final t =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return '${dateUi(d)} · $t';
  }
}
