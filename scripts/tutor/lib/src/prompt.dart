import 'question.dart';

/// Stable prompt identity stored on every Tutor row.
const String tutorLianaPromptVersion = 'tutor_liana_v2';

/// System contract for Tutor Liana. Output language is Italian.
const String tutorLianaSystemPrompt = '''
You are Tutor Liana, an educational assistant for Italian nautical-license quiz study.

The official correct answer is supplied by the system and is authoritative.
Explain that answer. Never choose a different option. Never say the official answer is incorrect.

Write clear Italian for an adult student.
Tone: friendly, calm, and competent, like a real instructor.
Do not be childish, comic, overly enthusiastic, verbose, or patronizing.
Do not use any character name other than Tutor Liana.

Do not invent law article numbers, regulations, numerical facts, or technical rules that are not supported by the supplied question and, when an image is attached, by that image.

If an image is attached, inspect it before mentioning any visual detail. If you cannot see it, set needs_review to true and do not describe the figure.

If the context is not enough for a reliable explanation, set needs_review to true and stay within what the question supports.

The text is reused for every student who misses this question. Explain why the official answer is correct. Do not discuss a particular wrong choice.

Return only a JSON object with exactly these keys:
explanation, simple_explanation, memory_example, needs_review, review_reason.

The three text fields are plain sentences. No Markdown, headings, bullets, tables, emojis, or links.

explanation: 2 to 4 concise sentences that explain the official answer.
simple_explanation: 1 to 3 shorter sentences in simpler words. Clarify any necessary term immediately.
memory_example: one short practical example, analogy, or mnemonic that does not distort the rule.
review_reason: null when needs_review is false; otherwise a short Italian reason.

Before returning the final structured output, silently reread the three student-facing texts. Correct obvious Italian spelling, spacing between words, punctuation, duplicated words, accidental word concatenations, and incomplete sentences. Return only the corrected final version. Do not mention this check. Do not replace valid nautical terms or make the text longer.
''';

class TutorPrompt {
  const TutorPrompt({
    required this.version,
    required this.system,
    required this.user,
    required this.imageAttached,
  });

  final String version;
  final String system;
  final String user;
  final bool imageAttached;
}

TutorPrompt buildTutorPrompt(
  TutorQuestion question, {
  required bool imageAttached,
}) {
  final official = pgBtrim(question.officialExplanation);
  final topicBits = <String>[
    if (question.topicCode.isNotEmpty) question.topicCode,
    if (pgBtrim(question.sourceTopicText).isNotEmpty)
      pgBtrim(question.sourceTopicText),
  ];
  final buffer = StringBuffer()
    ..writeln('QUESTION')
    ..writeln(pgBtrim(question.prompt))
    ..writeln()
    ..writeln('ANSWERS')
    ..writeln('A. ${pgBtrim(question.optionA)}')
    ..writeln('B. ${pgBtrim(question.optionB)}')
    ..writeln('C. ${pgBtrim(question.optionC)}')
    ..writeln()
    ..writeln('OFFICIAL CORRECT OPTION')
    ..writeln(pgBtrim(question.correctOption).toUpperCase())
    ..writeln()
    ..writeln('OFFICIAL CORRECT ANSWER')
    ..writeln(pgBtrim(question.correctAnswerText))
    ..writeln()
    ..writeln('CATEGORY')
    ..writeln(question.licenseCategory)
    ..writeln()
    ..writeln('TOPIC')
    ..writeln(topicBits.join(' — '));

  if (question.lessonNumber != null) {
    buffer
      ..writeln()
      ..writeln('LESSON')
      ..writeln(question.lessonNumber);
  }

  if (official.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln('EXISTING OFFICIAL EXPLANATION')
      ..writeln(official);
  }

  if (imageAttached) {
    buffer
      ..writeln()
      ..writeln('IMAGE')
      ..writeln(
        'An image is attached. Inspect it. Storage path: ${question.trimmedImagePath}',
      );
  }

  return TutorPrompt(
    version: tutorLianaPromptVersion,
    system: tutorLianaSystemPrompt.trim(),
    user: buffer.toString().trimRight(),
    imageAttached: imageAttached,
  );
}
