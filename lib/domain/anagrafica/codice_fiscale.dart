/// Motore puro per il codice fiscale italiano (persone fisiche).
///
/// NON contiene alcun elenco di Comuni: il codice catastale/Belfiore del luogo
/// di nascita va passato come parametro [codiceCatastale]. In questo modo il
/// motore è completamente disaccoppiato dal dataset dei Comuni.
///
/// Riferimenti algoritmo: DM 23/12/1976 (Agenzia delle Entrate).
class CodiceFiscale {
  CodiceFiscale._();

  /// Lettere del mese: gennaio→A … dicembre→T.
  static const List<String> _mesi = [
    'A', 'B', 'C', 'D', 'E', 'H', 'L', 'M', 'P', 'R', 'S', 'T',
  ];

  /// Valori per i caratteri in posizione DISPARI (1-based) per il check digit.
  static const Map<String, int> _dispari = {
    '0': 1, '1': 0, '2': 5, '3': 7, '4': 9, '5': 13, '6': 15, '7': 17,
    '8': 19, '9': 21,
    'A': 1, 'B': 0, 'C': 5, 'D': 7, 'E': 9, 'F': 13, 'G': 15, 'H': 17,
    'I': 19, 'J': 21, 'K': 2, 'L': 4, 'M': 18, 'N': 20, 'O': 11, 'P': 3,
    'Q': 6, 'R': 8, 'S': 12, 'T': 14, 'U': 16, 'V': 10, 'W': 22, 'X': 25,
    'Y': 24, 'Z': 23,
  };

  /// Valori per i caratteri in posizione PARI (1-based) per il check digit.
  static const Map<String, int> _pari = {
    '0': 0, '1': 1, '2': 2, '3': 3, '4': 4, '5': 5, '6': 6, '7': 7,
    '8': 8, '9': 9,
    'A': 0, 'B': 1, 'C': 2, 'D': 3, 'E': 4, 'F': 5, 'G': 6, 'H': 7,
    'I': 8, 'J': 9, 'K': 10, 'L': 11, 'M': 12, 'N': 13, 'O': 14, 'P': 15,
    'Q': 16, 'R': 17, 'S': 18, 'T': 19, 'U': 20, 'V': 21, 'W': 22, 'X': 23,
    'Y': 24, 'Z': 25,
  };

  /// Regex tollerante: ammette le lettere di omocodia (L M N P Q R S T U V)
  /// nelle posizioni numeriche, così non scarta codici omocodici validi.
  static final RegExp _formato = RegExp(
    r'^[A-Z]{6}[0-9LMNPQRSTUV]{2}[A-EHLMPRST][0-9LMNPQRSTUV]{2}[A-Z]'
    r'[0-9LMNPQRSTUV]{3}[A-Z]$',
  );

  /// Codice catastale: una lettera seguita da 3 cifre (es. F839, Z112).
  static final RegExp _codiceCatastaleFormato = RegExp(r'^[A-Z]\d{3}$');

  static const Map<String, String> _accenti = {
    'À': 'A', 'Á': 'A', 'Â': 'A', 'Ã': 'A', 'Ä': 'A', 'Å': 'A',
    'È': 'E', 'É': 'E', 'Ê': 'E', 'Ë': 'E',
    'Ì': 'I', 'Í': 'I', 'Î': 'I', 'Ï': 'I',
    'Ò': 'O', 'Ó': 'O', 'Ô': 'O', 'Õ': 'O', 'Ö': 'O', 'Ø': 'O',
    'Ù': 'U', 'Ú': 'U', 'Û': 'U', 'Ü': 'U',
    'Ç': 'C', 'Ñ': 'N', 'Ý': 'Y',
  };

  /// Rimuove gli spazi e porta in maiuscolo (nessuna altra trasformazione).
  static String normalizza(String cf) =>
      cf.replaceAll(RegExp(r'\s'), '').toUpperCase();

  static String _soloLettere(String s) {
    final buffer = StringBuffer();
    for (final ch in s.toUpperCase().split('')) {
      final mapped = _accenti[ch] ?? ch;
      if (RegExp(r'[A-Z]').hasMatch(mapped)) buffer.write(mapped);
    }
    return buffer.toString();
  }

  static bool _isVocale(String c) => 'AEIOU'.contains(c);

  static String _consonanti(String s) =>
      s.split('').where((c) => !_isVocale(c)).join();

  static String _vocali(String s) =>
      s.split('').where(_isVocale).join();

  static String _codiceCognome(String cognome) {
    final s = _soloLettere(cognome);
    final base = '${_consonanti(s)}${_vocali(s)}XXX';
    return base.substring(0, 3);
  }

  static String _codiceNome(String nome) {
    final s = _soloLettere(nome);
    final cons = _consonanti(s);
    if (cons.length >= 4) {
      return '${cons[0]}${cons[2]}${cons[3]}';
    }
    final base = '$cons${_vocali(s)}XXX';
    return base.substring(0, 3);
  }

  static String _codiceDataSesso(DateTime data, bool isFemmina) {
    final anno = (data.year % 100).toString().padLeft(2, '0');
    final mese = _mesi[data.month - 1];
    final giorno = (isFemmina ? data.day + 40 : data.day)
        .toString()
        .padLeft(2, '0');
    return '$anno$mese$giorno';
  }

  static String _carattereControllo(String primi15) {
    var somma = 0;
    for (var i = 0; i < primi15.length; i++) {
      final c = primi15[i];
      // posizione 1-based dispari → indice 0-based pari
      somma += (i % 2 == 0) ? (_dispari[c] ?? 0) : (_pari[c] ?? 0);
    }
    return String.fromCharCode('A'.codeUnitAt(0) + (somma % 26));
  }

  /// Genera il codice fiscale base (senza gestione omocodia).
  ///
  /// Lancia [ArgumentError] se mancano i dati o se [codiceCatastale] non ha
  /// formato valido. Il risultato va sempre trattato come **suggerimento**
  /// modificabile dall'operatore.
  static String genera({
    required String cognome,
    required String nome,
    required bool isFemmina,
    required DateTime dataNascita,
    required String codiceCatastale,
  }) {
    if (cognome.trim().isEmpty) {
      throw ArgumentError('Cognome mancante.');
    }
    if (nome.trim().isEmpty) {
      throw ArgumentError('Nome mancante.');
    }
    final cc = codiceCatastale.trim().toUpperCase();
    if (!_codiceCatastaleFormato.hasMatch(cc)) {
      throw ArgumentError('Codice catastale non valido: "$codiceCatastale".');
    }
    final base = '${_codiceCognome(cognome)}'
        '${_codiceNome(nome)}'
        '${_codiceDataSesso(dataNascita, isFemmina)}'
        '$cc';
    return '$base${_carattereControllo(base)}';
  }

  /// Validazione formale: formato corretto + carattere di controllo coerente.
  /// Tollera i codici omocodici.
  static bool isFormalmenteValido(String cf) {
    final s = normalizza(cf);
    if (s.length != 16) return false;
    if (!_formato.hasMatch(s)) return false;
    return _carattereControllo(s.substring(0, 15)) == s[15];
  }

  /// `true` se i due codici, una volta normalizzati, coincidono.
  static bool coincidono(String a, String b) =>
      normalizza(a) == normalizza(b);
}
