/// Identity of the offline copyedit instruction. It is not the Tutor prompt.
const String tutorCopyeditVersion = 'tutor_copyedit_v1';

const String tutorCopyeditSchemaName = 'tutor_copyedit_v1';

/// Mechanical copyedit only. The question, options, and image are not included.
const String tutorCopyeditSystemPrompt = '''
You are a copy editor for three Italian texts already written for an adult nautical-license student.

You do not answer the quiz. You do not choose an option. You do not see the question or any image.

Correct only mechanical defects:
- obvious spelling typos
- missing spaces between words
- accidental word concatenations
- duplicated words
- punctuation
- capitalization
- obvious mechanical grammar slips caused by typing

Do not change the nautical meaning.
Do not add facts, remove facts, or introduce examples.
Do not change numbers, units, or legal references.
Do not expand the explanation or replace a valid nautical term.
Keep the wording when it is already clean.

Return the three corrected texts, whether you changed anything, and a short review_reason or null.
''';

Map<String, Object?> tutorCopyeditJsonSchema() {
  return {
    'type': 'object',
    'additionalProperties': false,
    'properties': {
      'explanation': {'type': 'string'},
      'simple_explanation': {'type': 'string'},
      'memory_example': {'type': 'string'},
      'changed': {'type': 'boolean'},
      'review_reason': {
        'type': ['string', 'null'],
      },
    },
    'required': [
      'explanation',
      'simple_explanation',
      'memory_example',
      'changed',
      'review_reason',
    ],
  };
}

/// The only text sent to the copy editor.
String tutorCopyeditUserText({
  required String explanation,
  required String simpleExplanation,
  required String memoryExample,
}) {
  return 'explanation:\n$explanation\n\n'
      'simple_explanation:\n$simpleExplanation\n\n'
      'memory_example:\n$memoryExample\n';
}

class TutorCopyeditOutput {
  const TutorCopyeditOutput({
    required this.explanation,
    required this.simpleExplanation,
    required this.memoryExample,
    required this.changed,
    required this.reviewReason,
  });

  final String explanation;
  final String simpleExplanation;
  final String memoryExample;
  final bool changed;
  final String? reviewReason;
}

class TutorCopyeditParseException implements Exception {
  TutorCopyeditParseException(this.message);
  final String message;
  @override
  String toString() => message;
}

class TutorCopyeditCheck {
  const TutorCopyeditCheck({required this.rejections});

  final List<String> rejections;
  bool get accepted => rejections.isEmpty;
}

const _copyeditKeys = {
  'explanation',
  'simple_explanation',
  'memory_example',
  'changed',
  'review_reason',
};

/// Italian number words and units whose counts must survive copyediting.
const _guardedWords = {
  'zero',
  'un',
  'uno',
  'una',
  'due',
  'tre',
  'quattro',
  'cinque',
  'sei',
  'sette',
  'otto',
  'nove',
  'dieci',
  'undici',
  'dodici',
  'venti',
  'trenta',
  'cento',
  'mille',
  'miglio',
  'miglia',
  'nodo',
  'nodi',
  'metro',
  'metri',
  'minuto',
  'minuti',
  'secondo',
  'secondi',
  'grado',
  'gradi',
  'ora',
  'ore',
};

/// An explicit sign is part of the number. A hyphen between two numbers, as in
/// `4-6`, is not a sign because a digit precedes it.
final RegExp _numberToken = RegExp(
  '(?<![0-9A-Za-zÀ-ÿ])'
  r'([+'
  '\u2212'
  r'-])?'
  r'[0-9]+(?:[.,][0-9]+)?'
  '(?![0-9A-Za-zÀ-ÿ])',
);
final RegExp _wordToken = RegExp(r'[A-Za-zÀ-ÿ]+');

/// Compact units and symbols seen in the question bank, plus the nautical
/// forms the typography gate already treats as valid (`NM`, `kW`, `V`, `A`).
///
/// Comparison is case-sensitive: `26m` and `11M` are different bank notations.
/// Longer forms are listed first so `kW` is not read as `W` and `VHF` is not
/// read as `V`.
const _technicalUnits =
    'hPa|MHz|Mhz|litri/h|VHF/FM|MF/HF|kW|Kw|KW|l/h|k/h|CV|Cv|HP|Hp|NM|'
    'kg|Kg|km|Km|mm|cm|gr|VHF|NE|SE|SW|NW|[MmBVsAW]';

final RegExp _technicalToken = RegExp(
  '(?<![0-9A-Za-zÀ-ÿ])'
  r'([+'
  '\u2212'
  r'-]?[0-9]+(?:[.,][0-9]+)?)'
  r'\s*'
  '(?:$_technicalUnits|[°º]|[\u2032'
  "'’])"
  '(?![0-9A-Za-zÀ-ÿ])'
  '|'
  '(?<![0-9A-Za-zÀ-ÿ])'
  '(VHF/FM|MF/HF|VHF|NE|SE|SW|NW|N|S|E|W)'
  '(?![0-9A-Za-zÀ-ÿ])',
);
final RegExp _urlToken = RegExp(r'https?://\S+', caseSensitive: false);
final RegExp _optionLabel = RegExp(
  r'\b(?:opzione|risposta)\s+[abc]\b',
  caseSensitive: false,
);

