import '../../domain/backoffice/backoffice.dart';
import '../../domain/course_taxonomy.dart';
import '../../models/license_models.dart';
import 'backoffice_demo_seed.dart';

/// Dataset dimostrativo — **non collegato alle schermate studente attuali**.
///
/// Utile per test manuali o prime integrazioni repository backoffice.
abstract final class SchoolBackofficeDemoData {
  static const StudentId demoStudentLucia = 'stu-demo-lucia-001';
  static const StudentId demoStudentMarco = 'stu-demo-marco-002';

  static List<StudentProfile> get profiles => List.unmodifiable(_profiles);

  static List<StudentStudyProgressBundle> get progressBundles =>
      List.unmodifiable(_progress);

  static List<GuidanceAppointment> get appointments =>
      List.unmodifiable(_appointments);

  static List<ExamAttempt> get examAttempts => List.unmodifiable(_exams);

  static List<PaymentReceived> get payments => List.unmodifiable(_payments);

  /// Scheda completa demo per un [StudentId], se presente nel mock.
  /// Clona il seed in collezioni mutabili per [BackofficeDemoStore].
  static BackofficeDemoSeed cloneSeedForMutableStore() {
    return BackofficeDemoSeed(
      profiles: List<StudentProfile>.from(_profiles),
      progressBundles:
          _progress.map(_copyStudyProgressBundle).toList(growable: true),
      appointments: List<GuidanceAppointment>.from(_appointments),
      exams: List<ExamAttempt>.from(_exams),
      payments: List<PaymentReceived>.from(_payments),
      financial: Map<StudentId, StudentFinancialSummary>.from(_financial),
      practice: Map<StudentId, PracticeLicenseDossier?>.from(_practice),
    );
  }

  static StudentStudyProgressBundle _copyStudyProgressBundle(
    StudentStudyProgressBundle b,
  ) {
    return StudentStudyProgressBundle(
      studentId: b.studentId,
      assignedLessons: b.assignedLessons.map(_copyAssignedLesson).toList(),
      sheetUnlocks: b.sheetUnlocks.map(_copySheetUnlock).toList(),
      examAccessByCategory:
          b.examAccessByCategory.map(_copyExamAccess).toList(),
      errorReviewAssignments:
          b.errorReviewAssignments.map(_copyErrorReview).toList(),
      globalProgressNotes: b.globalProgressNotes,
    );
  }

  static AssignedLesson _copyAssignedLesson(AssignedLesson l) {
    return AssignedLesson(
      studentId: l.studentId,
      categoryId: l.categoryId,
      lessonNumber: l.lessonNumber,
      status: l.status,
      assignedAt: l.assignedAt,
      completedAt: l.completedAt,
      assignedByStaffId: l.assignedByStaffId,
      schoolNotes: l.schoolNotes,
    );
  }

  static LessonQuizSheetUnlock _copySheetUnlock(LessonQuizSheetUnlock u) {
    return LessonQuizSheetUnlock(
      studentId: u.studentId,
      categoryId: u.categoryId,
      lessonNumber: u.lessonNumber,
      sheetNumber: u.sheetNumber,
      unlocked: u.unlocked,
      unlockedAt: u.unlockedAt,
      unlockedByStaffId: u.unlockedByStaffId,
      revokedAt: u.revokedAt,
    );
  }

  static ExamQuizAccess _copyExamAccess(ExamQuizAccess e) {
    return ExamQuizAccess(
      studentId: e.studentId,
      categoryId: e.categoryId,
      examUnlocked: e.examUnlocked,
      updatedAt: e.updatedAt,
      updatedByStaffId: e.updatedByStaffId,
    );
  }

  static ErrorReviewTopicAssignment _copyErrorReview(
    ErrorReviewTopicAssignment r,
  ) {
    return ErrorReviewTopicAssignment(
      studentId: r.studentId,
      categoryId: r.categoryId,
      lessonNumber: r.lessonNumber,
      topicUnlocked: r.topicUnlocked,
      updatedAt: r.updatedAt,
      updatedByStaffId: r.updatedByStaffId,
      didacticNote: r.didacticNote,
    );
  }

  static StudentAdmin360View? aggregateFor(StudentId studentId) {
    final profileMatch = _profiles.where((e) => e.id == studentId).toList();
    if (profileMatch.isEmpty) return null;
    final profile = profileMatch.first;

    final progMatch =
        _progress.where((e) => e.studentId == studentId).toList();
    if (progMatch.isEmpty) return null;
    final prog = progMatch.first;

    final ap =
        _appointments.where((e) => e.studentId == studentId).toList(growable: false);
    final ex =
        _exams.where((e) => e.studentId == studentId).toList(growable: false);
    final pay =
        _payments.where((e) => e.studentId == studentId).toList(growable: false);

    final theory =
        ex.where((e) => e.examType == ExamAttemptType.theory).toList();
    final pract =
        ex.where((e) => e.examType == ExamAttemptType.practical).toList();

    final fin = _financial[studentId];
    if (fin == null) return null;

    return StudentAdmin360View(
      profile: profile,
      studyProgress: prog,
      appointments: ap,
      examSummary: StudentExamSummary(
        studentId: studentId,
        theoryAttempts: theory,
        practicalAttempts: pract,
      ),
      financialSummary: fin,
      payments: pay,
      practiceDossier: _practice[studentId],
      staffNotes: const [],
      activityLog: const [],
    );
  }

