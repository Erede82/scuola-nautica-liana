import 'question.dart';
import 'sample_selector.dart';

class TutorSelection {
  const TutorSelection({
    this.questionIds = const [],
    this.limit,
    this.category,
    this.lesson,
    this.withImage = false,
    this.withoutImage = false,
    this.sample = false,
  });

  final List<String> questionIds;
  final int? limit;
  final String? category;
  final int? lesson;
  final bool withImage;
  final bool withoutImage;
  final bool sample;

  bool get hasCriteria =>
      sample ||
      questionIds.isNotEmpty ||
      limit != null ||
      category != null ||
      lesson != null ||
      withImage ||
      withoutImage;
}

final RegExp tutorQuestionIdPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

void validateSelection(TutorSelection selection) {
  if (!selection.hasCriteria) {
    throw FormatException(
      'Select questions with --sample, --question-id, --limit, '
      '--category, --lesson, or an image filter.',
    );
  }
  if (selection.withImage && selection.withoutImage) {
    throw FormatException('Use only one of --with-image or --without-image.');
  }
  if (selection.category != null &&
      selection.category != 'A12' &&
      selection.category != 'D1') {
    throw FormatException('--category must be A12 or D1.');
  }
  if (selection.lesson != null &&
      (selection.lesson! < 1 || selection.lesson! > 14)) {
    throw FormatException('--lesson must be from 1 to 14.');
  }
  if (selection.limit != null && selection.limit! < 1) {
    throw FormatException('--limit must be at least 1.');
  }
  for (final id in selection.questionIds) {
    if (!tutorQuestionIdPattern.hasMatch(id)) {
      throw FormatException('--question-id is not a UUID: $id');
    }
  }
}

class QuestionSelection {
  const QuestionSelection({
    required this.questions,
    this.missingSampleSlots = const [],
  });

  final List<TutorQuestion> questions;
  final List<String> missingSampleSlots;
}

QuestionSelection selectQuestions(
  List<TutorQuestion> questions,
  TutorSelection selection,
) {
  final ids = selection.questionIds.map((id) => id.toLowerCase()).toSet();
  var filtered = questions.where((question) {
    if (ids.isNotEmpty && !ids.contains(question.id.toLowerCase())) {
      return false;
    }
    if (selection.category != null &&
        question.licenseCategory != selection.category) {
      return false;
    }
    if (selection.lesson != null && question.lessonNumber != selection.lesson) {
      return false;
    }
    if (selection.withImage && !question.hasImage) return false;
    if (selection.withoutImage && question.hasImage) return false;
    return true;
  }).toList()..sort((a, b) => a.id.compareTo(b.id));

  var missing = const <String>[];
  if (selection.sample) {
    final sample = buildRepresentativeSample(filtered);
    filtered = sample.questions;
    missing = sample.missingSlots;
  }
  final limit = selection.limit;
  if (limit != null && filtered.length > limit) {
    filtered = filtered.take(limit).toList(growable: false);
  }
  return QuestionSelection(questions: filtered, missingSampleSlots: missing);
}
