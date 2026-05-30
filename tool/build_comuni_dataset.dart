// Build dataset Comuni/Stati esteri → assets/data/comuni_catastali.json
//
// SCHELETRO. NON SCARICA NULLA dalla rete.
// Trasforma file UFFICIALI GIÀ PRESENTI in locale nel formato usato dall'app.
//
// Sorgenti ufficiali da fornire (scaricate manualmente dall'utente):
//   - Comuni + codice catastale/Belfiore: Agenzia delle Entrate
//     "Elenco dei codici catastali dei Comuni" (CSV) e/o ISTAT
//     "Codici statistici delle unità amministrative territoriali".
//   - Stati esteri + codice catastale: Agenzia delle Entrate
//     "Elenco dei codici catastali degli Stati esteri" (CSV).
//
// Uso (dopo aver salvato i CSV ufficiali in locale):
//   dart run tool/build_comuni_dataset.dart \
//     --comuni=path/comuni.csv \
//     --esteri=path/esteri.csv \
//     --out=assets/data/comuni_catastali.json
//
// IMPORTANTE: gli indici colonna qui sotto vanno verificati sull'header reale
// del CSV ufficiale fornito prima di considerare valido l'output.

import 'dart:convert';
import 'dart:io';

// Indici colonna (0-based) del CSV ufficiale Agenzia Entrate "ElencoComuniAttuali":
//   Codice Nazionale;Sigla Provincia;Denominazione Italiana;Denominazione Estera;
//   Codice Catastale;...
// IMPORTANTE: per il codice fiscale si usa "Codice Nazionale" (Belfiore),
// NON "Codice Catastale".
const int _comuneNomeIdx = 2; // Denominazione Italiana
const int _comuneProvinciaIdx = 1; // Sigla Provincia
const int _comuneCodiceIdx = 0; // Codice Nazionale (Belfiore)
const int _esteroNomeIdx = 0;
const int _esteroCodiceIdx = 1;

void main(List<String> args) {
  final opts = _parseArgs(args);
  final comuniPath = opts['comuni'];
  final esteriPath = opts['esteri'];
  final outPath = opts['out'] ?? 'assets/data/comuni_catastali.json';

  if (comuniPath == null) {
    stderr.writeln(
      'ERRORE: manca --comuni=<file.csv> con i codici catastali dei Comuni.\n'
      'Nessun download viene effettuato: fornisci il file ufficiale in locale.',
    );
    exitCode = 2;
    return;
  }

  final comuni = _parseCsv(
    File(comuniPath),
    nomeIdx: _comuneNomeIdx,
    codiceIdx: _comuneCodiceIdx,
    provinciaIdx: _comuneProvinciaIdx,
  );
  final esteri = esteriPath == null
      ? const <Map<String, String>>[]
      : _parseCsv(
          File(esteriPath),
          nomeIdx: _esteroNomeIdx,
          codiceIdx: _esteroCodiceIdx,
        );

  if (comuni.isEmpty) {
    stderr.writeln(
      'STOP: nessun comune estratto. Verifica gli indici colonna in cima allo '
      'script sul CSV ufficiale, poi rilancia. Niente è stato scritto.',
    );
    exitCode = 3;
    return;
  }

  final dataset = <String, dynamic>{
    'meta': {
      'disponibile': true,
      'fonte': opts['fonte'] ??
          'Agenzia delle Entrate - ElencoComuniAttuali (Codice Nazionale/Belfiore)',
      'aggiornato_al': opts['aggiornato'] ??
          DateTime.now().toIso8601String().substring(0, 10),
      'copertura': opts['copertura'] ?? 'solo_comuni_italiani_attuali',
    },
    'comuni': comuni,
    'esteri': esteri,
  };

  File(outPath).writeAsStringSync(json.encode(dataset));
  stdout.writeln(
    'Scritto $outPath — comuni: ${comuni.length}, esteri: ${esteri.length}',
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

/// Parser CSV minimale (separatore ';' tipico dei file italiani). Da sostituire
/// con package:csv se i file ufficiali usano quoting complesso.
List<Map<String, String>> _parseCsv(
  File file, {
  required int nomeIdx,
  required int codiceIdx,
  int? provinciaIdx,
}) {
  if (!file.existsSync()) {
    stderr.writeln('ERRORE: file non trovato: ${file.path}');
    return const [];
  }
  final lines = file.readAsLinesSync();
  final out = <Map<String, String>>[];
  final maxIdx = [
    nomeIdx,
    codiceIdx,
    provinciaIdx ?? 0,
  ].reduce((a, b) => a > b ? a : b);

  for (var i = 1; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;
    final cells = line.split(';');
    if (cells.length <= maxIdx) continue;
    final nome = cells[nomeIdx].trim();
    final codice = cells[codiceIdx].trim().toUpperCase();
    if (nome.isEmpty || codice.isEmpty) continue;
    out.add({
      'nome': nome,
      'provincia': provinciaIdx != null
          ? cells[provinciaIdx].trim().toUpperCase()
          : 'EE',
      'codice': codice,
    });
  }
  return out;
}
