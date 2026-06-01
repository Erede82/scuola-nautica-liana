// Build assets/data/comuni_cap.json da CSV locali Garda Informatica gi_db_comuni.
// NON scarica nulla da internet.
//
// Uso:
//   dart run tool/build_comuni_cap_dataset.dart \
//     --gi-cap=/path/gi_cap.csv \
//     --gi-comuni=/path/gi_comuni.csv \
//     --out=assets/data/comuni_cap.json

import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final opts = _parseArgs(args);
  final giCapPath = opts['gi-cap'];
  final giComuniPath = opts['gi-comuni'];
  final outPath = opts['out'] ?? 'assets/data/comuni_cap.json';

  if (giCapPath == null || giComuniPath == null) {
    stderr.writeln(
      'ERRORE: servono --gi-cap=<gi_cap.csv> e --gi-comuni=<gi_comuni.csv>.\n'
      'Nessun download viene effettuato.',
    );
    exitCode = 2;
    return;
  }

  final comuniMeta = _loadComuniMeta(File(giComuniPath));
  if (comuniMeta.isEmpty) {
    stderr.writeln('ERRORE: gi_comuni.csv vuoto o non leggibile.');
    exitCode = 3;
    return;
  }

  final capsByIstat = _loadCapsByIstat(File(giCapPath));
  if (capsByIstat.isEmpty) {
    stderr.writeln('ERRORE: gi_cap.csv vuoto o non leggibile.');
    exitCode = 4;
    return;
  }

  final comuni = <Map<String, dynamic>>[];
  for (final entry in comuniMeta.entries) {
    final istat = entry.key;
    final meta = entry.value;
    final caps = capsByIstat[istat];
    if (caps == null || caps.isEmpty) continue;
    comuni.add({
      'codiceIstat': istat,
      'nome': meta['nome']!,
      'provincia': meta['provincia']!,
      'codiceBelfiore': meta['codiceBelfiore']!,
      'caps': caps,
    });
  }

  comuni.sort((a, b) => (a['nome'] as String).compareTo(b['nome'] as String));

  final dataset = <String, dynamic>{
    'meta': {
      'disponibile': comuni.isNotEmpty,
      'fonte': 'Garda Informatica gi_db_comuni',
      'licenza': 'MIT',
      'aggiornato_al': opts['aggiornato'] ?? '2026-05-29',
      'copertura': 'solo_comuni_italiani_attuali_cap',
    },
    'comuni': comuni,
  };

  File(outPath).writeAsStringSync(json.encode(dataset));
  stdout.writeln(
    'Scritto $outPath — comuni con CAP: ${comuni.length}, '
    'single-CAP: ${comuni.where((c) => (c['caps'] as List).length == 1).length}, '
    'multi-CAP: ${comuni.where((c) => (c['caps'] as List).length > 1).length}',
  );
}

Map<String, String?> _parseArgs(List<String> args) {
  final map = <String, String?>{};
  for (final a in args) {
    final m = RegExp(r'^--([^=]+)=(.*)$').firstMatch(a);
    if (m != null) map[m.group(1)!] = m.group(2);
  }
  return map;
}

Map<String, Map<String, String>> _loadComuniMeta(File file) {
  if (!file.existsSync()) {
    stderr.writeln('ERRORE: file non trovato: ${file.path}');
    return {};
  }
  final lines = file.readAsLinesSync();
  if (lines.isEmpty) return {};
  final header = lines.first.split(';');
  final idx = {
    'istat': header.indexOf('codice_istat'),
    'nome': header.indexOf('denominazione_ita'),
    'provincia': header.indexOf('sigla_provincia'),
    'belfiore': header.indexOf('codice_belfiore'),
  };
  final out = <String, Map<String, String>>{};
  for (var i = 1; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;
    final cells = _parseCsvLine(line);
    if (cells.length <= idx['belfiore']!) continue;
    final istat = cells[idx['istat']!].trim();
    final nome = cells[idx['nome']!].trim();
    final prov = cells[idx['provincia']!].trim();
    final bf = cells[idx['belfiore']!].trim().toUpperCase();
    if (istat.isEmpty || nome.isEmpty || prov.isEmpty || bf.isEmpty) continue;
    out[istat] = {
      'nome': nome,
      'provincia': prov,
      'codiceBelfiore': bf,
    };
  }
  return out;
}

Map<String, List<String>> _loadCapsByIstat(File file) {
  if (!file.existsSync()) {
    stderr.writeln('ERRORE: file non trovato: ${file.path}');
    return {};
  }
  final lines = file.readAsLinesSync();
  if (lines.isEmpty) return {};
  final byIstat = <String, Set<String>>{};
  for (var i = 1; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;
    final cells = line.split(';');
    if (cells.length < 2) continue;
    final istat = cells[0].trim();
    final cap = cells[1].trim();
    if (istat.isEmpty || cap.isEmpty) continue;
    byIstat.putIfAbsent(istat, () => {}).add(cap);
  }
  return byIstat.map(
    (k, v) => MapEntry(k, v.toList()..sort()),
  );
}

/// Parser minimale per celle tra virgolette (gi_comuni.csv).
List<String> _parseCsvLine(String line) {
  final out = <String>[];
  final buf = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (ch == '"') {
      inQuotes = !inQuotes;
    } else if (ch == ';' && !inQuotes) {
      out.add(buf.toString());
      buf.clear();
    } else {
      buf.write(ch);
    }
  }
  out.add(buf.toString());
  return out;
}
