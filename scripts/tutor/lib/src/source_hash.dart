import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'question.dart';

/// Canonical Tutor source string.
///
/// This is the same byte layout as
/// `public.compute_quiz_question_tutor_source_hash(uuid)`:
/// `concat_ws` of the labeled fields, UTF-8, SHA-256, lowercase hex.
/// Live runs store the hash returned by that function. This mirror exists
/// so tests and offline catalogs can reproduce it without a second formula.
String tutorSourceCanonical(TutorQuestion question) {
  return [
    'prompt=${pgBtrim(question.prompt)}',
    'option_a=${pgBtrim(question.optionA)}',
    'option_b=${pgBtrim(question.optionB)}',
    'option_c=${pgBtrim(question.optionC)}',
    'correct_option=${pgBtrim(question.correctOption)}',
    'image_path=${pgBtrim(question.imagePath)}',
    'official_explanation=${pgBtrim(question.officialExplanation)}',
  ].join('\n');
}

String tutorSourceHash(TutorQuestion question) {
  return sha256.convert(utf8.encode(tutorSourceCanonical(question))).toString();
}

final RegExp tutorSourceHashPattern = RegExp(r'^[0-9a-f]{64}$');