TutorCopyeditOutput parseTutorCopyedit(Object? decoded) {
  if (decoded is! Map) {
    throw TutorCopyeditParseException('copyedit output is not a JSON object');
  }
  final keys = decoded.keys.map((key) => key.toString()).toSet();
  if (keys.length != _copyeditKeys.length || !keys.containsAll(_copyeditKeys)) {
    throw TutorCopyeditParseException(
      'copyedit output keys must be exactly $_copyeditKeys',
    );
  }
  final explanation = decoded['explanation'];
  final simple = decoded['simple_explanation'];
  final memory = decoded['memory_example'];
  final changed = decoded['changed'];
  final reviewReason = decoded['review_reason'];
  if (explanation is! String || simple is! String || memory is! String) {
    throw TutorCopyeditParseException('copyedit text fields must be strings');
  }
  if (changed is! bool) {
    throw TutorCopyeditParseException('copyedit changed must be a boolean');
  }
  if (reviewReason != null && reviewReason is! String) {
    throw TutorCopyeditParseException(
      'copyedit review_reason must be a string or null',
    );
  }
  return TutorCopyeditOutput(
    explanation: explanation,
    simpleExplanation: simple,
    memoryExample: memory,
    changed: changed,
    reviewReason: reviewReason,
  );
}

/// Character slack for a mechanical correction.
///
/// A missing space changes length by one. Twelve characters covers that plus
/// a short punctuation or duplicated-word fix. The cap of forty characters
/// stops a new sentence from hiding inside a long explanation.
int tutorCopyeditLengthAllowance(int length) {
  final relative = (length * 0.08).ceil();
  if (relative < 12) return 12;
  if (relative > 40) return 40;
  return relative;
}

/// Minimum normalized substitution allowed for one mechanical typo.
///
/// Distance 0 is a space or punctuation change (`misuratain` to `misurata in`).
/// Distance 1 or 2 is a short typo. Distance 3 or more is a different word
/// (`prua` to `poppa`, `nord` to `sud`).
const int tutorCopyeditSubstitutionFloor = 2;

/// Edit slack after spaces, punctuation, and case are ignored.
///
/// Inserting a space has distance zero. The floor of two characters is the
/// largest mechanical typo that still stays below the semantic swaps above.
/// Three percent, capped at twenty, still limits a rewritten sentence.
int tutorCopyeditEditAllowance(int normalizedLength) {
  final relative = (normalizedLength * 0.03).ceil();
  if (relative < tutorCopyeditSubstitutionFloor) {
    return tutorCopyeditSubstitutionFloor;
  }
  if (relative > 20) return 20;
  return relative;
}

TutorCopyeditCheck verifyTutorCopyedit({
  required String beforeExplanation,
  required String beforeSimple,
  required String beforeMemory,
  required String afterExplanation,
  required String afterSimple,
  required String afterMemory,
}) {
  final rejections = <String>[];
  _compareField(beforeExplanation, afterExplanation, rejections);
  _compareField(beforeSimple, afterSimple, rejections);
  _compareField(beforeMemory, afterMemory, rejections);
  return TutorCopyeditCheck(rejections: rejections.toSet().toList());
}

void _compareField(String before, String after, List<String> rejections) {
  final original = before.trim();
  final edited = after.trim();
  if (!_sameList(_numbers(original), _numbers(edited))) {
    rejections.add('copyedit_number_changed');
  }
  if (!_sameCounts(_guardedCounts(original), _guardedCounts(edited))) {
    rejections.add('copyedit_guarded_token_changed');
  }
  if (!_sameList(_technicalTokens(original), _technicalTokens(edited))) {
    rejections.add('copyedit_technical_token_changed');
  }
  if (!_sameList(_urls(original), _urls(edited))) {
    rejections.add('copyedit_url_changed');
  }
  if (!_sameList(_optionLabels(original), _optionLabels(edited))) {
    rejections.add('copyedit_option_label_changed');
  }
  final lengthDelta = (edited.length - original.length).abs();
  if (lengthDelta > tutorCopyeditLengthAllowance(original.length)) {
    rejections.add('copyedit_length_changed');
  }
  final left = _normalized(original);
  final right = _normalized(edited);
  if (_editDistance(left, right) > tutorCopyeditEditAllowance(left.length)) {
    rejections.add('copyedit_rewrite');
  }
  if (!_sameWordSequence(_words(original), _words(edited))) {
    rejections.add('copyedit_rewrite');
  }
}

