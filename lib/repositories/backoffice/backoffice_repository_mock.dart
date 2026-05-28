import '../../data/backoffice_mock/backoffice_demo_store.dart';
import '../../domain/backoffice/backoffice.dart';
import '../../models/license_models.dart';
import 'backoffice_repository.dart';

/// Adattatore [BackofficeRepository] → [BackofficeDemoStore] (memoria / demo).
///
/// Nessuna rete; mantiene allineamento 1:1 con le API dello store mock attuale.
class BackofficeRepositoryMock implements BackofficeRepository {
  BackofficeRepositoryMock({BackofficeDemoStore? store})
    : _store = store ?? backofficeDemoStore;

  final BackofficeDemoStore _store;

  @override
  Future<List<StudentProfile>> listStudentProfiles() async {
    return List<StudentProfile>.from(_store.profilesForList);
  }

  @override
  Future<PracticeRegistryAssignment> assignPracticeRegistryNumber({
    required PracticeDossierId practiceDossierId,
    required DateTime registrationDate,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 40));
    return _store.assignPracticeRegistryNumber(
      practiceDossierId: practiceDossierId,
      registrationDate: registrationDate,
    );
  }

  @override
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
  }) async {
    try {
      return _store.createBackofficeStudent(
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        email: email,
        fiscalCode: fiscalCode,
        birthDate: birthDate,
        birthPlace: birthPlace,
        gender: gender,
        address: address,
        city: city,
        province: province,
        cap: cap,
        enrolledCoursePath: enrolledCoursePath,
        enrolledLicenseCategory: enrolledLicenseCategory,
        notes: notes,
        createPracticeDossier: createPracticeDossier,
        practiceType: practiceType,
        registrationDate: registrationDate,
      );
    } on DuplicateStudentEmailException {
      throw StateError('Esiste già un allievo con questa email.');
    }
  }

  @override
  Future<StudentAppAccessCredentials> createStudentAppAccess({
    required StudentId studentId,
    required String email,
    required String temporaryPassword,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (temporaryPassword.length < 8) {
      throw ArgumentError(
        'La password temporanea deve avere almeno 8 caratteri.',
      );
    }
    final em = email.trim().toLowerCase();
    if (em.isEmpty || !em.contains('@')) {
      throw ArgumentError('Email non valida.');
    }
    return StudentAppAccessCredentials(
      studentId: studentId,
      userId: '00000000-0000-4000-8000-00000000c001',
      email: em,
      temporaryPassword: temporaryPassword,
    );
  }

  @override
  Future<StudentAdmin360View?> getStudentAdmin360(StudentId studentId) async {
    return _store.aggregateFor(studentId);
  }

  @override
  Future<List<PracticeListItem>> listPracticeDossiers() async {
    final out = <PracticeListItem>[];
    for (final p in _store.profiles) {
      final view = _store.aggregateFor(p.id);
      final d = view?.practiceDossier;
      if (d == null) continue;
      out.add(
        PracticeListItem(
          practiceDossierId: d.id,
          studentId: d.studentId,
          studentFullName: '${p.firstName} ${p.lastName}'.trim(),
          studentEmail: p.email,
          studentPhone: p.phone,
          practiceType: d.practiceType,
          registrationDate: d.registrationDate,
          registryYear: d.registryYear,
          registryNumber: d.registryNumber,
          registryCode: d.registryCode,
          practiceNumber: d.practiceNumber,
          documentStatus: d.documentStatus,
          practiceStatus: d.practiceStatus,
        ),
      );
    }
    out.sort((a, b) {
      final da = a.registrationDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      final db = b.registrationDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      return db.compareTo(da);
    });
    return out;
  }

  @override
  Future<List<GuidanceListItem>> listGuidanceAppointments() async {
    final out = <GuidanceListItem>[];
    for (final p in _store.profiles) {
      final view = _store.aggregateFor(p.id);
      if (view == null) continue;
      for (final a in view.appointments) {
        out.add(
          GuidanceListItem.fromGuidanceAppointment(
            a,
            studentFullName: '${p.firstName} ${p.lastName}'.trim(),
            studentEmail: p.email,
            studentPhone: p.phone,
          ),
        );
      }
    }
    out.sort((a, b) {
      return b.effectiveSortKey.compareTo(a.effectiveSortKey);
    });
    return out;
  }

  @override
  Future<List<AccountingPaymentListItem>> listAccountingPayments() async {
    return List<AccountingPaymentListItem>.from(
      _store.listAccountingPaymentDirectoryItems(),
    );
  }

  @override
  Future<String> createStudentDocumentSignedUrl(String storagePath) async {
    return '';
  }

  @override
  Future<String> createStudentPhotoSignedUrl(String storagePath) async {
    return '';
  }

  @override
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
  }) async {
    return _store.uploadStudentDocument(
      studentId: studentId,
      practiceDossierId: practiceDossierId,
      documentType: documentType,
      title: title,
      fileName: fileName,
      bytes: bytes,
      mimeType: mimeType,
      expiresAt: expiresAt,
      notes: notes,
    );
  }

  @override
  Future<StudentPhoto> uploadStudentPhoto({
    required StudentId studentId,
    required String photoKind,
    required String fileName,
    required List<int> bytes,
    String? mimeType,
    String? notes,
  }) async {
    return _store.uploadStudentPhoto(
      studentId: studentId,
      photoKind: photoKind,
      fileName: fileName,
      bytes: bytes,
      mimeType: mimeType,
      notes: notes,
    );
  }

  @override
  Future<void> setLessonSheetUnlocked({
    required StudentId studentId,
    required LicenseCategoryId categoryId,
    required int lessonNumber,
    required int sheetNumber,
    required bool unlocked,
  }) async {
    _store.setLessonSheetUnlocked(
      studentId: studentId,
      categoryId: categoryId,
      lessonNumber: lessonNumber,
      sheetNumber: sheetNumber,
      unlocked: unlocked,
    );
  }

  @override
  Future<void> setExamQuizAccessForCategory({
    required StudentId studentId,
    required LicenseCategoryId categoryId,
    required bool examUnlocked,
  }) async {
    _store.setExamQuizAccessForCategory(
      studentId: studentId,
      categoryId: categoryId,
      examUnlocked: examUnlocked,
    );
  }

  @override
  Future<void> setErrorReviewTopicAssignment({
    required StudentId studentId,
    required LicenseCategoryId categoryId,
    required int lessonNumber,
    required bool topicUnlocked,
    String? didacticNote,
  }) async {
    _store.setErrorReviewTopicAssignment(
      studentId: studentId,
      categoryId: categoryId,
      lessonNumber: lessonNumber,
      topicUnlocked: topicUnlocked,
      didacticNote: didacticNote,
    );
  }

  @override
  Future<void> addPayment({
    required StudentId studentId,
    required int amountCents,
    required PaymentMethod method,
    required DateTime receivedAt,
    String? notes,
    String? receiptReference,
    String? idempotencyKey,
  }) async {
    _store.addPayment(
      studentId: studentId,
      amountCents: amountCents,
      method: method,
      receivedAt: receivedAt,
      notes: notes,
      receiptReference: receiptReference,
    );
  }

  @override
  Future<void> addGuidanceAppointment({
    required StudentId studentId,
    required DateTime lessonDate,
    DateTime? startTime,
    DateTime? endTime,
    String? instructorName,
    required GuidanceLessonType lessonType,
    String? notes,
  }) async {
    _store.addGuidanceAppointment(
      studentId: studentId,
      lessonDate: lessonDate,
      startTime: startTime,
      endTime: endTime,
      instructorName: instructorName,
      lessonType: lessonType,
      notes: notes,
    );
  }

  @override
  Future<void> updateGuidanceAppointmentOutcome({
    required AppointmentId appointmentId,
    required AppointmentCompletionOutcome outcome,
  }) async {
    _store.updateGuidanceAppointmentOutcome(
      appointmentId: appointmentId,
      outcome: outcome,
    );
  }

  @override
  Future<void> updateGuidanceAppointment({
    required AppointmentId appointmentId,
    required StudentId studentId,
    required DateTime lessonDate,
    DateTime? startTime,
    DateTime? endTime,
    String? instructorName,
    String? notes,
  }) async {
    _store.updateGuidanceAppointment(
      appointmentId: appointmentId,
      studentId: studentId,
      lessonDate: lessonDate,
      startTime: startTime,
      endTime: endTime,
      instructorName: instructorName,
      notes: notes,
    );
  }

  @override
  Future<void> deleteGuidanceAppointment({
    required AppointmentId appointmentId,
  }) async {
    _store.deleteGuidanceAppointment(appointmentId: appointmentId);
  }

  @override
  Future<void> addInternalNote({
    required StudentId studentId,
    required String body,
    String? authorStaffName,
    StaffNoteCategory category = StaffNoteCategory.general,
  }) async {
    _store.addInternalNote(
      studentId: studentId,
      body: body,
      authorStaffName: authorStaffName,
      category: category,
    );
  }

  @override
  Future<void> updateProfileLegacyInternalNote({
    required StudentId studentId,
    String? internalNotes,
  }) async {
    _store.updateProfileLegacyInternalNote(
      studentId: studentId,
      internalNotes: internalNotes,
    );
  }

  @override
  Future<void> addExamAttemptRecord({
    required StudentId studentId,
    required ExamAttemptType examType,
    required ExamAttemptResult result,
    DateTime? examDate,
    String? scoreOrLabel,
    String? notes,
  }) async {
    _store.addExamAttemptRecord(
      studentId: studentId,
      examType: examType,
      result: result,
      examDate: examDate,
      scoreOrLabel: scoreOrLabel,
      notes: notes,
    );
  }

  @override
  Future<void> updatePracticeDossier({
    required StudentId studentId,
    String? practiceNumber,
    String? licenseNumber,
    DateTime? issueDate,
    DateTime? expirationDate,
    LicenseDocumentStatus? documentStatus,
    PracticeFileStatus? practiceStatus,
    String? authorityNotes,
  }) async {
    _store.updatePracticeDossier(
      studentId: studentId,
      practiceNumber: practiceNumber,
      licenseNumber: licenseNumber,
      issueDate: issueDate,
      expirationDate: expirationDate,
      documentStatus: documentStatus,
      practiceStatus: practiceStatus,
      authorityNotes: authorityNotes,
    );
  }

  @override
  Future<void> appendActivityEvent(BackofficeActivityEvent event) async {
    _store.appendActivityEvent(event);
  }

  @override
  Future<void> updateStudentOnboardingStatus({
    required StudentId studentId,
    required StudentOnboardingStatus status,
    String? onboardingNotes,
  }) async {
    _store.updateStudentOnboardingStatus(
      studentId: studentId,
      status: status,
      onboardingNotes: onboardingNotes,
    );
  }

  @override
  Future<void> markStudentFirstContacted(StudentId studentId) async {
    _store.markStudentFirstContacted(studentId);
  }

  @override
  Future<void> setStudentRegistrationFeeCents({
    required StudentId studentId,
    required int registrationFeeCents,
  }) async {
    _store.setStudentRegistrationFeeCents(
      studentId: studentId,
      registrationFeeCents: registrationFeeCents,
    );
  }

  @override
  Future<void> activateStudentCourse(StudentId studentId) async {
    _store.activateStudentCourse(studentId);
  }
}
