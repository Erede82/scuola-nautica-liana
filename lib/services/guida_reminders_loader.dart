import '../data/guida_badge_notifier.dart';
import '../models/guida_reminder.dart';
import '../repositories/student_guidance_repository.dart';
import 'demo_student_enrollment.dart';

/// Carica promemoria Guida reali e aggiorna il badge Home.
abstract final class GuidaRemindersLoader {
  static Future<List<GuidaReminder>> loadForCurrentStudent() async {
    final studentId = studentSession.value?.studentId;
    if (studentId == null) {
      GuidaBadgeNotifier.refreshFrom(const []);
      return const [];
    }

    try {
      final reminders = await studentGuidanceRepository.listForStudent(
        studentId,
      );
      GuidaBadgeNotifier.refreshFrom(reminders);
      return reminders;
    } catch (_) {
      GuidaBadgeNotifier.refreshFrom(const []);
      return const [];
    }
  }
}
