/// Formattazione leggibile (IT) senza dipendenze [intl].
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

  static String formatDate(DateTime d) {
    return '${d.day} ${_mesi[d.month - 1]} ${d.year}';
  }

  static String formatTime(DateTime d, {String? override}) {
    final o = override?.trim();
    if (o != null && o.isNotEmpty) return o;
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
