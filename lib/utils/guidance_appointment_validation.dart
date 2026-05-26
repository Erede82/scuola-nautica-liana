import 'package:flutter/material.dart';

import '../domain/backoffice/backoffice.dart';

/// Due intervalli [start, end) si sovrappongono se condividono almeno un istante.
bool guidanceIntervalsOverlap(
  DateTime startA,
  DateTime endA,
  DateTime startB,
  DateTime endB,
) {
  return startA.isBefore(endB) && endA.isAfter(startB);
}

DateTime guidanceEffectiveStart(GuidanceListItem item) {
  if (item.startTime != null) return item.startTime!.toLocal();
  return DateTime(
    item.lessonDate.year,
    item.lessonDate.month,
    item.lessonDate.day,
    9,
  );
}

DateTime guidanceEffectiveEnd(GuidanceListItem item) {
  if (item.endTime != null) return item.endTime!.toLocal();
  final start = guidanceEffectiveStart(item);
  return start.add(const Duration(hours: 1));
}

/// Controllo sovrapposizioni V1 (client-side su elenco directory).
///
/// Restituisce messaggio d’errore localizzato, oppure `null` se lo slot è libero.
String? validateGuidanceSlotConflict({
  required List<GuidanceListItem> existing,
  required StudentId studentId,
  required String instructorName,
  required DateTime start,
  required DateTime end,
  AppointmentId? excludeAppointmentId,
}) {
  final instructor = instructorName.trim();
  for (final g in existing) {
    if (g.lessonType != GuidanceLessonType.practiceSea) continue;
    if (excludeAppointmentId != null && g.appointmentId == excludeAppointmentId) {
      continue;
    }
    final gStart = guidanceEffectiveStart(g);
    final gEnd = guidanceEffectiveEnd(g);
    if (!guidanceIntervalsOverlap(start, end, gStart, gEnd)) continue;

    if (g.studentId == studentId) {
      return 'Questo allievo ha già una guida in questa fascia oraria.';
    }
    final gInst = g.instructorName?.trim() ?? '';
    if (gInst.isNotEmpty &&
        instructor.isNotEmpty &&
        gInst.toLowerCase() == instructor.toLowerCase()) {
      return 'Questo istruttore ha già una guida in questa fascia oraria.';
    }
    return 'Guida non prenotabile: questa fascia oraria è già occupata da un altro allievo.';
  }
  return null;
}

TimeOfDay guidanceAddOneHour(TimeOfDay time) {
  final totalMinutes = time.hour * 60 + time.minute + 60;
  return TimeOfDay(hour: (totalMinutes ~/ 60) % 24, minute: totalMinutes % 60);
}
