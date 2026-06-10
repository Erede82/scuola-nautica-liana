import '../../domain/backoffice/backoffice.dart';
import '../../models/license_models.dart';

/// Callback dopo una mutazione: passa la scheda già ricaricata per evitare doppia GET.
typedef BackofficeDetailRefresh =
    Future<void> Function([StudentAdmin360View? updated]);

/// Contratto persistenza backoffice scuola — implementazione mock o Supabase.
///
/// La shell backoffice usa [backofficeRepository] (`backoffice_registry.dart`).
/// Le mutazioni passano da questo contratto; il mock aggiorna [BackofficeDemoStore].
abstract class BackofficeRepository {
  /// Anagrafiche ordinate come restituite dal backend (il mock non garantisce sort).
  Future<List<StudentProfile>> listStudentProfiles();

  /// Crea un nuovo allievo da backoffice **senza** account Auth né sessione studente.
  ///
  /// Non usa `register_student_app` né `signUp`. Opzionalmente crea la riga `practice_dossiers`.
  Future<BackofficeNewStudentOutcome> createBackofficeStudent({
    required String firstName,
    required String lastName,
    String? phone,
    String? email,
    String? fiscalCode,
    DateTime? birthDate,
    String? birthPlace,
    String? gender,
    String? address,
    String? city,
    String? province,
    String? cap,
    String? enrolledCoursePath,
    String? enrolledLicenseCategory,
    String? notes,
    bool createPracticeDossier = true,
    String? practiceType,
    DateTime? registrationDate,

    /// Se `true` (default), dopo aver creato il dossier assegna anche il numero
    /// di registro via RPC. Per rinnovo/duplicato passare `false`: il fascicolo
    /// viene creato ma NON consuma un numero di registro.
    bool assignRegistryNumber = true,
  });

  /// Assegna progressivo registro pratiche per anno (RPC server).
  Future<PracticeRegistryAssignment> assignPracticeRegistryNumber({
    required PracticeDossierId practiceDossierId,
    required DateTime registrationDate,
  });

  /// Crea utente Auth lato server (Edge Function) e collega `students.user_id` via RPC.
  /// La password non viene mai persistita dal client oltre a questo trasporto in memoria.
  Future<StudentAppAccessCredentials> createStudentAppAccess({
    required StudentId studentId,
    required String email,
    required String temporaryPassword,
  });

  /// Vista aggregata 360° (stesso significato di [StudentAdmin360View] nel dominio).
  Future<StudentAdmin360View?> getStudentAdmin360(StudentId studentId);

  /// Directory pratiche: fascicoli con dati minimi allievo (**solo SELECT** lato Supabase).
  Future<List<PracticeListItem>> listPracticeDossiers();

  /// Directory guide/agenda: appuntamenti con dati minimi allievo (**solo SELECT** lato Supabase).
  Future<List<GuidanceListItem>> listGuidanceAppointments();

  /// Directory contabile: tutti gli incassi con dati minimi allievo (**solo SELECT** lato Supabase).
  Future<List<AccountingPaymentListItem>> listAccountingPayments();

  /// Crea un URL temporaneo read-only per un documento allievo in bucket privato.
  Future<String> createStudentDocumentSignedUrl(String storagePath);

  /// Crea un URL temporaneo read-only per una foto allievo in bucket privato.
  Future<String> createStudentPhotoSignedUrl(String storagePath);

  Future<StudentDocument> uploadStudentDocument({
    required StudentId studentId,
    PracticeDossierId? practiceDossierId,
    required String documentType,
    required String title,
    required String fileName,
    required List<int> bytes,
    String? mimeType,
    DateTime? expiresAt,
    String? notes,
  });

  /// Elimina documento allievo (record DB + file storage se presente).
  Future<void> deleteStudentDocument({
    required String documentId,
    String? storagePath,
  });

  /// Segna un requisito checklist come non necessario per il fascicolo pratica.
  Future<void> setPracticeDocumentRequirementWaived({
    required StudentId studentId,
    required PracticeDossierId practiceDossierId,
    required PracticeDocumentRequirementId requirementId,
    String? practiceType,
    String? note,
  });

