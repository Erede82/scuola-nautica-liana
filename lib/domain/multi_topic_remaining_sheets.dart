import '../models/license_models.dart';
import 'multi_topic_quiz_history_models.dart';

/// True se attempt e selezione condividono la stessa categoria e
/// il set argomenti dell'attempt è contenuto nella selezione corrente.
///
/// Attempt misti (es. {L2,L4}) restano rilevanti per {L2,L4,L6},
/// ma non per una selezione più stretta come {L2}.
/// Attempt di altra categoria (es. A12 vs D1) non sono mai rilevanti.
bool isMultiTopicAttemptRelevantToSelection({
  required LicenseCategoryId attemptLicenseCategory,
  required LicenseCategoryId currentLicenseCategory,
  required Iterable<int> attemptLessonNumbers,
  required Iterable<int> selectedLessonNumbers,
}) {
  if (attemptLicenseCategory != currentLicenseCategory) return false;

  final selected = selectedLessonNumbers.toSet();
  if (selected.isEmpty) return false;

  final attempt = <int>{};
  for (final lesson in attemptLessonNumbers) {
    if (lesson <= 0) continue;
    attempt.add(lesson);
  }
  if (attempt.isEmpty) return false;

  return attempt.every(selected.contains);
}

/// Conta le schede Multischeda completate rilevanti per la selezione.
///
/// Ogni attempt persistito = 1 scheda. Dedup per `(sessionId, sheetIndex)`
/// per evitare doppio conteggio su retry/idempotenza.
/// Filtra anche per [currentLicenseCategory] (defense-in-depth oltre al repo).
int countCompletedRelevantMultiTopicSheets({
  required Iterable<MultiTopicQuizAttemptSummary> attempts,
  required LicenseCategoryId currentLicenseCategory,
  required Iterable<int> selectedLessonNumbers,
}) {
  final seen = <String>{};
  var count = 0;
  for (final attempt in attempts) {
    if (!isMultiTopicAttemptRelevantToSelection(
      attemptLicenseCategory: attempt.licenseCategory,
      currentLicenseCategory: currentLicenseCategory,
      attemptLessonNumbers: attempt.lessonNumbers,
      selectedLessonNumbers: selectedLessonNumbers,
    )) {
      continue;
    }
    final key = '${attempt.sessionId}:${attempt.sheetIndex}';
    if (!seen.add(key)) continue;
    count++;
  }
  return count;
}

/// Schede ancora da svolgere per la selezione corrente.
int remainingMultiTopicSheets({
  required int catalogActionableTotal,
  required int completedRelevantCount,
}) {
  if (catalogActionableTotal <= 0) return 0;
  final remaining = catalogActionableTotal - completedRelevantCount;
  return remaining < 0 ? 0 : remaining;
}
