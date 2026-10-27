import 'validation.dart';

/// Inserts a missing space after comma, semicolon, or colon when both sides
/// are letters. Digits, URLs, and compact technical notation are left as-is.
final RegExp _missingPunctuationSpace = RegExp(
  '(?<=[A-Za-z\u00C0-\u00FF])([,;:])(?=[A-Za-z\u00C0-\u00FF])',
);

String normalizeTutorTypographyText(String text) {
  return text.replaceAllMapped(
    _missingPunctuationSpace,
    (match) => '${match.group(1)} ',
  );
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
