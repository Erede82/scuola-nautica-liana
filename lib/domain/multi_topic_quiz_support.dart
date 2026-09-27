import '../models/license_models.dart';
import 'quiz_license_category.dart';

/// Categorie supportate da Multischeda: solo Motore (A12) e D1.
bool isMultiTopicCategorySupported(LicenseCategoryId categoryId) {
  return dbLicenseCategoryFor(categoryId) != null;
}

/// True se la lezione è selezionabile in Multischeda.
///
/// Gate esclusivi: categoria supportata + pool domande + unlock
/// ([StudyAccessRepository]). La completion non è un gate.
bool isLessonEligibleForMultiTopic({
  required LicenseCategoryId categoryId,
  required bool hasQuestionPool,
  required bool isUnlocked,
}) {
  return isMultiTopicCategorySupported(categoryId) &&
      hasQuestionPool &&
      isUnlocked;
}
