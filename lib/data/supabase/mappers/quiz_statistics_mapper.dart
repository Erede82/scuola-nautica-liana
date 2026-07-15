import '../../license_catalog.dart';
import '../../../domain/quiz_license_category.dart';
import '../dto/quiz_result_row.dart';
import '../dto/quiz_sheet_catalog_row.dart';
import '../../../models/lesson_quiz_progress.dart';
import '../../../models/lesson_quiz_performance_snapshot.dart';
import '../../../models/license_models.dart';
import '../../../models/quiz_attempt_activity.dart';
import '../../../models/quiz_category_statistics.dart';
import '../../../models/quiz_statistics_summary.dart';

/// Tentativo scheda lezione con metadati coerenti (prerequisito statistiche).
bool isCompleteLessonQuizResult(QuizResultRow row) {
  if (row.kind != 'lesson') return false;
  if (row.totalQuestions <= 0) return false;
  if (row.lessonNumber <= 0 || row.sheetNumber <= 0) return false;
  if (licenseCategoryIdFromDb(row.licenseCategory) == null) return false;

  final accounted = row.correctCount + row.wrongCount + row.unansweredCount;
  return accounted == row.totalQuestions;
}

/// Tentativo valido per statistiche: metadati coerenti + answer count esatto.
bool isCompleteQuizStatisticsAttempt({
  required QuizResultRow result,
  required int? answerCount,
}) {
  if (!isCompleteLessonQuizResult(result)) return false;
  if (answerCount == null) return false;
  return answerCount == result.totalQuestions;
}

/// Esito partizione tentativi in validi vs ignorati.
class QuizStatisticsAttemptPartition {
  const QuizStatisticsAttemptPartition({
    required this.validResults,
    required this.ignoredIncompleteAttempts,
  });

  final List<QuizResultRow> validResults;
  final int ignoredIncompleteAttempts;
}

/// Separa tentativi validi da quelli ignorati (per result.id).
QuizStatisticsAttemptPartition partitionStatisticsAttempts({
  required List<QuizResultRow> rows,
  required Map<String, int> answerCounts,
}) {
  final valid = <QuizResultRow>[];
  var ignored = 0;

  for (final row in rows) {
    if (isCompleteQuizStatisticsAttempt(
      result: row,
      answerCount: answerCounts[row.id],
    )) {
      valid.add(row);
    } else {
      ignored++;
    }
  }

  return QuizStatisticsAttemptPartition(
    validResults: valid,
    ignoredIncompleteAttempts: ignored,
  );
}

/// Filtra solo tentativi completi di schede lezione (solo metadati).
List<QuizResultRow> filterCompleteLessonResults(Iterable<QuizResultRow> rows) {
  return rows.where(isCompleteLessonQuizResult).toList(growable: false);
}

