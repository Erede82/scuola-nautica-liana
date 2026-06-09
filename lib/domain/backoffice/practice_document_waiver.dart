import 'ids.dart';
import 'practice_document_requirements.dart';

/// Esenzione staff per un requisito documentale della checklist pratica.
class PracticeDocumentWaiver {
  const PracticeDocumentWaiver({
    required this.id,
    required this.practiceDossierId,
    required this.requirementId,
    this.note,
    this.waivedByStaffId,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final PracticeDossierId practiceDossierId;
  final PracticeDocumentRequirementId requirementId;
  final String? note;
  final StaffId? waivedByStaffId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

/// Converte valore DB `requirement_id` → enum dominio.
PracticeDocumentRequirementId? practiceDocumentRequirementIdFromDb(String raw) {
  final trimmed = raw.trim();
  for (final id in PracticeDocumentRequirementId.values) {
    if (id.name == trimmed) return id;
  }
  return null;
}
