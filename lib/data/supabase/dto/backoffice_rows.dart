// Righe PostgREST / Supabase (snake_case) — non usare direttamente nell’UI.
// Mappare con lib/data/supabase/mappers/backoffice_row_mappers.dart → dominio.

/// Riga `public.students`.
///
/// Produzione: `address` testo (via), `fiscal_code`, `notes`, colonne flatten
/// `city` / `province` / `cap` / `birth_place` / `gender`.
/// In lettura restano fallback verso chiavi legacy (`tax_code`, `internal_notes`, `address` jsonb).
class StudentRow {
  const StudentRow({
    required this.id,
    this.userId,
    required this.firstName,
    required this.lastName,
    this.phone,
    this.email,
    this.birthDate,
    this.fiscalCode,
    this.birthPlace,
    this.gender,

    /// Colonna `address` come testo (via, piazza, civico).
    this.addressStreet,
    this.city,
    this.province,
    this.cap,

    /// JSON legacy opzionale se `address` era jsonb.
    this.legacyAddressJson,
    this.enrolledCoursePath,
    required this.enrolledLicenseCategory,
    required this.registrationStatus,
    this.onboardingStatus,
    this.firstContactedAt,
    this.onboardingNotes,

    /// Note staff: colonna `notes` (fallback lettura `internal_notes`).
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.practiceDossierType,
  });

  final String id;

  /// FK verso `auth.users.id` — colonna DB `public.students.user_id`.
  final String? userId;
  final String firstName;
  final String lastName;
  final String? phone;
  final String? email;
  final DateTime? birthDate;
  final String? fiscalCode;
  final String? birthPlace;
  final String? gender;
  final String? addressStreet;
  final String? city;
  final String? province;
  final String? cap;
  final Map<String, dynamic>? legacyAddressJson;

  /// Percorso iscrizione (`entro_12_miglia`, `d1`, `entro_12_miglia_vela`).
  /// Se null (API legacy), inferire da [enrolledLicenseCategory] nel mapper.
  final String? enrolledCoursePath;

  final String enrolledLicenseCategory;
  final String registrationStatus;
  final String? onboardingStatus;
  final DateTime? firstContactedAt;
  final String? onboardingNotes;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Da embed `practice_dossiers(practice_type)` in elenco allievi.
  final String? practiceDossierType;

  factory StudentRow.fromJson(Map<String, dynamic> j) {
    final addrRaw = j['address'];
    String? addressStreet;
    Map<String, dynamic>? legacyAddressJson;
    if (addrRaw is String) {
      final t = addrRaw.trim();
      addressStreet = t.isEmpty ? null : t;
    } else if (addrRaw is Map) {
      legacyAddressJson = Map<String, dynamic>.from(addrRaw);
    }

    final fc = j['fiscal_code'] as String? ?? j['tax_code'] as String?;

    String? notesFromJson() {
      final n = j['notes'] as String?;
      if (n != null && n.trim().isNotEmpty) return n.trim();
      final legacy = j['internal_notes'] as String?;
      if (legacy != null && legacy.trim().isNotEmpty) return legacy.trim();
      return null;
    }

    return StudentRow(
      id: j['id'] as String,
      userId: (j['user_id'] ?? j['auth_user_id']) as String?,
      firstName: j['first_name'] as String,
      lastName: j['last_name'] as String,
      phone: j['phone'] as String?,
      email: j['email'] as String?,
      birthDate: _parseDate(j['birth_date']),
      fiscalCode: fc,
      birthPlace: j['birth_place'] as String?,
      gender: j['gender'] as String?,
      addressStreet: addressStreet,
      city: j['city'] as String?,
      province: j['province'] as String?,
      cap: j['cap'] as String?,
      legacyAddressJson: legacyAddressJson,
      enrolledCoursePath: j['enrolled_course_path'] as String?,
      enrolledLicenseCategory: j['enrolled_license_category'] as String? ?? '',
      registrationStatus: () {
        final r = j['registration_status'] as String?;
        if (r == null || r.trim().isEmpty) return 'pending';
        return r.trim();
      }(),
      onboardingStatus: j['onboarding_status'] as String?,
      firstContactedAt: _parseTs(j['first_contacted_at']),
      onboardingNotes: j['onboarding_notes'] as String?,
      notes: notesFromJson(),
      createdAt: _parseTs(j['created_at']),
      updatedAt: _parseTs(j['updated_at']),
      practiceDossierType: _practiceTypeFromEmbed(j['practice_dossiers']),
    );
  }

