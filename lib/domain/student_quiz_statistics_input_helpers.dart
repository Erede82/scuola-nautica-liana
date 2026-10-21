import '../data/license_catalog.dart';
import '../data/supabase/dto/quiz_sheet_catalog_row.dart';
import '../data/supabase/student_quiz_statistics_data_source.dart';
import '../models/license_models.dart';
import 'student_quiz_statistics_aggregator.dart';
import 'student_quiz_statistics_models.dart';
import 'student_stats_source.dart';

/// Completeness Multischeda (stesso criterio STUDENT.STATS.1).
bool isCompleteMultiTopicStatsAttempt(MultiTopicStatsAttemptRow row) {
  if (row.totalQuestions <= 0) return false;
  if (row.sheetIndex <= 0) return false;
  final accounted =
      row.correctCount + row.wrongCount + row.unansweredCount;
  return accounted == row.totalQuestions;
}

/// Completeness Esame (stesso criterio STUDENT.STATS.1).
bool isCompleteExamStatsAttempt(ExamStatsAttemptRow row) {
  if (row.totalQuestions <= 0) return false;
  final accounted =
      row.correctCount + row.wrongCount + row.unansweredCount;
  return accounted == row.totalQuestions;
}

/// Dedup Multischeda `(session_id, sheet_index)` → più recente `completed_at`.
List<MultiTopicStatsAttemptRow> dedupeMultiTopicStatsAttempts(
  List<MultiTopicStatsAttemptRow> rows,
) {
  final best = <String, MultiTopicStatsAttemptRow>{};
  for (final row in rows) {
    final key = '${row.sessionId}::${row.sheetIndex}';
    final existing = best[key];
    if (existing == null || row.completedAt.isAfter(existing.completedAt)) {
      best[key] = row;
    }
  }
  return best.values.toList(growable: false);
}

/// Catalogo topic da `quiz_sets` kind=lesson (denominatore dinamico).
List<StudentStatsTopicCatalogEntry> catalogEntriesFromLessonQuizSets({
  required LicenseCategoryId categoryId,
  required List<QuizSheetCatalogRow> catalog,
}) {
  final lessonNumbers = <int>{
    for (final row in catalog)
      if (row.kind == 'lesson' && row.lessonNumber > 0) row.lessonNumber,
  };
  final licenseLessons = LicenseCatalog.byId(categoryId).lessons;
  final titleByNumber = <int, String>{
    for (final lesson in licenseLessons) lesson.number: lesson.title,
  };
  final sorted = lessonNumbers.toList()..sort();
  return [
    for (final n in sorted)
      StudentStatsTopicCatalogEntry(
        lessonNumber: n,
        title: titleByNumber[n] ?? 'Lezione $n',
      ),
  ];
}

/// Espande conteggi header scheda in eventi answer-level (topic = lesson).
void addRollupAnswerEvents({
  required List<StudentStatsAnswerEvent> into,
  required StudentStatsSource source,
  required int lessonNumber,
  required DateTime completedAt,
  required int correct,
  required int wrong,
  required int unanswered,
}) {
  if (lessonNumber <= 0) return;
  for (var i = 0; i < correct; i++) {
    into.add(
      StudentStatsAnswerEvent(
        source: source,
        lessonNumber: lessonNumber,
        isCorrect: true,
        isUnanswered: false,
        completedAt: completedAt,
      ),
    );
  }
  for (var i = 0; i < wrong; i++) {
    into.add(
      StudentStatsAnswerEvent(
        source: source,
        lessonNumber: lessonNumber,
        isCorrect: false,
        isUnanswered: false,
        completedAt: completedAt,
      ),
    );
  }
  for (var i = 0; i < unanswered; i++) {
    into.add(
      StudentStatsAnswerEvent(
        source: source,
        lessonNumber: lessonNumber,
        isCorrect: false,
        isUnanswered: true,
        completedAt: completedAt,
      ),
    );
  }
}
