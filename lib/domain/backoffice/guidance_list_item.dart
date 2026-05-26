import 'backoffice_enums.dart';
import 'guidance_appointment.dart';
import 'ids.dart';

/// Riga directory guide/agenda (lettura-only): appuntamento + identificazione minima allievo.
class GuidanceListItem {
  const GuidanceListItem({
    required this.appointmentId,
    required this.studentId,
    required this.studentFullName,
    this.studentEmail,
    this.studentPhone,
    required this.lessonDate,
    this.startTime,
    this.endTime,
    this.instructorName,
    this.instructorStaffId,
    required this.lessonType,
    required this.reminderStatus,
    required this.completionOutcome,
    this.notes,
  });

  final AppointmentId appointmentId;
  final StudentId studentId;
  final String studentFullName;
  final String? studentEmail;
  final String? studentPhone;

  final DateTime lessonDate;
  final DateTime? startTime;
  final DateTime? endTime;

  final String? instructorName;
  final StaffId? instructorStaffId;

  final GuidanceLessonType lessonType;
  final AppointmentReminderStatus reminderStatus;
  final AppointmentCompletionOutcome completionOutcome;

  final String? notes;

  /// Momento locale usato per ordinamento e confronto “futuro/passato”.
  DateTime get effectiveSortKey {
    if (startTime != null) return startTime!.toLocal();
    return DateTime(lessonDate.year, lessonDate.month, lessonDate.day, 9);
  }

  bool get isLessonInFuture => effectiveSortKey.isAfter(DateTime.now());

  bool get isLessonInPast => effectiveSortKey.isBefore(DateTime.now());

  bool get lacksInstructor {
    final n = instructorName?.trim();
    if (n != null && n.isNotEmpty) return false;
    final s = instructorStaffId?.trim();
    if (s != null && s.isNotEmpty) return false;
    return true;
  }

  bool get isOutcomePending =>
      completionOutcome == AppointmentCompletionOutcome.pending;

  factory GuidanceListItem.fromGuidanceAppointment(
    GuidanceAppointment a, {
    required String studentFullName,
    String? studentEmail,
    String? studentPhone,
  }) {
    return GuidanceListItem(
      appointmentId: a.id,
      studentId: a.studentId,
      studentFullName: studentFullName,
      studentEmail: studentEmail,
      studentPhone: studentPhone,
      lessonDate: a.lessonDate,
      startTime: a.startTime,
      endTime: a.endTime,
      instructorName: a.instructorName,
      instructorStaffId: a.instructorStaffId,
      lessonType: a.lessonType,
      reminderStatus: a.reminderStatus,
      completionOutcome: a.completionOutcome,
      notes: a.notes,
    );
  }
}
