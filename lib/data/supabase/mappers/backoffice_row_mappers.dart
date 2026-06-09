import '../../../domain/backoffice/backoffice.dart';
import '../../../domain/course_taxonomy.dart';
import '../../../domain/enrollment_content_mapping.dart';
import '../../../models/license_models.dart';
import '../dto/backoffice_rows.dart';

T _enumByName<T extends Enum>(List<T> values, String raw, T fallback) {
  for (final v in values) {
    if (v.name == raw) return v;
  }
  return fallback;
}

/// `students` + opzionale `student_financial_summaries` → riepilogo dominio parziale.
StudentProfile mapStudentRowToProfile(StudentRow r) {
  final legacyCategory = _enumByName(
    LicenseCategoryId.values,
    r.enrolledLicenseCategory,
    LicenseCategoryId.motore,
  );
  final coursePath =
      EnrollmentCoursePathStorage.tryParse(r.enrolledCoursePath) ??
      EnrollmentContentMapping.inferEnrollmentPathFromLegacyCategory(
        legacyCategory,
      );

  return StudentProfile(
    id: r.id,
    firstName: r.firstName,
    lastName: r.lastName,
    phone: r.phone,
    email: r.email,
    birthDate: r.birthDate,
    taxCode: r.fiscalCode,
    birthPlace: r.birthPlace?.trim().isEmpty ?? true
        ? null
        : r.birthPlace!.trim(),
    gender: r.gender?.trim().isEmpty ?? true ? null : r.gender!.trim(),
    address: _postalAddressFromStudentRow(r),
    enrolledCoursePath: coursePath,
    registrationStatus: () {
      final raw = r.registrationStatus.trim();
      if (raw.isEmpty) return StudentRegistrationStatus.pending;
      return _enumByName(
        StudentRegistrationStatus.values,
        raw,
        StudentRegistrationStatus.pending,
      );
    }(),
    // NULL da DB: trattato come da censire in segreteria (non "attivo").
    onboardingStatus: r.onboardingStatus != null
        ? studentOnboardingStatusFromDb(r.onboardingStatus!)
        : StudentOnboardingStatus.pendingReview,
    firstContactedAt: r.firstContactedAt,
    onboardingNotes: r.onboardingNotes,
    linkedAuthUserId: r.userId,
    internalNotes: r.notes,
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
    practiceDossierType: r.practiceDossierType,
  );
}

PostalAddress? _postalAddressFromStudentRow(StudentRow r) {
  var street = r.addressStreet?.trim();
  var city = r.city?.trim();
  var prov = r.province?.trim();
  var cap = r.cap?.trim();

  final legacy = r.legacyAddressJson;
  if (legacy != null) {
    street ??=
        legacy['street_line1'] as String? ?? legacy['streetLine1'] as String?;
    street = street?.trim();
    city ??= legacy['city'] as String?;
    city = city?.trim();
    prov ??=
        legacy['province_code'] as String? ?? legacy['provinceCode'] as String?;
    prov = prov?.trim();
    cap ??= legacy['postal_code'] as String? ?? legacy['postalCode'] as String?;
    cap = cap?.trim();
  }

  final has =
      (street != null && street.isNotEmpty) ||
      (city != null && city.isNotEmpty) ||
      (prov != null && prov.isNotEmpty) ||
      (cap != null && cap.isNotEmpty);
  if (!has) return null;

  return PostalAddress(
    streetLine1: street != null && street.isNotEmpty ? street : null,
    city: city != null && city.isNotEmpty ? city : null,
    provinceCode: prov != null && prov.isNotEmpty ? prov : null,
    postalCode: cap != null && cap.isNotEmpty ? cap : null,
    countryCode: 'IT',
  );
}

StudentFinancialSummary mapFinancialRowToSummary(StudentFinancialSummaryRow r) {
  return StudentFinancialSummary(
    studentId: r.studentId,
    registrationFeeCents: r.registrationFeeCents,
    currencyCode: r.currencyCode,
    totalPaidCents: r.totalPaidCents,
    remainingBalanceCents: r.remainingBalanceCents,
    accountingNotes: r.accountingNotes,
    lastUpdatedAt: r.lastUpdatedAt,
  );
}

