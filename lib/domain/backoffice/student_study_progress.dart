import '../../models/license_models.dart';
import 'backoffice_enums.dart';
import 'ids.dart';

/// Lezione del programma assegnata allo studente (chiave naturale: studente + categoria + n. lezione).
class AssignedLesson {
  const AssignedLesson({
    required this.studentId,
    required this.categoryId,
    required this.lessonNumber,
    required this.status,
    this.assignedAt,
    this.completedAt,
    this.assignedByStaffId,
    this.schoolNotes,
  });

  final StudentId studentId;
  final LicenseCategoryId categoryId;
  final int lessonNumber;
  final AssignedLessonStatus status;
  final DateTime? assignedAt;
  final DateTime? completedAt;
  final StaffId? assignedByStaffId;

  /// Nota didattica / amministrativa visibile in backoffice.
  final String? schoolNotes;
}

/// Riferimento granularità singola scheda quiz — corrisponde alle chiavi usate nell’app
/// (`lesson:{n}:sheet:{s}`) e al mock [StudyAccessRepository].
class LessonQuizSheetUnlock {
  const LessonQuizSheetUnlock({
    required this.studentId,
    required this.categoryId,
    required this.lessonNumber,
    required this.sheetNumber,
    required this.unlocked,
    this.unlockedAt,
    this.unlockedByStaffId,
    this.revokedAt,
  });

  final StudentId studentId;
  final LicenseCategoryId categoryId;
  final int lessonNumber;
  final int sheetNumber;
  final bool unlocked;
  final DateTime? unlockedAt;
  final StaffId? unlockedByStaffId;
  final DateTime? revokedAt;
}

/// Abilitazione quiz esame per categoria (flag per studente).
class ExamQuizAccess {
  const ExamQuizAccess({
    required this.studentId,
    required this.categoryId,
    required this.examUnlocked,
    this.updatedAt,
    this.updatedByStaffId,
  });

  final StudentId studentId;
  final LicenseCategoryId categoryId;
  final bool examUnlocked;
  final DateTime? updatedAt;
  final StaffId? updatedByStaffId;
}

/// Argomento ripasso errori abilitato (per lezione, nella stessa logica di [errorReviewTopic]).
class ErrorReviewTopicAssignment {
  const ErrorReviewTopicAssignment({
    required this.studentId,
    required this.categoryId,
    required this.lessonNumber,
    required this.topicUnlocked,
    this.updatedAt,
    this.updatedByStaffId,
    this.didacticNote,
  });

  final StudentId studentId;
  final LicenseCategoryId categoryId;
  final int lessonNumber;
  final bool topicUnlocked;
  final DateTime? updatedAt;
  final StaffId? updatedByStaffId;
  final String? didacticNote;
}

/// Vista aggregata “percorso studio” per pannelli admin / API `GET /students/:id/progress`.
/// In produzione spesso costruita con join; qui come DTO comodo per UI e mock.
class StudentStudyProgressBundle {
  const StudentStudyProgressBundle({
    required this.studentId,
    required this.assignedLessons,
    required this.sheetUnlocks,
    required this.examAccessByCategory,
    required this.errorReviewAssignments,
    this.globalProgressNotes,
  });

  final StudentId studentId;
  final List<AssignedLesson> assignedLessons;
  final List<LessonQuizSheetUnlock> sheetUnlocks;
  final List<ExamQuizAccess> examAccessByCategory;
  final List<ErrorReviewTopicAssignment> errorReviewAssignments;

  /// Nota sintetica segreteria sul percorso (es. “attesa recupero L7”).
  final String? globalProgressNotes;
}
