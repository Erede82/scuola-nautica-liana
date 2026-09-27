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
