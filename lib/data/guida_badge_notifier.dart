import 'package:flutter/foundation.dart';

import '../models/guida_reminder.dart';
import 'guida_reminders_mock.dart';

/// Notifica il badge non letti sulla home (sostituibile con stream da Supabase).
abstract final class GuidaBadgeNotifier {
  static final ValueNotifier<int> unreadCount = ValueNotifier(
    _countFor(GuidaRemindersMock.seeded),
  );

  static int _countFor(Iterable<GuidaReminder> list) {
    return list.where((r) => r.appearsUnreadForBadge).length;
  }

  static void refreshFrom(List<GuidaReminder> reminders) {
    unreadCount.value = _countFor(reminders);
  }
}