DateTime activityTimestamp(QuizResultRow row) {
  return row.completedAt ??
      row.createdAt ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

/// Ordine deterministico attività: timestamp ↓, lezione ↓, scheda ↓, id ↓.
int compareQuizResultsByActivity(QuizResultRow a, QuizResultRow b) {
  final byTime = activityTimestamp(b).compareTo(activityTimestamp(a));
  if (byTime != 0) return byTime;

  final byLesson = b.lessonNumber.compareTo(a.lessonNumber);
  if (byLesson != 0) return byLesson;

  final bySheet = b.sheetNumber.compareTo(a.sheetNumber);
  if (bySheet != 0) return bySheet;

  return b.id.compareTo(a.id);
}

List<QuizResultRow> sortQuizResultsByActivity(List<QuizResultRow> rows) {
  final sorted = List<QuizResultRow>.from(rows)
    ..sort(compareQuizResultsByActivity);
  return sorted;
}

double errorPercentageForResult(QuizResultRow row) {
  if (row.totalQuestions <= 0) return 0;
  final errors = row.wrongCount + row.unansweredCount;
  return errors * 100 / row.totalQuestions;
}

double accuracyPercentageForCounts({
  required int correctCount,
  required int totalQuestions,
}) {
  if (totalQuestions <= 0) return 0;
  return correctCount * 100 / totalQuestions;
}

double errorPercentageForCounts({
  required int wrongCount,
  required int unansweredCount,
  required int totalQuestions,
}) {
  if (totalQuestions <= 0) return 0;
  return (wrongCount + unansweredCount) * 100 / totalQuestions;
}

double averageWrongAnswersPerSheet({
  required int wrongCount,
  required int completedSheetsCount,
}) {
  if (completedSheetsCount <= 0) return 0;
  return wrongCount / completedSheetsCount;
}

double clampCompletionPercentage({
  required int completed,
  required int available,
}) {
  if (available <= 0) return 0;
  return (completed / available * 100).clamp(0, 100).toDouble();
}

/// Schede uniche completate per lezione (distinct `quiz_set_id`).
///
/// Usato solo per diagnostica legacy; il progresso catalogo usa
/// [completedUniqueQuizSetIdsByLessonFromCatalog].
Map<int, Set<String>> completedUniqueQuizSetIdsByLesson(
  Iterable<QuizResultRow> completeResults,
) {
  final byLesson = <int, Set<String>>{};
  for (final row in completeResults) {
    if (row.quizSetId.isEmpty) continue;
    byLesson.putIfAbsent(row.lessonNumber, () => <String>{}).add(row.quizSetId);
  }
  return byLesson;
}

/// Deduplica il catalogo per `quiz_set_id`.
///
/// Se lo stesso id compare più volte con metadati discordanti, mantiene la
/// prima riga valida in ordine deterministico (lessonNumber, sheetNumber):
/// ogni id contribuisce una sola volta e a una sola lezione.
Map<String, QuizSheetCatalogRow> deduplicatedCatalogByQuizSetId(
  Iterable<QuizSheetCatalogRow> catalog,
) {
  final validRows =
      catalog
          .where(
            (row) =>
                row.kind == 'lesson' &&
                row.id.isNotEmpty &&
                row.lessonNumber > 0,
          )
          .toList(growable: false)
        ..sort((a, b) {
          final byLesson = a.lessonNumber.compareTo(b.lessonNumber);
          if (byLesson != 0) return byLesson;
          return a.sheetNumber.compareTo(b.sheetNumber);
        });

  final byId = <String, QuizSheetCatalogRow>{};
  for (final row in validRows) {
    byId.putIfAbsent(row.id, () => row);
  }
  return byId;
}

/// Conteggio schede disponibili per lezione dal catalogo deduplicato.
Map<int, int> availableSheetsCountByLesson(
  Iterable<QuizSheetCatalogRow> catalog,
) {
  final counts = <int, int>{};
  for (final row in deduplicatedCatalogByQuizSetId(catalog).values) {
    counts[row.lessonNumber] = (counts[row.lessonNumber] ?? 0) + 1;
  }
  return counts;
}

/// Completamenti unici intersecati col catalogo, raggruppati per lezione catalogo.
Map<int, Set<String>> completedUniqueQuizSetIdsByLessonFromCatalog({
  required Iterable<QuizResultRow> completeResults,
  required Map<String, QuizSheetCatalogRow> catalogById,
}) {
  final completedInCatalog = <String>{};
  for (final row in completeResults) {
    final quizSetId = row.quizSetId;
    if (quizSetId.isEmpty || !catalogById.containsKey(quizSetId)) continue;
    completedInCatalog.add(quizSetId);
  }

  final byLesson = <int, Set<String>>{};
  for (final quizSetId in completedInCatalog) {
    final catalogRow = catalogById[quizSetId]!;
    byLesson
        .putIfAbsent(catalogRow.lessonNumber, () => <String>{})
        .add(quizSetId);
  }
  return byLesson;
}

CategoryQuizProgress buildCategoryQuizProgress({
  required LicenseCategoryId categoryId,
  required List<QuizSheetCatalogRow> catalog,
  required List<QuizResultRow> completeResults,
}) {
  final category = LicenseCatalog.byId(categoryId);
  final catalogById = deduplicatedCatalogByQuizSetId(catalog);
  final availableByLesson = availableSheetsCountByLesson(catalog);
  final completedByLesson = completedUniqueQuizSetIdsByLessonFromCatalog(
    completeResults: completeResults,
    catalogById: catalogById,
  );

  final lessonProgress = <LessonQuizProgress>[];
  var totalAvailable = 0;
  var totalCompletedUnique = 0;
  var completedLessons = 0;
  var availableLessons = 0;
  var inProgressLessons = 0;

  for (final lesson in category.lessons) {
    final available = availableByLesson[lesson.number] ?? 0;
    final completedUnique = completedByLesson[lesson.number]?.length ?? 0;
    final isAvailable = available > 0;
    final percentage = clampCompletionPercentage(
      completed: completedUnique,
      available: available,
    );
    final isComplete = isAvailable && completedUnique >= available;

    if (isAvailable) {
      availableLessons++;
      totalAvailable += available;
      totalCompletedUnique += completedUnique;
      if (isComplete) {
        completedLessons++;
      } else if (completedUnique > 0) {
        inProgressLessons++;
      }
    }

    lessonProgress.add(
      LessonQuizProgress(
        lessonNumber: lesson.number,
        lessonTitle: lesson.title,
        availableSheetsCount: available,
        completedUniqueSheetsCount: completedUnique,
        completionPercentage: percentage,
        isAvailable: isAvailable,
        isComplete: isComplete,
      ),
    );
  }

  lessonProgress.sort((a, b) => a.lessonNumber.compareTo(b.lessonNumber));

  return CategoryQuizProgress(
    totalAvailableSheets: totalAvailable,
    totalCompletedUniqueSheets: totalCompletedUnique,
    overallCompletionPercentage: clampCompletionPercentage(
      completed: totalCompletedUnique,
      available: totalAvailable,
    ),
    lessonProgress: lessonProgress,
    completedLessonsCount: completedLessons,
    availableLessonsCount: availableLessons,
    inProgressLessonsCount: inProgressLessons,
  );
}

QuizStatisticsSummary buildQuizStatisticsSummary({
  required List<QuizResultRow> completeResults,
  required int ignoredIncompleteAttempts,
  List<LessonQuizPerformanceSnapshot>? lessonSnapshots,
  required LicenseCategoryId categoryId,
}) {
  if (completeResults.isEmpty) {
    return QuizStatisticsSummary(
      completedSheetsCount: 0,
      totalQuestions: 0,
      correctCount: 0,
      wrongCount: 0,
      unansweredCount: 0,
      accuracyPercentage: 0,
      errorPercentage: 0,
      averageErrorsPerSheet: 0,
      ignoredIncompleteAttempts: ignoredIncompleteAttempts,
    );
  }

  var totalQuestions = 0;
  var correctCount = 0;
  var wrongCount = 0;
  var unansweredCount = 0;

  for (final row in completeResults) {
    totalQuestions += row.totalQuestions;
    correctCount += row.correctCount;
    wrongCount += row.wrongCount;
    unansweredCount += row.unansweredCount;
  }

  final completedSheetsCount = completeResults.length;

  final sortedByActivity = sortQuizResultsByActivity(completeResults);
  final latest = sortedByActivity.first;

  int? weakestLessonNumber;
  int? strongestLessonNumber;
  final snapshots =
      lessonSnapshots ??
      buildLessonPerformanceSnapshots(
        completeResults: completeResults,
        categoryId: categoryId,
      );

  if (snapshots.isNotEmpty) {
    final sortedLessons = List<LessonQuizPerformanceSnapshot>.from(snapshots)
      ..sort(
        (a, b) => b.averageErrorPercentage.compareTo(a.averageErrorPercentage),
      );
    weakestLessonNumber = sortedLessons.first.lessonNumber;
    strongestLessonNumber = sortedLessons.last.lessonNumber;
  }

  return QuizStatisticsSummary(
    completedSheetsCount: completedSheetsCount,
    totalQuestions: totalQuestions,
    correctCount: correctCount,
    wrongCount: wrongCount,
    unansweredCount: unansweredCount,
    accuracyPercentage: accuracyPercentageForCounts(
      correctCount: correctCount,
      totalQuestions: totalQuestions,
    ),
    errorPercentage: errorPercentageForCounts(
      wrongCount: wrongCount,
      unansweredCount: unansweredCount,
      totalQuestions: totalQuestions,
    ),
    averageErrorsPerSheet: averageWrongAnswersPerSheet(
      wrongCount: wrongCount,
      completedSheetsCount: completedSheetsCount,
    ),
    ignoredIncompleteAttempts: ignoredIncompleteAttempts,
    lastActivityAt: activityTimestamp(latest),
    lastLessonNumber: latest.lessonNumber,
    lastSheetNumber: latest.sheetNumber,
    weakestLessonNumber: weakestLessonNumber,
    strongestLessonNumber: strongestLessonNumber,
  );
}

List<LessonQuizPerformanceSnapshot> buildLessonPerformanceSnapshots({
  required List<QuizResultRow> completeResults,
  required LicenseCategoryId categoryId,
}) {
  if (completeResults.isEmpty) return const [];

  final category = LicenseCatalog.byId(categoryId);
  final titleByLesson = {
    for (final lesson in category.lessons) lesson.number: lesson.title,
  };

  final byLesson = <int, List<QuizResultRow>>{};
  for (final row in completeResults) {
    byLesson.putIfAbsent(row.lessonNumber, () => []).add(row);
  }

  final snapshots = <LessonQuizPerformanceSnapshot>[];
  for (final entry in byLesson.entries) {
    final lessonNumber = entry.key;
    final rows = entry.value;

    var totalQuestions = 0;
    var wrongCount = 0;
    var unansweredCount = 0;
    for (final row in rows) {
      totalQuestions += row.totalQuestions;
      wrongCount += row.wrongCount;
      unansweredCount += row.unansweredCount;
    }

    snapshots.add(
      LessonQuizPerformanceSnapshot(
        categoryId: categoryId,
        lessonNumber: lessonNumber,
        lessonTitle: titleByLesson[lessonNumber] ?? 'Lezione $lessonNumber',
        totalAttempts: rows.length,
        averageErrorPercentage: errorPercentageForCounts(
          wrongCount: wrongCount,
          unansweredCount: unansweredCount,
          totalQuestions: totalQuestions,
        ),
      ),
    );
  }

  snapshots.sort((a, b) => a.lessonNumber.compareTo(b.lessonNumber));
  return snapshots;
}

List<QuizAttemptActivity> buildRecentAttemptActivities({
  required List<QuizResultRow> completeResults,
  int limit = 10,
}) {
  if (completeResults.isEmpty || limit <= 0) return const [];

  final sorted = sortQuizResultsByActivity(completeResults);

  return sorted
      .take(limit)
      .map(
        (row) => QuizAttemptActivity(
          quizResultId: row.id,
          lessonNumber: row.lessonNumber,
          sheetNumber: row.sheetNumber,
          totalQuestions: row.totalQuestions,
          correctCount: row.correctCount,
          wrongCount: row.wrongCount,
          unansweredCount: row.unansweredCount,
          errorPercentage: errorPercentageForResult(row),
          completedAt: activityTimestamp(row),
        ),
      )
      .toList(growable: false);
}

QuizCategoryStatistics buildQuizCategoryStatistics({
  required LicenseCategoryId categoryId,
  required List<QuizResultRow> results,
  required List<QuizSheetCatalogRow> catalog,
  required int ignoredIncompleteAttempts,
  int recentAttemptsLimit = 10,
}) {
  final progress = buildCategoryQuizProgress(
    categoryId: categoryId,
    catalog: catalog,
    completeResults: results,
  );

  if (results.isEmpty) {
    if (ignoredIncompleteAttempts > 0) {
      return QuizCategoryStatistics.ignoredOnly(
        categoryId: categoryId,
        ignoredIncompleteAttempts: ignoredIncompleteAttempts,
        progress: progress,
      );
    }
    return QuizCategoryStatistics.empty(categoryId, progress: progress);
  }

  final lessonSnapshots = buildLessonPerformanceSnapshots(
    completeResults: results,
    categoryId: categoryId,
  );
  final summary = buildQuizStatisticsSummary(
    completeResults: results,
    ignoredIncompleteAttempts: ignoredIncompleteAttempts,
    lessonSnapshots: lessonSnapshots,
    categoryId: categoryId,
  );
  final recentAttempts = buildRecentAttemptActivities(
    completeResults: results,
    limit: recentAttemptsLimit,
  );

  return QuizCategoryStatistics(
    categoryId: categoryId,
    summary: summary,
    lessonSnapshots: lessonSnapshots,
    recentAttempts: recentAttempts,
    progress: progress,
  );
}