List<String> _numbers(String text) {
  final covered = _technicalToken.allMatches(text);
  return [
    for (final match in _numberToken.allMatches(text))
      if (!covered.any(
        (token) => match.start >= token.start && match.end <= token.end,
      ))
        _canonNumber(match.group(0)!),
  ];
}

String _canonNumber(String raw) {
  var sign = '';
  var rest = raw;
  if (rest.startsWith('+')) {
    sign = '+';
    rest = rest.substring(1);
  } else if (rest.startsWith('-') || rest.startsWith('\u2212')) {
    sign = '-';
    rest = rest.substring(1);
  }
  return '$sign${rest.replaceAll(',', '.')}';
}

List<String> _technicalTokens(String text) {
  return [
    for (final match in _technicalToken.allMatches(text))
      _canonTechnical(match.group(0)!),
  ];
}

String _canonTechnical(String raw) {
  final buffer = StringBuffer();
  for (final rune in raw.replaceAll(RegExp(r'\s+'), '').runes) {
    final char = String.fromCharCode(rune);
    if (char == '\u2212') {
      buffer.write('-');
    } else if (char == '\u2032' || char == '’') {
      buffer.write("'");
    } else if (char == 'º') {
      buffer.write('°');
    } else if (char == ',') {
      buffer.write('.');
    } else {
      buffer.write(char);
    }
  }
  return buffer.toString();
}

List<String> _words(String text) {
  return [
    for (final match in _wordToken.allMatches(text))
      match.group(0)!.toLowerCase(),
  ];
}

/// A missing space may split or join a word. A repeated neighbor may be
/// dropped. Any other word may change by at most
/// [tutorCopyeditSubstitutionFloor] characters.
bool _sameWordSequence(List<String> before, List<String> after) {
  var i = 0;
  var j = 0;
  while (i < before.length && j < after.length) {
    if (before[i] == after[j]) {
      i++;
      j++;
      continue;
    }
    final split = _packedLength(before[i], after, j);
    if (split > 1) {
      i++;
      j += split;
      continue;
    }
    final merged = _packedLength(after[j], before, i);
    if (merged > 1) {
      i += merged;
      j++;
      continue;
    }
    if (i > 0 && before[i] == before[i - 1]) {
      i++;
      continue;
    }
    if (_editDistance(before[i], after[j]) <= tutorCopyeditSubstitutionFloor) {
      i++;
      j++;
      continue;
    }
    return false;
  }
  while (i < before.length && i > 0 && before[i] == before[i - 1]) {
    i++;
  }
  return i == before.length && j == after.length;
}

int _packedLength(String packed, List<String> parts, int start) {
  final buffer = StringBuffer();
  final limit = parts.length - start < 4 ? parts.length - start : 4;
  for (var count = 0; count < limit; count++) {
    buffer.write(parts[start + count]);
    if (count >= 1 && buffer.toString() == packed) return count + 1;
    if (buffer.length > packed.length) return 0;
  }
  return 0;
}

Map<String, int> _guardedCounts(String text) {
  final counts = <String, int>{};
  for (final match in _wordToken.allMatches(text)) {
    final word = match.group(0)!.toLowerCase();
    if (!_guardedWords.contains(word)) continue;
    counts[word] = (counts[word] ?? 0) + 1;
  }
  return counts;
}

List<String> _urls(String text) {
  return _urlToken.allMatches(text).map((match) => match.group(0)!).toList();
}

List<String> _optionLabels(String text) {
  return _optionLabel
      .allMatches(text)
      .map(
        (match) =>
            match.group(0)!.toLowerCase().replaceAll(RegExp(r'\s+'), ' '),
      )
      .toList();
}

bool _sameList(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) return false;
  }
  return true;
}

bool _sameCounts(Map<String, int> left, Map<String, int> right) {
  if (left.length != right.length) return false;
  for (final entry in left.entries) {
    if (right[entry.key] != entry.value) return false;
  }
  return true;
}

String _normalized(String text) {
  final buffer = StringBuffer();
  for (final rune in text.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    if (RegExp(r'[a-zàèéìòù0-9]').hasMatch(char)) buffer.write(char);
  }
  return buffer.toString();
}

int _editDistance(String left, String right) {
  if (left == right) return 0;
  if (left.isEmpty) return right.length;
  if (right.isEmpty) return left.length;
  var previous = List<int>.generate(right.length + 1, (index) => index);
  for (var i = 0; i < left.length; i++) {
    final current = List<int>.filled(right.length + 1, 0);
    current[0] = i + 1;
    for (var j = 0; j < right.length; j++) {
      final cost = left.codeUnitAt(i) == right.codeUnitAt(j) ? 0 : 1;
      final insert = current[j] + 1;
      final delete = previous[j + 1] + 1;
      final replace = previous[j] + cost;
      var best = insert < delete ? insert : delete;
      if (replace < best) best = replace;
      current[j + 1] = best;
    }
    previous = current;
  }
  return previous[right.length];
}
