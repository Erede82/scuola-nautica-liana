import 'backoffice_enums.dart';
import 'ids.dart';

/// Fascicolo documenti / pratica patente (dopo superamento esami, dove applicabile).
///
/// Separato dalla [StudentProfile] per evitare tabelle larghe; join su `student_id`.
class PracticeLicenseDossier {
  const PracticeLicenseDossier({
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

  final PracticeDossierId id;
  final StudentId studentId;

  /// `new_license` | `renewal` | `duplicate` (DB `practice_dossiers.practice_type`).
  final String? practiceType;
  final DateTime? registrationDate;
  final int? registryYear;
  final int? registryNumber;
  final String? registryCode;

  /// Numero pratica motorizzazione / codice interno.
  final String? practiceNumber;
  final String? licenseNumber;
  final DateTime? issueDate;
  final DateTime? expirationDate;
  final LicenseDocumentStatus documentStatus;
  final PracticeFileStatus practiceStatus;
  final String? authorityNotes;
  final DateTime? lastCheckedAt;
  final StaffId? updatedByStaffId;
}

class StudentDocument {
  const StudentDocument({
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
  final StudentId studentId;
  final PracticeDossierId? practiceDossierId;
  final String documentType;
  final String title;
  final String? storagePath;
  final String? fileName;
  final String? mimeType;
  final String status;
  final DateTime? expiresAt;
  final String? notes;
  final StaffId? uploadedByStaffId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

class StudentPhoto {
  const StudentPhoto({
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
  final StudentId studentId;
  final String photoKind;
  final String? storagePath;
  final String? fileName;
  final String? mimeType;
  final String? notes;
  final StaffId? uploadedByStaffId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}
