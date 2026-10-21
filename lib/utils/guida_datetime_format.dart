import 'europe_rome_time.dart';

/// Formattazione leggibile (IT) senza dipendenze [intl].
///
/// Timestamps are shown in official Italian time ([EuropeRomeTime]).
abstract final class GuidaDateTimeFormat {
  static const _mesi = [
    'gennaio',
    'febbraio',
    'marzo',
    'aprile',
    'maggio',
    'giugno',
    'luglio',
    'agosto',
    'settembre',
    'ottobre',
    'novembre',
    'dicembre',
  ];

  /// Absolute [instant] → `21 ottobre 2026` in Europe/Rome.
  static String formatDate(DateTime instant) {
    final d = EuropeRomeTime.wallClock(instant);
    return '${d.day} ${_mesi[d.month - 1]} ${d.year}';
  }

  /// Absolute [instant] → `20:56` (24h) in Europe/Rome.
  static String formatTime(DateTime instant, {String? override}) {
    final o = override?.trim();
    if (o != null && o.isNotEmpty) return o;
    final d = EuropeRomeTime.wallClock(instant);
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Absolute [instant] → `21 ottobre 2026 · 20:56` in Europe/Rome.
  static String formatItalianDateTime(DateTime instant) {
    return '${formatDate(instant)} · ${formatTime(instant)}';
  }
}
