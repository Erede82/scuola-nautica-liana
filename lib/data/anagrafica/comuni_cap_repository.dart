import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../domain/anagrafica/comune_cap.dart';

/// Lookup CAP per Comune (chiave: codice Belfiore / catastale).
class ComuniCapRepository {
  ComuniCapRepository({this.assetPath = 'assets/data/comuni_cap.json'});

  final String assetPath;

  bool _loaded = false;
  bool _disponibile = false;
  final Map<String, ComuneCap> _byBelfiore = {};

  bool get disponibile => _disponibile;

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
      final list = decoded['comuni'];
      if (list is! List || list.isEmpty) {
        _markUnavailable();
        return;
      }
      for (final item in list) {
        if (item is! Map<String, dynamic>) continue;
        final cap = ComuneCap.fromJson(item);
        if (cap.codiceBelfiore.isEmpty || cap.caps.isEmpty) continue;
        _byBelfiore[cap.codiceBelfiore] = cap;
      }
      _disponibile = _byBelfiore.isNotEmpty;
    } catch (_) {
      _markUnavailable();
    }
  }

  void _markUnavailable() {
    _disponibile = false;
    _byBelfiore.clear();
  }

  /// CAP del Comune per codice Belfiore. Lista vuota se non trovato.
  List<String> capsForBelfiore(String codiceBelfiore) {
    if (!_disponibile) return const [];
    final key = codiceBelfiore.trim().toUpperCase();
    return _byBelfiore[key]?.caps ?? const [];
  }
}
