import 'ids.dart';

/// Categoria nota interna staff (per filtri e politiche future).
enum StaffNoteCategory {
  general,
  accounting,
  study,
  exam,
}

/// Nota interna strutturata — tabella tipica `student_staff_notes` (Supabase).
///
/// Non esposta all’app allievo; solo backoffice / API segreteria.
class StaffInternalNote {
  const StaffInternalNote({
    required this.id,
    required this.studentId,
    required this.body,
    required this.createdAt,
    this.authorStaffName,
    this.category = StaffNoteCategory.general,
  });

  final StaffInternalNoteId id;
  final StudentId studentId;

  /// Testo libero (markdown futuro opzionale).
  final String body;
  final DateTime createdAt;

  /// Nome legibile autore (mock); in DB `recorded_by_staff_id` + join.
  final String? authorStaffName;
  final StaffNoteCategory category;
}
