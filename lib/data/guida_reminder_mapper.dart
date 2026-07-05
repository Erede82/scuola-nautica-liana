import '../domain/backoffice/backoffice_enums.dart';
import '../domain/backoffice/guidance_appointment.dart';
import '../models/guida_reminder.dart';
import '../widgets/backoffice/backoffice_formatters.dart';

/// Converte appuntamenti Agenda (`guidance_appointments`) in promemoria area Guida.
abstract final class GuidaReminderMapper {
  static GuidaReminder fromAppointment(GuidanceAppointment appointment) {
    final scheduledAt = appointment.startTime ?? appointment.lessonDate;
    final title = BackofficeFormatters.lessonType(appointment.lessonType);
    final instructorRaw = appointment.instructorName?.trim();
    final instructor = (instructorRaw != null && instructorRaw.isNotEmpty)
        ? instructorRaw
        : 'Da definire';
    final notes = appointment.notes?.trim();
    final status = _mapStatus(appointment);
    final isUnread = _isUnread(appointment, status);

    return GuidaReminder(
      id: appointment.id,
      title: title,
      instructorName: instructor,
      scheduledAt: scheduledAt,
      status: status,
      shortMessage: _shortMessage(appointment, notes),
      longMessage: (notes != null && notes.isNotEmpty) ? notes : null,
      isUnread: isUnread,
      requiresReading: status == GuidaReminderStatus.daLeggere,
      category: _mapCategory(appointment.lessonType),
      timeDisplayOverride: appointment.startTime == null
          ? 'Orario da definire'
          : null,
    );
  }

  static GuidaReminderStatus _mapStatus(GuidanceAppointment appointment) {
    switch (appointment.completionOutcome) {
      case AppointmentCompletionOutcome.attended:
      case AppointmentCompletionOutcome.absent:
        return GuidaReminderStatus.completato;
      case AppointmentCompletionOutcome.rescheduled:
      case AppointmentCompletionOutcome.pending:
        if (appointment.reminderStatus ==
            AppointmentReminderStatus.acknowledged) {
          return GuidaReminderStatus.confermato;
        }
        if (appointment.reminderStatus == AppointmentReminderStatus.sent ||
            appointment.reminderStatus == AppointmentReminderStatus.scheduled) {
          return GuidaReminderStatus.daLeggere;
        }
        return GuidaReminderStatus.confermato;
    }
  }

  static bool _isUnread(
    GuidanceAppointment appointment,
    GuidaReminderStatus status,
  ) {
    if (status == GuidaReminderStatus.completato) return false;
    return appointment.reminderStatus != AppointmentReminderStatus.acknowledged;
  }

  static String _shortMessage(GuidanceAppointment appointment, String? notes) {
    if (notes != null && notes.isNotEmpty) return notes;
    switch (appointment.completionOutcome) {
      case AppointmentCompletionOutcome.attended:
        return 'Lezione completata.';
      case AppointmentCompletionOutcome.absent:
        return 'Assenza registrata per questa lezione.';
      case AppointmentCompletionOutcome.rescheduled:
        return 'Appuntamento riprogrammato.';
      case AppointmentCompletionOutcome.pending:
        return 'Guida programmata dalla scuola.';
    }
  }

  static GuidaReminderCategory? _mapCategory(GuidanceLessonType lessonType) {
    switch (lessonType) {
      case GuidanceLessonType.theory:
      case GuidanceLessonType.examPrep:
        return GuidaReminderCategory.teoria;
      case GuidanceLessonType.practiceSea:
      case GuidanceLessonType.practiceSimulator:
        return GuidaReminderCategory.lezionePratica;
      case GuidanceLessonType.officeMeeting:
        return GuidaReminderCategory.documenti;
      case GuidanceLessonType.other:
        return GuidaReminderCategory.generale;
    }
  }
}