  static String? _practiceTypeFromEmbed(dynamic raw) {
    if (raw is Map) {
      return raw['practice_type'] as String?;
    }
    if (raw is List && raw.isNotEmpty) {
      final first = raw.first;
      if (first is Map) return first['practice_type'] as String?;
    }
    return null;
  }
}

class StudentFinancialSummaryRow {
  const StudentFinancialSummaryRow({
    required this.studentId,
    required this.registrationFeeCents,
    required this.currencyCode,
    required this.totalPaidCents,
    required this.remainingBalanceCents,
    this.accountingNotes,
    this.lastUpdatedAt,
  });

  final String studentId;
  final int registrationFeeCents;
  final String currencyCode;
  final int totalPaidCents;
  final int remainingBalanceCents;
  final String? accountingNotes;
  final DateTime? lastUpdatedAt;

  factory StudentFinancialSummaryRow.fromJson(Map<String, dynamic> j) {
    return StudentFinancialSummaryRow(
      studentId: j['student_id'] as String,
      registrationFeeCents: (j['registration_fee_cents'] as num?)?.toInt() ?? 0,
      currencyCode: j['currency_code'] as String? ?? 'EUR',
      totalPaidCents: (j['total_paid_cents'] as num?)?.toInt() ?? 0,
      remainingBalanceCents:
          (j['remaining_balance_cents'] as num?)?.toInt() ?? 0,
      accountingNotes: j['accounting_notes'] as String?,
      lastUpdatedAt: _parseTs(j['last_updated_at']),
    );
  }
}

class PaymentRow {
  const PaymentRow({
    required this.id,
    required this.studentId,
    required this.amountCents,
    required this.currencyCode,
    required this.receivedAt,
    required this.method,
    this.receiptReference,
    this.fiscalReceiptNumber,
    this.notes,
    this.recordedByStaffId,
  });

  final String id;
  final String studentId;
  final int amountCents;
  final String currencyCode;
  final DateTime receivedAt;
  final String method;
  final String? receiptReference;
  final String? fiscalReceiptNumber;
  final String? notes;
  final String? recordedByStaffId;

