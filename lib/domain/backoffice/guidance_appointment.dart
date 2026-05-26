import 'backoffice_enums.dart';
import 'ids.dart';

/// Appuntamento lezione / promemoria — tabella `appointments` o `lesson_sessions`.
///
/// **App studente:** vista “Guida” può leggere subset (data, tipo, stato promemoria).
/// **Backoffice:** CRUD completo, assegnazione docente, esito.
class GuidanceAppointment {
  const GuidanceAppointment({
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

  final AppointmentId id;
  final StudentId studentId;

  /// Giorno dell’appuntamento (timezone sede).
  final DateTime lessonDate;

  /// Orario locale; opzionale se full-day.
  final DateTime? startTime;
  final DateTime? endTime;

  final String? instructorName;
  final StaffId? instructorStaffId;

  final GuidanceLessonType lessonType;
  final AppointmentReminderStatus reminderStatus;
  final AppointmentCompletionOutcome completionOutcome;

  /// Note visibili a docente/segreteria; policy su visibilità studente da definire.
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}
