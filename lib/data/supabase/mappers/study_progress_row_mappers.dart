import '../../../domain/backoffice/backoffice.dart';
import '../../../models/license_models.dart';

/// Righe `lesson_quiz_sheet_unlocks` → dominio.
LessonQuizSheetUnlock mapLessonQuizSheetUnlockFromJson(Map<String, dynamic> j) {
  return LessonQuizSheetUnlock(
    studentId: j['student_id'] as String,
    categoryId: _enumByName(
      LicenseCategoryId.values,
      j['license_category'] as String,
      LicenseCategoryId.motore,
    ),
    lessonNumber: j['lesson_number'] as int,
    sheetNumber: j['sheet_number'] as int,
    unlocked: j['unlocked'] as bool? ?? false,
    unlockedAt: _parseTs(j['unlocked_at']),
    unlockedByStaffId: j['unlocked_by_staff_id'] as String?,
    revokedAt: _parseTs(j['revoked_at']),
  );
}

/// Righe `exam_quiz_access` → dominio.
ExamQuizAccess mapExamQuizAccessFromJson(Map<String, dynamic> j) {
  return ExamQuizAccess(
    studentId: j['student_id'] as String,
    categoryId: _enumByName(
      LicenseCategoryId.values,
      j['license_category'] as String,
      LicenseCategoryId.motore,
    ),
    examUnlocked: j['exam_unlocked'] as bool? ?? false,
    updatedAt: _parseTs(j['updated_at']),
    updatedByStaffId: j['updated_by_staff_id'] as String?,
  );
}

/// Righe `error_review_topic_assignments` → dominio.
ErrorReviewTopicAssignment mapErrorReviewTopicFromJson(Map<String, dynamic> j) {
  return ErrorReviewTopicAssignment(
    studentId: j['student_id'] as String,
    categoryId: _enumByName(
      LicenseCategoryId.values,
      j['license_category'] as String,
      LicenseCategoryId.motore,
    ),
    lessonNumber: j['lesson_number'] as int,
    topicUnlocked: j['topic_unlocked'] as bool? ?? false,
    updatedAt: _parseTs(j['updated_at']),
    updatedByStaffId: j['updated_by_staff_id'] as String?,
    didacticNote: j['didactic_note'] as String?,
  );
}

T _enumByName<T extends Enum>(List<T> values, String raw, T fallback) {
  for (final v in values) {
    if (v.name == raw) return v;
  }
  return fallback;
}

DateTime? _parseTs(Object? v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  return null;
}
