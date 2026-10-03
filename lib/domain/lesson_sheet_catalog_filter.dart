import '../data/supabase/dto/quiz_sheet_catalog_row.dart';
import '../models/license_models.dart';

/// Numeri lezione che hanno almeno una scheda reale `kind=lesson` in `quiz_sets`.
///
/// Source of truth per `STUDIO → SCHEDE`. Non hardcodare limiti D1.
Set<int> lessonNumbersWithRealSheets(Iterable<QuizSheetCatalogRow> catalog) {
  final out = <int>{};
  for (final row in catalog) {
    if (row.kind != 'lesson') continue;
    if (row.lessonNumber <= 0) continue;
    out.add(row.lessonNumber);
  }
  return out;
}

/// Filtra le lezioni del catalogo statico alle sole presenti in [quiz_sets].
///
/// Non altera il catalogo teoria / videocorsi / navigazione generale.
List<LessonItem> filterLessonsWithRealSheets({
  required List<LessonItem> catalogLessons,
  required Set<int> lessonNumbersWithSheets,
}) {
  return [
    for (final lesson in catalogLessons)
      if (lessonNumbersWithSheets.contains(lesson.number)) lesson,
  ];
}

/// Sheet number DISTINCT per lezione da catalogo `quiz_sets` (kind=lesson).
///
/// Righe duplicate sullo stesso `sheet_number` contano una sola scheda.
Map<int, List<int>> distinctLessonSheetNumbersByLesson(
  Iterable<QuizSheetCatalogRow> catalog,
) {
  final sets = <int, Set<int>>{};
  for (final row in catalog) {
    if (row.kind != 'lesson') continue;
    if (row.lessonNumber <= 0 || row.sheetNumber <= 0) continue;
    sets.putIfAbsent(row.lessonNumber, () => <int>{}).add(row.sheetNumber);
  }
  return {
    for (final entry in sets.entries) entry.key: (entry.value.toList()..sort()),
  };
}

/// Costruisce mappa lezione → sheet numbers DISTINCT da coppie grezze.
Map<int, List<int>> distinctLessonSheetNumbersFromPairs(
  Iterable<(int lessonNumber, int sheetNumber)> pairs,
) {
  final sets = <int, Set<int>>{};
  for (final pair in pairs) {
    final lessonNumber = pair.$1;
    final sheetNumber = pair.$2;
    if (lessonNumber <= 0 || sheetNumber <= 0) continue;
    sets.putIfAbsent(lessonNumber, () => <int>{}).add(sheetNumber);
  }
  return {
    for (final entry in sets.entries) entry.key: (entry.value.toList()..sort()),
  };
}

/// Schede realmente "da fare": catalogo ∩ unlock per-scheda.
List<int> actionableLessonSheetNumbers({
  required Iterable<int> catalogSheetNumbers,
  required bool Function(int sheetNumber) isSheetUnlocked,
}) {
  final out = <int>[];
  final seen = <int>{};
  for (final sheet in catalogSheetNumbers) {
    if (sheet <= 0 || !seen.add(sheet)) continue;
    if (isSheetUnlocked(sheet)) out.add(sheet);
  }
  out.sort();
  return out;
}

/// Prima scheda actionable con `sheet_number` strettamente maggiore di
/// [currentSheetNumber], oppure `null` se non esiste.
///
/// Usa la stessa pipeline catalogo ∩ unlock (nessuna terza logica).
int? nextActionableLessonSheetNumber({
  required Iterable<int> catalogSheetNumbers,
  required int currentSheetNumber,
  required bool Function(int sheetNumber) isSheetUnlocked,
}) {
  final actionable = actionableLessonSheetNumbers(
    catalogSheetNumbers: catalogSheetNumbers,
    isSheetUnlocked: isSheetUnlocked,
  );
  for (final sheet in actionable) {
    if (sheet > currentSheetNumber) return sheet;
  }
  return null;
}

/// Conteggio actionable per lezione (quiz_sets DISTINCT ∩ unlock).
Map<int, int> actionableLessonSheetCountsByLesson({
  required Map<int, List<int>> sheetNumbersByLesson,
  required bool Function(int lessonNumber, int sheetNumber) isSheetUnlocked,
}) {
  return {
    for (final entry in sheetNumbersByLesson.entries)
      entry.key: actionableLessonSheetNumbers(
        catalogSheetNumbers: entry.value,
        isSheetUnlocked: (sheet) => isSheetUnlocked(entry.key, sheet),
      ).length,
  };
}

/// Somma le schede actionable per gli argomenti selezionati (no double-count).
int sumSelectedLessonSheetCounts({
  required Map<int, int> sheetCountByLesson,
  required Iterable<int> selectedLessonNumbers,
}) {
  final seen = <int>{};
  var total = 0;
  for (final lesson in selectedLessonNumbers) {
    if (!seen.add(lesson)) continue;
    final count = sheetCountByLesson[lesson] ?? 0;
    if (count > 0) total += count;
  }
  return total;
}
