import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../domain/anagrafica/comune_catastale.dart';

/// Carica il dataset Comuni/Stati esteri da un asset JSON locale.
///
/// Gestisce in modo esplicito lo stato "dataset non disponibile" (asset
/// mancante, vuoto o placeholder): in quel caso [disponibile] resta `false`
/// e le ricerche restituiscono liste vuote, senza mai lanciare eccezioni né
/// rompere il build.
class ComuniRepository {
  ComuniRepository({this.assetPath = 'assets/data/comuni_catastali.json'});

  final String assetPath;

  bool _loaded = false;
  bool _disponibile = false;
  List<ComuneCatastale> _comuni = const [];
  List<ComuneCatastale> _esteri = const [];

  /// `true` solo se è presente almeno l'elenco dei comuni italiani.
  bool get disponibile => _disponibile;

  int get numeroComuni => _comuni.length;
  int get numeroEsteri => _esteri.length;

  /// Carica il dataset una sola volta. Sicuro da chiamare più volte.
  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final raw = await rootBundle.loadString(assetPath);
      if (raw.trim().isEmpty) {
        _markUnavailable();
        return;
      }
      final decoded = json.decode(raw);
      if (decoded is! Map<String, dynamic>) {
        _markUnavailable();
        return;
      }
      _comuni = _parseList(decoded['comuni'], LuogoNascitaTipo.comuneItaliano);
      _esteri = _parseList(decoded['esteri'], LuogoNascitaTipo.statoEstero);
      _disponibile = _comuni.isNotEmpty;
    } catch (_) {
      // Asset non registrato / JSON malformato: dataset non disponibile.
      _markUnavailable();
    }
  }

  void _markUnavailable() {
    _disponibile = false;
    _comuni = const [];
    _esteri = const [];
  }

  List<ComuneCatastale> _parseList(dynamic raw, LuogoNascitaTipo tipo) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map((e) => ComuneCatastale.fromJson(e, tipo: tipo))
        .where((c) => c.isValido)
        .toList(growable: false);
  }

  /// Ricerca per prefisso (priorità) e poi per sottostringa sul nome.
  /// Restituisce lista vuota se il dataset non è disponibile.
  List<ComuneCatastale> cerca(String query, {int limit = 20}) {
    if (!_disponibile) return const [];
    final q = query.trim().toUpperCase();
    if (q.isEmpty) return const [];
    final prefisso = <ComuneCatastale>[];
    final contiene = <ComuneCatastale>[];
    for (final c in [..._comuni, ..._esteri]) {
      final nome = c.nomeNormalizzato;
      if (nome.startsWith(q)) {
        prefisso.add(c);
      } else if (nome.contains(q)) {
        contiene.add(c);
      }
    }
    return [...prefisso, ...contiene].take(limit).toList(growable: false);
  }
}
