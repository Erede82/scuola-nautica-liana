class TutorParsedOutput {
  const TutorParsedOutput({
    required this.explanation,
    required this.simpleExplanation,
    required this.memoryExample,
    required this.needsReview,
    required this.reviewReason,
  });

  final String explanation;
  final String simpleExplanation;
  final String memoryExample;
  final bool needsReview;
  final String? reviewReason;
}

class TutorQualityReport {
  const TutorQualityReport({
    required this.acceptForReview,
    required this.rejections,
    required this.flags,
  });

  final bool acceptForReview;
  final List<String> rejections;
  final List<String> flags;
}

const int explanationSoftMax = 900;
const int explanationHardMax = 1600;
const int simpleSoftMax = 500;
const int simpleHardMax = 900;
const int memorySoftMax = 400;
const int memoryHardMax = 700;

const _expectedKeys = {
  'explanation',
  'simple_explanation',
  'memory_example',
  'needs_review',
  'review_reason',
};

class TutorOutputParseException implements Exception {
  TutorOutputParseException(this.message);
  final String message;
  @override
  String toString() => message;
}

TutorParsedOutput parseTutorOutput(Object? decoded) {
  if (decoded is! Map) {
    throw TutorOutputParseException('structured output is not a JSON object');
  }
  final keys = decoded.keys.map((key) => key.toString()).toSet();
  if (keys.length != _expectedKeys.length || !keys.containsAll(_expectedKeys)) {
    throw TutorOutputParseException(
      'structured output keys must be exactly $_expectedKeys',
    );
  }
  final explanation = decoded['explanation'];
  final simple = decoded['simple_explanation'];
  final memory = decoded['memory_example'];
  final needsReview = decoded['needs_review'];
  final reviewReason = decoded['review_reason'];
  if (explanation is! String || simple is! String || memory is! String) {
    throw TutorOutputParseException('text fields must be strings');
  }
  if (needsReview is! bool) {
    throw TutorOutputParseException('needs_review must be a boolean');
  }
  if (reviewReason != null && reviewReason is! String) {
    throw TutorOutputParseException('review_reason must be a string or null');
  }
  return TutorParsedOutput(
    explanation: explanation,
    simpleExplanation: simple,
    memoryExample: memory,
    needsReview: needsReview,
    reviewReason: reviewReason,
  );
}

TutorQualityReport validateTutorOutput(
  TutorParsedOutput output, {
  required String correctOption,
}) {
  final rejections = <String>[];
  final flags = <String>[];
  final explanation = output.explanation.trim();
  final simple = output.simpleExplanation.trim();
  final memory = output.memoryExample.trim();
  final official = correctOption.trim().toUpperCase();

  if (explanation.isEmpty) rejections.add('empty_explanation');
  if (simple.isEmpty) rejections.add('empty_simple_explanation');
  if (memory.isEmpty) rejections.add('empty_memory_example');

  _lengthGuard(
    field: 'explanation',
    text: explanation,
    softMax: explanationSoftMax,
    hardMax: explanationHardMax,
    rejections: rejections,
    flags: flags,
  );
  _lengthGuard(
    field: 'simple_explanation',
    text: simple,
    softMax: simpleSoftMax,
    hardMax: simpleHardMax,
    rejections: rejections,
    flags: flags,
  );
  _lengthGuard(
    field: 'memory_example',
    text: memory,
    softMax: memorySoftMax,
    hardMax: memoryHardMax,
    rejections: rejections,
    flags: flags,
  );

  final combined = '$explanation\n$simple\n$memory';
  if (_hasGluedNumberWord(combined)) {
    rejections.add('concatenated_number_word');
  }
  if (_hasMarkdown(combined)) rejections.add('markdown_or_link');
  if (_contradictsOfficial(combined, official)) {
    rejections.add('contradicts_official_answer');
  }
  if (_inventedCitation(combined)) rejections.add('invented_citation');
  if (_uncertainty(combined)) flags.add('unsupported_uncertainty');
  final reviewReason = output.reviewReason?.trim();
  if (output.needsReview) {
    flags.add('needs_review');
    if (reviewReason == null || reviewReason.isEmpty) {
      flags.add('missing_review_reason');
    }
  } else if (reviewReason != null && reviewReason.isNotEmpty) {
    flags.add('ignored_review_reason');
  }

  return TutorQualityReport(
    acceptForReview: rejections.isEmpty,
    rejections: rejections,
    flags: flags,
  );
}

