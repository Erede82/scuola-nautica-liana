/// Normalizzazione dei testi anagrafici.
///
/// Title Case "all'italiana" per nomi, cognomi e luoghi (es. "mario" → "Mario",
/// "NAPOLI" → "Napoli", "castellammare di stabia" → "Castellammare di Stabia").
/// I dati che devono restare in maiuscolo per motivi tecnici (codice fiscale,
/// sigla provincia) NON passano da qui.
class AnagraficaFormat {
  AnagraficaFormat._();

  /// Connettori che restano minuscoli quando non sono la prima parola.
  static const Set<String> _connettori = {
    'di', 'de', 'del', 'dello', 'della', 'dei', 'degli', 'delle',
    'da', 'dal', 'dalla', 'lo', 'la', 'le', 'li', 'il', 'i',
    'e', 'ed', 'in', 'su', 'a', 'al', 'ai',
  };

  /// Restituisce la stringa in Title Case. Vuoto → vuoto.
  static String titleCase(String input) {
    final s = input.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (s.isEmpty) return '';
    final parole = s.split(' ');
    final out = <String>[];
    for (var i = 0; i < parole.length; i++) {
      final p = parole[i];
      if (i != 0 && _connettori.contains(p)) {
        out.add(p);
      } else {
        out.add(_capitalizzaParola(p));
      }
    }
    return out.join(' ');
  }

  /// Maiuscola la prima lettera e quelle dopo trattino/apostrofo.
  static String _capitalizzaParola(String parola) {
    final buffer = StringBuffer();
    var maiuscolaProssima = true;
    for (var i = 0; i < parola.length; i++) {
      final ch = parola[i];
      if (ch == '-' || ch == "'" || ch == '\u2019') {
        buffer.write(ch);
        maiuscolaProssima = true;
      } else {
        buffer.write(maiuscolaProssima ? ch.toUpperCase() : ch);
        maiuscolaProssima = false;
      }
    }
    return buffer.toString();
  }
}