  static final List<StudentProfile> _profiles = [
    StudentProfile(
      id: demoStudentLucia,
      firstName: 'Lucia',
      lastName: 'Bianchi',
      phone: '+39 320 0000001',
      email: 'lucia.bianchi@example.com',
      birthDate: DateTime(1998, 4, 12),
      taxCode: 'BNCLCU98D52F205X',
      address: const PostalAddress(
        streetLine1: 'Via del Porto 12',
        postalCode: '20100',
        city: 'Milano',
        provinceCode: 'MI',
        countryCode: 'IT',
      ),
      enrolledCoursePath: EnrollmentCoursePath.entro12MigliaVela,
      registrationStatus: StudentRegistrationStatus.active,
      onboardingStatus: StudentOnboardingStatus.activeCourse,
      firstContactedAt: DateTime(2025, 1, 12),
      linkedAuthUserId: null,
      internalNotes: 'Iscrizione anno corrente — preferenza lezioni weekend.',
      createdAt: DateTime(2025, 1, 10),
      updatedAt: DateTime(2025, 3, 1),
    ),
    StudentProfile(
      id: demoStudentMarco,
      firstName: 'Marco',
      lastName: 'Verdi',
      phone: '+39 333 0000002',
      email: 'marco.verdi@example.com',
      birthDate: DateTime(1995, 11, 3),
      taxCode: 'VRDMRC95S03H501Y',
      address: const PostalAddress(
        streetLine1: 'Piazza Molo 5',
        postalCode: '16121',
        city: 'Genova',
        provinceCode: 'GE',
        countryCode: 'IT',
      ),
      enrolledCoursePath: EnrollmentCoursePath.d1,
      registrationStatus: StudentRegistrationStatus.pending,
      onboardingStatus: StudentOnboardingStatus.pendingReview,
      linkedAuthUserId: null,
      internalNotes: 'In attesa ultima rata iscrizione.',
      createdAt: DateTime(2025, 2, 5),
    ),
  ];

  static final List<StudentStudyProgressBundle> _progress = [
    StudentStudyProgressBundle(
      studentId: demoStudentLucia,
      assignedLessons: [
        AssignedLesson(
          studentId: demoStudentLucia,
          categoryId: LicenseCategoryId.motore,
          lessonNumber: 4,
          status: AssignedLessonStatus.completed,
          assignedAt: DateTime(2025, 2, 1),
          completedAt: DateTime(2025, 2, 20),
        ),
        AssignedLesson(
          studentId: demoStudentLucia,
          categoryId: LicenseCategoryId.motore,
          lessonNumber: 6,
          status: AssignedLessonStatus.inProgress,
          assignedAt: DateTime(2025, 3, 1),
        ),
      ],
      sheetUnlocks: [
        LessonQuizSheetUnlock(
          studentId: demoStudentLucia,
          categoryId: LicenseCategoryId.motore,
          lessonNumber: 6,
          sheetNumber: 1,
          unlocked: true,
          unlockedAt: DateTime(2025, 3, 2),
        ),
        LessonQuizSheetUnlock(
          studentId: demoStudentLucia,
          categoryId: LicenseCategoryId.motore,
          lessonNumber: 6,
          sheetNumber: 2,
          unlocked: false,
        ),
      ],
      examAccessByCategory: [
        ExamQuizAccess(
          studentId: demoStudentLucia,
          categoryId: LicenseCategoryId.motore,
          examUnlocked: false,
          updatedAt: DateTime(2025, 3, 1),
        ),
      ],
      errorReviewAssignments: [
        ErrorReviewTopicAssignment(
          studentId: demoStudentLucia,
          categoryId: LicenseCategoryId.motore,
          lessonNumber: 6,
          topicUnlocked: true,
          didacticNote: 'Ripasso fanali — errore alto su incroci.',
          updatedAt: DateTime(2025, 3, 3),
        ),
        ErrorReviewTopicAssignment(
          studentId: demoStudentLucia,
          categoryId: LicenseCategoryId.motore,
          lessonNumber: 7,
          topicUnlocked: false,
          updatedAt: DateTime(2025, 3, 3),
        ),
      ],
      globalProgressNotes: 'Teoria avanzata ok; consolidare COLREG prima esame.',
    ),
    StudentStudyProgressBundle(
      studentId: demoStudentMarco,
      assignedLessons: [
        AssignedLesson(
          studentId: demoStudentMarco,
          categoryId: LicenseCategoryId.motore,
          lessonNumber: 1,
          status: AssignedLessonStatus.planned,
          assignedAt: DateTime(2025, 2, 10),
        ),
      ],
      sheetUnlocks: [],
      examAccessByCategory: [
        ExamQuizAccess(
          studentId: demoStudentMarco,
          categoryId: LicenseCategoryId.motore,
          examUnlocked: false,
        ),
      ],
      errorReviewAssignments: [],
      globalProgressNotes: null,
    ),
  ];

