import 'backoffice_enums.dart';
import 'ids.dart';

/// Tentativo d’esame (teoria o pratica) con storico.
///
/// Tabella tipica: `exam_attempts` con indice su `(student_id, exam_type, attempt_number)`.
class ExamAttempt {
  const ExamAttempt({
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

  final ExamAttemptId id;
  final StudentId studentId;
  final ExamAttemptType examType;

  /// 1-based: primo tentativo teoria, secondo, ecc.
  final int attemptNumber;
  final ExamAttemptResult result;
  final DateTime? examDate;

  /// Voto o etichetta testuale (es. “30”, “Idoneo”) — normalizzare in fase UI.
  final String? scoreOrLabel;

  /// Identificativo sessione ministeriale / locale se necessario.
  final String? externalSessionId;
  final String? notes;
  final StaffId? recordedByStaffId;
  final DateTime? createdAt;
}

/// Riepilogo esami per cartella studente (deriva da query aggregata).
class StudentExamSummary {
  const StudentExamSummary({
    required this.studentId,
    required this.theoryAttempts,
    required this.practicalAttempts,
  });

  final StudentId studentId;
  final List<ExamAttempt> theoryAttempts;
  final List<ExamAttempt> practicalAttempts;

  ExamAttempt? get latestTheory => _latestExamByDate(theoryAttempts);

  ExamAttempt? get latestPractical => _latestExamByDate(practicalAttempts);
}

ExamAttempt? _latestExamByDate(List<ExamAttempt> list) {
  if (list.isEmpty) return null;
  final sorted = List<ExamAttempt>.from(list)
    ..sort((a, b) {
      final da = a.examDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      final db = b.examDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      return db.compareTo(da);
    });
  return sorted.first;
}
