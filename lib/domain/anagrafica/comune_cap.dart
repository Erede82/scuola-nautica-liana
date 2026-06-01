/// CAP associati a un Comune italiano (lookup residenza).
class ComuneCap {
  const ComuneCap({
    required this.codiceIstat,
    required this.nome,
    required this.provincia,
    required this.codiceBelfiore,
    required this.caps,
  });

  final String codiceIstat;
  final String nome;

  /// Sigla provincia (es. `NA`); sempre stringa, mai null.
  final String provincia;

  final String codiceBelfiore;
  final List<String> caps;

  bool get hasSingleCap => caps.length == 1;
  bool get hasMultipleCaps => caps.length > 1;

  factory ComuneCap.fromJson(Map<String, dynamic> json) {
    final capsRaw = json['caps'];
    final caps = capsRaw is List
        ? capsRaw.map((e) => e.toString().trim()).where((c) => c.isNotEmpty).toList()
        : <String>[];
    return ComuneCap(
      codiceIstat: (json['codiceIstat'] as String? ?? '').trim(),
      nome: (json['nome'] as String? ?? '').trim(),
      provincia: (json['provincia'] as String? ?? '').trim(),
      codiceBelfiore: (json['codiceBelfiore'] as String? ?? '').trim().toUpperCase(),
      caps: caps,
    );
  }
}
