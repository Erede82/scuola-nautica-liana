import '../models/license_models.dart';

/// Regole schede quiz delle lezioni (distinte da [ExamQuizRules]).
final class LessonQuizRules {
  const LessonQuizRules({
    required this.questionsPerSheet,
    required this.maxErrors,
    required this.countUnansweredAsErrors,
  });

  /// Domande attese per scheda (post-migration D1: 15; A12: 20).
  final int questionsPerSheet;

  /// Soglia errori per indicatori statistici «entro soglia».
  final int maxErrors;

  /// Se true, le non risposte contano come errori statistici.
  final bool countUnansweredAsErrors;

  static const LessonQuizRules a12 = LessonQuizRules(
    questionsPerSheet: 20,
    maxErrors: 4,
    countUnansweredAsErrors: false,
  );

  static const LessonQuizRules d1 = LessonQuizRules(
    questionsPerSheet: 15,
    maxErrors: 3,
    countUnansweredAsErrors: true,
  );
}

/// Regole schede per categoria app. `null` se non supportata.
LessonQuizRules? lessonQuizRulesForCategory(LicenseCategoryId categoryId) {
  switch (categoryId) {
    case LicenseCategoryId.motore:
      return LessonQuizRules.a12;
    case LicenseCategoryId.d1:
      return LessonQuizRules.d1;
    case LicenseCategoryId.vela:
      return null;
  }
}

/// Errori statistici di una scheda secondo le regole della categoria.
///
/// A12 → solo [wrongCount].
/// D1 → [wrongCount] + [unansweredCount].
int lessonQuizErrorCountForResult({
  required LicenseCategoryId categoryId,
  required int wrongCount,
  required int unansweredCount,
}) {
  final rules = lessonQuizRulesForCategory(categoryId);
  if (rules == null) {
    return wrongCount;
  }
  if (rules.countUnansweredAsErrors) {
    return wrongCount + unansweredCount;
  }
  return wrongCount;
}

/// True se gli errori della scheda sono entro la soglia della categoria.
bool lessonQuizWithinErrorThreshold({
  required LicenseCategoryId categoryId,
  required int wrongCount,
  required int unansweredCount,
}) {
  final rules = lessonQuizRulesForCategory(categoryId);
  if (rules == null) return false;
  final errors = lessonQuizErrorCountForResult(
    categoryId: categoryId,
    wrongCount: wrongCount,
    unansweredCount: unansweredCount,
  );
  return errors <= rules.maxErrors;
}
