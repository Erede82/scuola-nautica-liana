import 'package:flutter/foundation.dart';

import '../models/guida_reminder.dart';

/// Notifica il badge non letti sulla home (aggiornato da [GuidaRemindersLoader]).
abstract final class GuidaBadgeNotifier {
  static final ValueNotifier<int> unreadCount = ValueNotifier(0);

  static int _countFor(Iterable<GuidaReminder> list) {
    return list.where((r) => r.appearsUnreadForBadge).length;
  }

  static void refreshFrom(List<GuidaReminder> reminders) {
    unreadCount.value = _countFor(reminders);
  }
}