  static final List<GuidanceAppointment> _appointments = [
    GuidanceAppointment(
      id: 'appt-001',
      studentId: demoStudentLucia,
      lessonDate: DateTime(2025, 3, 18),
      startTime: DateTime(2025, 3, 18, 14, 30),
      endTime: DateTime(2025, 3, 18, 17, 0),
      instructorName: 'Istruttore Rossi',
      instructorStaffId: 'staff-rossi',
      lessonType: GuidanceLessonType.theory,
      reminderStatus: AppointmentReminderStatus.sent,
      completionOutcome: AppointmentCompletionOutcome.pending,
      notes: 'Modulo COLREG — portare appunti ultima lezione.',
    ),
    GuidanceAppointment(
      id: 'appt-002',
      studentId: demoStudentMarco,
      lessonDate: DateTime(2025, 3, 22),
      startTime: DateTime(2025, 3, 22, 9, 0),
      instructorName: 'Istruttore Bianchi',
      lessonType: GuidanceLessonType.officeMeeting,
      reminderStatus: AppointmentReminderStatus.scheduled,
      completionOutcome: AppointmentCompletionOutcome.pending,
    ),
  ];

  static final List<ExamAttempt> _exams = [
    ExamAttempt(
      id: 'exam-th-01',
      studentId: demoStudentLucia,
      examType: ExamAttemptType.theory,
      attemptNumber: 1,
      result: ExamAttemptResult.scheduled,
      examDate: DateTime(2025, 4, 10),
      scoreOrLabel: null,
      notes: 'Prenotazione prova motorizzazione.',
    ),
    ExamAttempt(
      id: 'exam-pr-01',
      studentId: demoStudentLucia,
      examType: ExamAttemptType.practical,
      attemptNumber: 1,
      result: ExamAttemptResult.pending,
      notes: 'Da pianificare dopo superamento teoria.',
    ),
  ];

  static final Map<StudentId, StudentFinancialSummary> _financial = {
    demoStudentLucia: StudentFinancialSummary(
      studentId: demoStudentLucia,
      registrationFeeCents: 120000,
      currencyCode: 'EUR',
      totalPaidCents: 80000,
      remainingBalanceCents: 40000,
      accountingNotes: 'Seconda rata entro 30gg da avviso.',
      lastUpdatedAt: DateTime(2025, 3, 1),
    ),
    demoStudentMarco: StudentFinancialSummary(
      studentId: demoStudentMarco,
      registrationFeeCents: 120000,
      currencyCode: 'EUR',
      totalPaidCents: 30000,
      remainingBalanceCents: 90000,
      lastUpdatedAt: DateTime(2025, 2, 6),
    ),
  };

  static final List<PaymentReceived> _payments = [
    PaymentReceived(
      id: 'pay-001',
      studentId: demoStudentLucia,
      amountCents: 50000,
      currencyCode: 'EUR',
      receivedAt: DateTime(2025, 1, 15),
      method: PaymentMethod.sepaBankTransfer,
      receiptReference: 'Bonifico TRX-2025-0115',
      fiscalReceiptNumber: null,
      notes: 'Acconto iscrizione',
    ),
    PaymentReceived(
      id: 'pay-002',
      studentId: demoStudentLucia,
      amountCents: 30000,
      currencyCode: 'EUR',
      receivedAt: DateTime(2025, 2, 20),
      method: PaymentMethod.card,
      receiptReference: 'Stripe ch_abc123',
    ),
    PaymentReceived(
      id: 'pay-003',
      studentId: demoStudentMarco,
      amountCents: 30000,
      currencyCode: 'EUR',
      receivedAt: DateTime(2025, 2, 7),
      method: PaymentMethod.cash,
      receiptReference: 'RCV-GE-007',
    ),
  ];

  static final Map<StudentId, PracticeLicenseDossier> _practice = {
    demoStudentLucia: PracticeLicenseDossier(
      id: 'prac-lucia-01',
      studentId: demoStudentLucia,
      practiceNumber: 'PR-2025-8891',
      licenseNumber: null,
      documentStatus: LicenseDocumentStatus.collected,
      practiceStatus: PracticeFileStatus.inProgress,
      authorityNotes: 'Mancano due firme modulo uscita porto.',
    ),
  };
}
