import 'dart:convert';
import 'dart:io';

import 'package:tutor_liana_generator/tutor_generator.dart';

const _fields = ['explanation', 'simple_explanation', 'memory_example'];

const _regression = [
  'navigaentro',
  'dall’altezzadelle',
  'dueimbarcazioni',
  'anchedall’altezza',
  'bendistante',
  'Pensaal',
  'lacilindrata',
  'cilindrataè',
  'ai29',
  'lasciarelibero',
  'obbligatoriala',
  'migliadalla',
  'Questonon',
  'unacustodia',
  'propriaimbarcazione',
  'di150',
  'edi',
  'bisognodi',
  'allacosta',
  'digalleggiamento',
  'partedello',
  'attuazioneal',
  'almenoun',
  'guida,poi',
  'frontefreddo',
  'spingeverso',
  'epunta',
  'Conil',
  'Perciò048°',
  'lasigla',
  'tragittoè',
  'consumatie',
  'sitrova',
  'hail',
  'interv allo',
  'più di150',
];

String _regressionAction(String original) {
  final normalized = normalizeTutorTypographyText(original);
  if (normalized != original) return 'AUTO_FIXED';
  final report = validateTutorOutput(
    TutorParsedOutput(
      explanation: 'La regola ufficiale resta chiara: $original.',
      simpleExplanation: 'In breve, conta la risposta ufficiale.',
      memoryExample: 'Pensala come una boa.',
      needsReview: false,
      reviewReason: null,
    ),
    correctOption: 'A',
  );
  if (!report.acceptForReview) return 'REJECTED_FOR_REVIEW';
  return 'SILENTLY_ACCEPTED';
}

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('Usage: dart run bin/tutor_spacing_report.dart <items.jsonl>');
    exit(2);
  }
  final questions = <Map<String, Object?>>[];
  for (final line in File(args.single).readAsLinesSync()) {
    if (line.trim().isEmpty) continue;
    final decoded = jsonDecode(line);
    if (decoded is! Map || !decoded.containsKey('question_id')) continue;
    questions.add(decoded.map((key, value) => MapEntry(key.toString(), value)));
  }
  final findings = <Map<String, Object?>>[];
  final changes = <Map<String, Object?>>[];
  for (final row in questions) {
    final id = row['question_id'].toString();
    for (final field in _fields) {
      final text = (row[field] ?? '').toString();
      final normalized = normalizeTutorTypographyText(text);
      if (normalized != text) {
        changes.add({
          'question_id': id,
          'field': field,
          'before': text,
          'after': normalized,
        });
      }
      for (final finding in tutorSpacingFindings(text)) {
        findings.add({
          'question_id': id,
          'field': field,
          ...finding.toJson(),
        });
      }
    }
  }
  final regression = [
    for (final sample in _regression)
      {
        'sample': sample,
        'normalized': normalizeTutorTypographyText(sample),
        'action': _regressionAction(sample),
      },
  ];
  stdout.writeln(
    jsonEncode({
      'questions': questions.length,
      'findings': findings,
      'changes': changes,
      'regression': regression,
    }),
  );
}