  factory PaymentRow.fromJson(Map<String, dynamic> j) {
    return PaymentRow(
      id: j['id']?.toString() ?? '',
      studentId: j['student_id']?.toString() ?? '',
      amountCents: (j['amount_cents'] as num?)?.toInt() ?? 0,
      currencyCode: j['currency_code'] as String? ?? 'EUR',
      receivedAt:
          _parseTs(j['received_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      method: (j['method'] as String?) ?? 'other',
      fiscalReceiptNumber: j['fiscal_receipt_number'] as String?,
      receiptReference: j['receipt_reference'] as String?,
      notes: j['notes'] as String?,
      recordedByStaffId: j['recorded_by_staff_id'] as String?,
    );
  }
}

class GuidanceAppointmentRow {
  const GuidanceAppointmentRow({
    required this.id,
    required this.studentId,
    required this.lessonDate,
    this.startTime,
    this.endTime,
    this.instructorName,
    this.instructorStaffId,
    required this.lessonType,
    required this.reminderStatus,
    required this.completionOutcome,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String studentId;
  final DateTime lessonDate;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? instructorName;
  final String? instructorStaffId;
  final String lessonType;
  final String reminderStatus;
  final String completionOutcome;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory GuidanceAppointmentRow.fromJson(Map<String, dynamic> j) {
    return GuidanceAppointmentRow(
      id: j['id']?.toString() ?? '',
      studentId: j['student_id']?.toString() ?? '',
      lessonDate:
          _parseDate(j['lesson_date']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      startTime: _parseTs(j['start_time']),
      endTime: _parseTs(j['end_time']),
      instructorName: j['instructor_name'] as String?,
      instructorStaffId: j['instructor_staff_id'] as String?,
      lessonType: (j['lesson_type'] as String?) ?? 'other',
      reminderStatus: (j['reminder_status'] as String?) ?? 'none',
      completionOutcome: (j['completion_outcome'] as String?) ?? 'pending',
      notes: j['notes'] as String?,
      createdAt: _parseTs(j['created_at']),
      updatedAt: _parseTs(j['updated_at']),
    );
  }
}

class ExamAttemptRow {
  const ExamAttemptRow({
    required this.id,
    required this.studentId,
    required this.examType,
    required this.attemptNumber,
    required this.result,
    this.examDate,
    this.scoreOrLabel,
    this.externalSessionId,
    this.notes,
    this.recordedByStaffId,
    this.createdAt,
  });

  final String id;
  final String studentId;
  final String examType;
  final int attemptNumber;
  final String result;
  final DateTime? examDate;
  final String? scoreOrLabel;
  final String? externalSessionId;
  final String? notes;
  final String? recordedByStaffId;
  final DateTime? createdAt;

  factory ExamAttemptRow.fromJson(Map<String, dynamic> j) {
    return ExamAttemptRow(
      id: j['id'] as String,
      studentId: j['student_id'] as String,
      examType: j['exam_type'] as String,
      attemptNumber: j['attempt_number'] as int,
      result: j['result'] as String,
      examDate: _parseDate(j['exam_date']),
      scoreOrLabel: j['score_or_label'] as String?,
      externalSessionId: j['external_session_id'] as String?,
      notes: j['notes'] as String?,
      recordedByStaffId: j['recorded_by_staff_id'] as String?,
      createdAt: _parseTs(j['created_at']),
    );
  }
}

class PracticeDossierRow {
  const PracticeDossierRow({
    required this.id,
    required this.studentId,
    this.practiceType,
    this.registrationDate,
    this.registryYear,
    this.registryNumber,
    this.registryCode,
    this.practiceNumber,
    this.licenseNumber,
    this.issueDate,
    this.expirationDate,
    required this.documentStatus,
    required this.practiceStatus,
    this.authorityNotes,
    this.lastCheckedAt,
    this.updatedByStaffId,
  });

  final String id;
  final String studentId;
  final String? practiceType;
  final DateTime? registrationDate;
  final int? registryYear;
  final int? registryNumber;
  final String? registryCode;
  final String? practiceNumber;
  final String? licenseNumber;
  final DateTime? issueDate;
  final DateTime? expirationDate;
  final String documentStatus;
  final String practiceStatus;
  final String? authorityNotes;
  final DateTime? lastCheckedAt;
  final String? updatedByStaffId;

  factory PracticeDossierRow.fromJson(Map<String, dynamic> j) {
    return PracticeDossierRow(
      id: j['id'] as String,
      studentId: j['student_id'] as String,
      practiceType: j['practice_type'] as String?,
      registrationDate: _parseDate(j['registration_date']),
      registryYear: (j['registry_year'] as num?)?.toInt(),
      registryNumber: (j['registry_number'] as num?)?.toInt(),
      registryCode: j['registry_code'] as String?,
      practiceNumber: j['practice_number'] as String?,
      licenseNumber: j['license_number'] as String?,
      issueDate: _parseDate(j['issue_date']),
      expirationDate: _parseDate(j['expiration_date']),
      documentStatus: j['document_status'] as String,
      practiceStatus: j['practice_status'] as String,
      authorityNotes: j['authority_notes'] as String?,
      lastCheckedAt: _parseTs(j['last_checked_at']),
      updatedByStaffId: j['updated_by_staff_id'] as String?,
    );
  }
}

class StaffInternalNoteRow {
  const StaffInternalNoteRow({
    required this.id,
    required this.studentId,
    required this.body,
    required this.category,
    this.authorStaffId,
    this.authorDisplayName,
    required this.createdAt,
  });

  final String id;
  final String studentId;
  final String body;
  final String category;
  final String? authorStaffId;
  final String? authorDisplayName;
  final DateTime createdAt;

  factory StaffInternalNoteRow.fromJson(Map<String, dynamic> j) {
    return StaffInternalNoteRow(
      id: j['id'] as String,
      studentId: j['student_id'] as String,
      body: j['body'] as String,
      category: j['category'] as String? ?? 'general',
      authorStaffId: j['author_staff_id'] as String?,
      authorDisplayName: j['author_display_name'] as String?,
      createdAt:
          _parseTs(j['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class BackofficeActivityEventRow {
  const BackofficeActivityEventRow({
    required this.id,
    required this.studentId,
    required this.eventType,
    required this.title,
    this.description,
    this.actorStaffId,
    this.actorDisplayName,
    required this.occurredAt,
  });

  final String id;
  final String studentId;
  final String eventType;
  final String title;
  final String? description;
  final String? actorStaffId;
  final String? actorDisplayName;
  final DateTime occurredAt;

  factory BackofficeActivityEventRow.fromJson(Map<String, dynamic> j) {
    return BackofficeActivityEventRow(
      id: j['id'] as String,
      studentId: j['student_id'] as String,
      eventType: j['event_type'] as String,
      title: j['title'] as String,
      description: j['description'] as String?,
      actorStaffId: j['actor_staff_id'] as String?,
      actorDisplayName: j['actor_display_name'] as String?,
      occurredAt:
          _parseTs(j['occurred_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class StudentDocumentRow {
  const StudentDocumentRow({
    required this.id,
    required this.studentId,
    this.practiceDossierId,
    required this.documentType,
    required this.title,
    this.storagePath,
    this.fileName,
    this.mimeType,
    required this.status,
    this.expiresAt,
    this.notes,
    this.uploadedByStaffId,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String studentId;
  final String? practiceDossierId;
  final String documentType;
  final String title;
  final String? storagePath;
  final String? fileName;
  final String? mimeType;
  final String status;
  final DateTime? expiresAt;
  final String? notes;
  final String? uploadedByStaffId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory StudentDocumentRow.fromJson(Map<String, dynamic> j) {
    return StudentDocumentRow(
      id: j['id'] as String,
      studentId: j['student_id'] as String,
      practiceDossierId: j['practice_dossier_id'] as String?,
      documentType: j['document_type'] as String,
      title: j['title'] as String,
      storagePath: j['storage_path'] as String?,
      fileName: j['file_name'] as String?,
      mimeType: j['mime_type'] as String?,
      status: j['status'] as String,
      expiresAt: _parseTs(j['expires_at']),
      notes: j['notes'] as String?,
      uploadedByStaffId: j['uploaded_by_staff_id'] as String?,
      createdAt: _parseTs(j['created_at']),
      updatedAt: _parseTs(j['updated_at']),
    );
  }
}

class StudentPhotoRow {
  const StudentPhotoRow({
    required this.id,
    required this.studentId,
    required this.photoKind,
    this.storagePath,
    this.fileName,
    this.mimeType,
    this.notes,
    this.uploadedByStaffId,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String studentId;
  final String photoKind;
  final String? storagePath;
  final String? fileName;
  final String? mimeType;
  final String? notes;
  final String? uploadedByStaffId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory StudentPhotoRow.fromJson(Map<String, dynamic> j) {
    return StudentPhotoRow(
      id: j['id'] as String,
      studentId: j['student_id'] as String,
      photoKind: j['photo_kind'] as String,
      storagePath: j['storage_path'] as String?,
      fileName: j['file_name'] as String?,
      mimeType: j['mime_type'] as String?,
      notes: j['notes'] as String?,
      uploadedByStaffId: j['uploaded_by_staff_id'] as String?,
      createdAt: _parseTs(j['created_at']),
      updatedAt: _parseTs(j['updated_at']),
    );
  }
}

DateTime? _parseTs(Object? v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  return null;
}

DateTime? _parseDate(Object? v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is String) {
    final d = DateTime.tryParse(v);
    if (d != null) return DateTime(d.year, d.month, d.day);
  }
  return null;
}
