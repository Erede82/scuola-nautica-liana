/// Official Italian civil time (`Europe/Rome`) for presentation.
///
/// Converts an absolute [DateTime] instant to wall-clock components under
/// EU DST rules used by Italy (CET UTC+1 / CEST UTC+2).
///
/// Presentation only — do not use converted values for sorting or storage.
abstract final class EuropeRomeTime {
  /// Returns a [DateTime] whose calendar fields (year…second) are the
  /// Europe/Rome wall clock for [instant]. The result is always `isUtc == false`
  /// and must only be used for formatting (not as a portable absolute instant).
  static DateTime wallClock(DateTime instant) {
    final utc = instant.toUtc();
    final offset = Duration(hours: isDaylightSaving(utc) ? 2 : 1);
    final shifted = utc.add(offset);
    return DateTime(
      shifted.year,
      shifted.month,
      shifted.day,
      shifted.hour,
      shifted.minute,
      shifted.second,
      shifted.millisecond,
      shifted.microsecond,
    );
  }

  /// Whether [utcInstant] falls in Italian daylight saving (CEST).
  ///
  /// EU rule: DST starts last Sunday of March at 01:00 UTC and ends last
  /// Sunday of October at 01:00 UTC. [utcInstant] is normalized with [toUtc].
  static bool isDaylightSaving(DateTime utcInstant) {
    final utc = utcInstant.toUtc();
    final start = _dstTransitionUtc(utc.year, month: 3);
    final end = _dstTransitionUtc(utc.year, month: 10);
    return !utc.isBefore(start) && utc.isBefore(end);
  }

  static DateTime _dstTransitionUtc(int year, {required int month}) {
    final lastDay = DateTime.utc(year, month + 1, 0).day;
    var day = lastDay;
    while (DateTime.utc(year, month, day).weekday != DateTime.sunday) {
      day--;
    }
    return DateTime.utc(year, month, day, 1);
  }
}