PaymentReceived mapPaymentRowToDomain(PaymentRow r) {
  return PaymentReceived(
    id: r.id,
    studentId: r.studentId,
    amountCents: r.amountCents,
    currencyCode: r.currencyCode,
    receivedAt: r.receivedAt,
    method: _enumByName(PaymentMethod.values, r.method, PaymentMethod.other),
    receiptReference: r.receiptReference,
    fiscalReceiptNumber: r.fiscalReceiptNumber,
    notes: r.notes,
    recordedByStaffId: r.recordedByStaffId,
  );
}

AccountingPaymentListItem mapPaymentAndStudentToAccountingListItem(
  PaymentRow pay,
  StudentRow? student,
) {
  final received = mapPaymentRowToDomain(pay);
  final name = student == null
      ? 'Allievo'
      : '${student.firstName} ${student.lastName}'.trim();
  return AccountingPaymentListItem(
    paymentId: pay.id,
    studentId: pay.studentId,
    studentFullName: name.isEmpty ? 'Allievo' : name,
    studentEmail: student?.email,
    studentPhone: student?.phone,
    amountCents: pay.amountCents,
    currencyCode: pay.currencyCode,
    receivedAt: pay.receivedAt,
    method: received.method,
    receiptReference: pay.receiptReference,
    fiscalReceiptNumber: pay.fiscalReceiptNumber,
    notes: pay.notes,
    recordedByStaffId: pay.recordedByStaffId,
  );
}

GuidanceListItem mapGuidanceListItemFromRows(
  GuidanceAppointmentRow d,
  StudentRow? student,
) {
  final name = student == null
      ? 'Allievo (dati non caricati)'
      : '${student.firstName} ${student.lastName}'.trim();
  return GuidanceListItem(
    appointmentId: d.id,
    studentId: d.studentId,
    studentFullName: name,
    studentEmail: student?.email,
    studentPhone: student?.phone,
    lessonDate: d.lessonDate,
    startTime: d.startTime,
    endTime: d.endTime,
    instructorName: d.instructorName,
    instructorStaffId: d.instructorStaffId,
    lessonType: _enumByName(
      GuidanceLessonType.values,
      d.lessonType,
      GuidanceLessonType.other,
    ),
    reminderStatus: _enumByName(
      AppointmentReminderStatus.values,
      d.reminderStatus,
      AppointmentReminderStatus.none,
    ),
    completionOutcome: _enumByName(
      AppointmentCompletionOutcome.values,
      d.completionOutcome,
      AppointmentCompletionOutcome.pending,
    ),
    notes: d.notes,
  );
}

GuidanceAppointment mapGuidanceRowToDomain(GuidanceAppointmentRow r) {
  return GuidanceAppointment(
    id: r.id,
    studentId: r.studentId,
    lessonDate: r.lessonDate,
    startTime: r.startTime,
    endTime: r.endTime,
    instructorName: r.instructorName,
    instructorStaffId: r.instructorStaffId,
    lessonType: _enumByName(
      GuidanceLessonType.values,
      r.lessonType,
      GuidanceLessonType.other,
    ),
    reminderStatus: _enumByName(
      AppointmentReminderStatus.values,
      r.reminderStatus,
      AppointmentReminderStatus.none,
    ),
    completionOutcome: _enumByName(
      AppointmentCompletionOutcome.values,
      r.completionOutcome,
      AppointmentCompletionOutcome.pending,
    ),
    notes: r.notes,
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
  );
}

ExamAttempt mapExamAttemptRowToDomain(ExamAttemptRow r) {
  return ExamAttempt(
    id: r.id,
    studentId: r.studentId,
    examType: _enumByName(
      ExamAttemptType.values,
      r.examType,
      ExamAttemptType.theory,
    ),
    attemptNumber: r.attemptNumber,
    result: _enumByName(
      ExamAttemptResult.values,
      r.result,
      ExamAttemptResult.pending,
    ),
    examDate: r.examDate,
    scoreOrLabel: r.scoreOrLabel,
    externalSessionId: r.externalSessionId,
    notes: r.notes,
    recordedByStaffId: r.recordedByStaffId,
    createdAt: r.createdAt,
  );
}

