/// Tipo di luogo di nascita ai fini del codice catastale/Belfiore.
enum LuogoNascitaTipo {
  /// Comune italiano (provincia = sigla, es. NA).
  comuneItaliano,

  /// Stato estero (provincia convenzionale = EE).
  statoEstero,
}

/// Voce del dataset Comuni/Stati esteri con codice catastale (Belfiore).
///
/// Il dataset reale va caricato da fonte ufficiale (vedi [ComuniRepository]);
/// questo model non contiene alcun dato hard-coded.
class ComuneCatastale {
  const ComuneCatastale({
    required this.nome,
    required this.provincia,
    required this.codiceCatastale,
    required this.tipo,
  });

  final String nome;

  /// Sigla provincia per i comuni italiani; `EE` per gli stati esteri.
  final String provincia;

  /// Codice catastale/Belfiore (es. F839 per Napoli, Z112 per la Germania).
  final String codiceCatastale;

  final LuogoNascitaTipo tipo;

  bool get isEstero => tipo == LuogoNascitaTipo.statoEstero;

  /// Nome in maiuscolo per ricerca/confronto case-insensitive.
  String get nomeNormalizzato => nome.toUpperCase();

  bool get isValido => nome.isNotEmpty && codiceCatastale.isNotEmpty;

  factory ComuneCatastale.fromJson(
    Map<String, dynamic> json, {
    required LuogoNascitaTipo tipo,
  }) {
    final provinciaRaw = (json['provincia'] as String? ?? '').trim().toUpperCase();
    return ComuneCatastale(
      nome: (json['nome'] as String? ?? '').trim(),
      provincia: tipo == LuogoNascitaTipo.statoEstero
          ? (provinciaRaw.isEmpty ? 'EE' : provinciaRaw)
          : provinciaRaw,
      codiceCatastale: (json['codice'] as String? ?? '').trim().toUpperCase(),
      tipo: tipo,
    );
  }

  @override
  String toString() => '$nome ($provincia) · $codiceCatastale';
}
