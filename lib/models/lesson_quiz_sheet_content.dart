import 'license_models.dart';
import 'quiz_question.dart';

/// Contenuto scheda lezione risolto da `quiz_sets` + `quiz_set_items`.
class LessonQuizSheetContent {
  const LessonQuizSheetContent({
    required this.quizSetId,
    required this.categoryId,
    required this.lessonNumber,
    required this.sheetNumber,
    required this.questions,
  });

  final String quizSetId;
  final LicenseCategoryId categoryId;
  final int lessonNumber;
  final int sheetNumber;
  final List<QuizQuestion> questions;

  bool get isEmpty => questions.isEmpty;
}