void _lengthGuard({
  required String field,
  required String text,
  required int softMax,
  required int hardMax,
  required List<String> rejections,
  required List<String> flags,
}) {
  if (text.isEmpty) return;
  if (text.length > hardMax) {
    rejections.add('excessive_$field');
  } else if (text.length > softMax) {
    flags.add('long_$field');
  }
}

/// Digits immediately followed by four or more lowercase letters.
///
/// `5nodi` matches. `5 nodi`, `12V`, `10kW`, `6NM`, `5s`, and `26m` do not.
/// The letter run `esimo` / `esima` / `esimi` / `esime` is the ordinal form
/// already present in the question bank (`50esimo`) and is not a missing space.
final RegExp _gluedNumberWord = RegExp(
  r'(?<![0-9A-Za-zÀ-ÿ])[0-9]+([a-zàèéìòù]{4,})(?![0-9A-Za-zÀ-ÿ])',
);

const _ordinalSuffixes = {'esimo', 'esima', 'esimi', 'esime'};

bool _hasGluedNumberWord(String text) {
  for (final match in _gluedNumberWord.allMatches(text)) {
    final suffix = match.group(1);
    if (suffix != null && !_ordinalSuffixes.contains(suffix)) return true;
  }
  return false;
}

bool _hasMarkdown(String text) {
  if (text.contains('```')) return true;
  if (text.contains('http://') || text.contains('https://')) return true;
  if (RegExp(r'^\s*#', multiLine: true).hasMatch(text)) return true;
  if (RegExp(r'^\s*[-*]\s+', multiLine: true).hasMatch(text)) return true;
  if (text.contains('|---')) return true;
  return RegExp(
    r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]',
    unicode: true,
  ).hasMatch(text);
}

bool _contradictsOfficial(String text, String official) {
  if (!{'A', 'B', 'C'}.contains(official)) return true;
  final others = ['A', 'B', 'C'].where((letter) => letter != official);
  final folded = text.toLowerCase();
  for (final other in others) {
    final lower = other.toLowerCase();
    final patterns = [
      RegExp('risposta corretta\\s+è\\s+$lower\\b'),
      RegExp('risposta corretta\\s+e\\s+$lower\\b'),
      RegExp('opzione\\s+$lower\\s+è\\s+corretta'),
      RegExp('la\\s+$lower\\s+è\\s+corretta'),
    ];
    if (patterns.any((pattern) => pattern.hasMatch(folded))) return true;
  }
  final officialLower = official.toLowerCase();
  return RegExp(
    'la risposta ufficiale\\s+$officialLower\\s+è\\s+sbagliata',
  ).hasMatch(folded);
}

bool _inventedCitation(String text) {
  final patterns = [
    RegExp(r'\b(art\.?|articolo)\s*\d+', caseSensitive: false),
    RegExp(
      r'\b(d\.?\s*lgs\.?|decreto legislativo)\s*\d+',
      caseSensitive: false,
    ),
    RegExp(r'\blegge\s+\d+', caseSensitive: false),
  ];
  return patterns.any((pattern) => pattern.hasMatch(text));
}

bool _uncertainty(String text) {
  final folded = text.toLowerCase();
  const phrases = [
    'non sono sicur',
    'potrebbe essere',
    'non è chiaro',
    'non e chiaro',
    'forse',
    'probabilmente',
  ];
  return phrases.any(folded.contains);
}