  /// Rimuove l'esenzione "non necessario" per un requisito checklist.
  Future<void> clearPracticeDocumentRequirementWaiver({
    required StudentId studentId,
    required PracticeDossierId practiceDossierId,
    required PracticeDocumentRequirementId requirementId,
    String? practiceType,
  });

  Future<StudentPhoto> uploadStudentPhoto({
    required StudentId studentId,
    required String photoKind,
    required String fileName,
    required List<int> bytes,
    String? mimeType,
    String? notes,
  });

  Future<void> setLessonSheetUnlocked({
    required StudentId studentId,
    required LicenseCategoryId categoryId,
    required int lessonNumber,
    required int sheetNumber,
    required bool unlocked,
  });

  Future<void> setExamQuizAccessForCategory({
    required StudentId studentId,
    required LicenseCategoryId categoryId,
    required bool examUnlocked,
  });

  Future<void> setErrorReviewTopicAssignment({
    required StudentId studentId,
    required LicenseCategoryId categoryId,
    required int lessonNumber,
    required bool topicUnlocked,
    String? didacticNote,
  });

  Future<void> addPayment({
    required StudentId studentId,
    required int amountCents,
    required PaymentMethod method,
    required DateTime receivedAt,
    String? notes,
    String? receiptReference,
    String? idempotencyKey,
  });

  Future<void> addGuidanceAppointment({
    required StudentId studentId,
    required DateTime lessonDate,
    DateTime? startTime,
    DateTime? endTime,
    String? instructorName,
    required GuidanceLessonType lessonType,
    String? notes,
  });

  /// Aggiorna solo l’esito operativo di un appuntamento guida (staff).
  Future<void> updateGuidanceAppointmentOutcome({
    required AppointmentId appointmentId,
    required AppointmentCompletionOutcome outcome,
  });

  /// Aggiorna data/orari/istruttore/note di una guida esistente.
  Future<void> updateGuidanceAppointment({
    required AppointmentId appointmentId,
    required StudentId studentId,
    required DateTime lessonDate,
    DateTime? startTime,
    DateTime? endTime,
    String? instructorName,
    String? notes,
  });

  /// Elimina una guida dall’agenda (hard delete controllato lato repository).
  Future<void> deleteGuidanceAppointment({
    required AppointmentId appointmentId,
  });

  Future<void> addInternalNote({
    required StudentId studentId,
    required String body,
    String? authorStaffName,
    StaffNoteCategory category = StaffNoteCategory.general,
  });

  Future<void> updateProfileLegacyInternalNote({
    required StudentId studentId,
    String? internalNotes,
  });

  Future<void> addExamAttemptRecord({
    required StudentId studentId,
    required ExamAttemptType examType,
    required ExamAttemptResult result,
    DateTime? examDate,
    String? scoreOrLabel,
    String? notes,
  });

  Future<void> updatePracticeDossier({
    required StudentId studentId,
    String? practiceNumber,
    String? licenseNumber,
    DateTime? issueDate,
    DateTime? expirationDate,
    LicenseDocumentStatus? documentStatus,
    PracticeFileStatus? practiceStatus,
    String? authorityNotes,
  });

  /// Inserimento manuale evento audit (opzionale; la mutazione può loggare lato server).
  Future<void> appendActivityEvent(BackofficeActivityEvent event);

  /// Stato operativo onboarding (segreteria).
  Future<void> updateStudentOnboardingStatus({
    required StudentId studentId,
    required StudentOnboardingStatus status,
    String? onboardingNotes,
    String? activityTitle,
    String? activityDescription,
  });

  /// Registra primo contatto con l’allievo.
  Future<void> markStudentFirstContacted(StudentId studentId);

  /// Imposta la quota iscrizione attesa (ricalcola residuo con incassi esistenti).
  Future<void> setStudentRegistrationFeeCents({
    required StudentId studentId,
    required int registrationFeeCents,
  });

  /// Attiva il percorso (iscrizione attiva + onboarding in corso).
  Future<void> activateStudentCourse(StudentId studentId);
}
