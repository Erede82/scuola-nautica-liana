import 'glued_words.dart';
import 'validation.dart';

/// Inserts a missing space after comma, semicolon, or colon when both sides
/// are letters. Digits, URLs, and compact technical notation are left as-is.
final RegExp _missingPunctuationSpace = RegExp(
  '(?<=[A-Za-z\u00C0-\u00FF])([,;:])(?=[A-Za-z\u00C0-\u00FF])',
);

/// A sentence period: a lowercase letter, a dot, then a new capitalized word.
///
/// `costa.Il` becomes `costa. Il`. `Fl.Y.3s4M` stays, because `Y` is not the
/// start of a lowercase word. Digits and URLs are outside this pattern.
final RegExp _missingSentenceSpace = RegExp(
  r'(?<=[a-zàèéìòù])\.(?=[A-ZÀÈÉÌÒÙ][a-zàèéìòù])',
);

const _unitsAfterNumber =
    'chilometri|chilometro|litri|litro|miglia|miglio|minuti|minuto|secondi|secondo|metri|metro|gradi|grado|nodi|nodo|ore|ora';

final RegExp _numberUnitGlue = RegExp(
  '(?<![0-9A-Za-zÀ-ÿ])([0-9]+)($_unitsAfterNumber)(?![0-9A-Za-zÀ-ÿ])',
  caseSensitive: false,
);

const _wordsBeforeNumber =
    'circa|quasi|oltre|sotto|sopra|entro|dopo|prima|ogni';

final RegExp _wordNumberGlue = RegExp(
  '(?<![0-9A-Za-zÀ-ÿ])($_wordsBeforeNumber)(?=[0-9])',
  caseSensitive: false,
);

final RegExp _urlOrEmail = RegExp(
  r'https?://\S+|(?<![0-9A-Za-zÀ-ÿ])[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}',
  caseSensitive: false,
);

String normalizeTutorTypographyText(String text) {
  final protected = _urlOrEmail.allMatches(text).toList();
  var next = text.replaceAllMapped(_missingPunctuationSpace, (match) {
    if (_inside(protected, match.start)) return match.group(0)!;
    return '${match.group(1)} ';
  });
  next = next.replaceAllMapped(_missingSentenceSpace, (match) {
    if (_inside(protected, match.start)) return match.group(0)!;
    return '. ';
  });
  next = next.replaceAllMapped(
    _numberUnitGlue,
    (match) => '${match.group(1)} ${match.group(2)}',
  );
  next = next.replaceAllMapped(
    _wordNumberGlue,
    (match) => '${match.group(1)} ',
  );
  return repairTutorGluedWords(next);
}

bool _inside(List<RegExpMatch> spans, int index) {
  for (final span in spans) {
    if (index >= span.start && index < span.end) return true;
  }
  return false;
}

TutorParsedOutput normalizeTutorTypographyOutput(TutorParsedOutput output) {
  return TutorParsedOutput(
    explanation: normalizeTutorTypographyText(output.explanation),
    simpleExplanation: normalizeTutorTypographyText(output.simpleExplanation),
    memoryExample: normalizeTutorTypographyText(output.memoryExample),
    needsReview: output.needsReview,
    reviewReason: output.reviewReason,
  );
}

bool tutorTypographyChanged({
  required String beforeExplanation,
  required String beforeSimple,
  required String beforeMemory,
  required String afterExplanation,
  required String afterSimple,
  required String afterMemory,
}) {
  return beforeExplanation != afterExplanation ||
      beforeSimple != afterSimple ||
      beforeMemory != afterMemory;
}