PracticeListItem mapPracticeListItemFromRows(
  PracticeDossierRow d,
  StudentRow? student, {
  PracticeDocumentChecklistSummary documentChecklistSummary =
      PracticeDocumentChecklistSummary.notApplicable,
}) {
  final name = student == null
      ? 'Allievo (dati non caricati)'
      : '${student.firstName} ${student.lastName}'.trim();
  return PracticeListItem(
    practiceDossierId: d.id,
    studentId: d.studentId,
    studentFullName: name,
    studentEmail: student?.email,
    studentPhone: student?.phone,
    practiceType: d.practiceType,
    registrationDate: d.registrationDate,
    registryYear: d.registryYear,
    registryNumber: d.registryNumber,
    registryCode: d.registryCode,
    practiceNumber: d.practiceNumber,
    documentStatus: _enumByName(
      LicenseDocumentStatus.values,
      d.documentStatus,
      LicenseDocumentStatus.notStarted,
    ),
    practiceStatus: _enumByName(
      PracticeFileStatus.values,
      d.practiceStatus,
      PracticeFileStatus.notOpen,
    ),
    documentChecklistSummary: documentChecklistSummary,
  );
}

PracticeLicenseDossier mapPracticeRowToDomain(PracticeDossierRow r) {
  return PracticeLicenseDossier(
    id: r.id,
    studentId: r.studentId,
    practiceType: r.practiceType,
    registrationDate: r.registrationDate,
    registryYear: r.registryYear,
    registryNumber: r.registryNumber,
    registryCode: r.registryCode,
    practiceNumber: r.practiceNumber,
    licenseNumber: r.licenseNumber,
    issueDate: r.issueDate,
    expirationDate: r.expirationDate,
    documentStatus: _enumByName(
      LicenseDocumentStatus.values,
      r.documentStatus,
      LicenseDocumentStatus.notStarted,
    ),
    practiceStatus: _enumByName(
      PracticeFileStatus.values,
      r.practiceStatus,
      PracticeFileStatus.notOpen,
    ),
    authorityNotes: r.authorityNotes,
    lastCheckedAt: r.lastCheckedAt,
    updatedByStaffId: r.updatedByStaffId,
  );
}

StudentDocument mapStudentDocumentRowToDomain(StudentDocumentRow r) {
  return StudentDocument(
    id: r.id,
    studentId: r.studentId,
    practiceDossierId: r.practiceDossierId,
    documentType: r.documentType,
    title: r.title,
    storagePath: r.storagePath,
    fileName: r.fileName,
    mimeType: r.mimeType,
    status: r.status,
    expiresAt: r.expiresAt,
    notes: r.notes,
    uploadedByStaffId: r.uploadedByStaffId,
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
  );
}

StudentPhoto mapStudentPhotoRowToDomain(StudentPhotoRow r) {
  return StudentPhoto(
    id: r.id,
    studentId: r.studentId,
    photoKind: r.photoKind,
    storagePath: r.storagePath,
    fileName: r.fileName,
    mimeType: r.mimeType,
    notes: r.notes,
    uploadedByStaffId: r.uploadedByStaffId,
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
  );
}

PracticeDocumentWaiver? mapPracticeDocumentWaiverRowToDomain(
  PracticeDocumentWaiverRow r,
) {
  final requirementId = practiceDocumentRequirementIdFromDb(r.requirementId);
  if (requirementId == null) return null;
  return PracticeDocumentWaiver(
    id: r.id,
    practiceDossierId: r.practiceDossierId,
    requirementId: requirementId,
    note: r.note,
    waivedByStaffId: r.waivedByStaffId,
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
  );
}

StaffInternalNote mapStaffNoteRowToDomain(StaffInternalNoteRow r) {
  return StaffInternalNote(
    id: r.id,
    studentId: r.studentId,
    body: r.body,
    createdAt: r.createdAt,
    authorStaffName: r.authorDisplayName,
    category: _enumByName(
      StaffNoteCategory.values,
      r.category,
      StaffNoteCategory.general,
    ),
  );
}

BackofficeActivityEvent mapActivityRowToDomain(BackofficeActivityEventRow r) {
  return BackofficeActivityEvent(
    id: r.id,
    studentId: r.studentId,
    occurredAt: r.occurredAt,
    type: _enumByName(
      BackofficeActivityType.values,
      r.eventType,
      BackofficeActivityType.paymentAdded,
    ),
    title: r.title,
    description: r.description,
  );
}
