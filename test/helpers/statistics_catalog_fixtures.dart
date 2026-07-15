import 'package:scuola_nautica_liana/data/supabase/dto/quiz_sheet_catalog_row.dart';

/// Id quiz set allineato a [testLessonSheetCatalog].
String testCatalogQuizSetId({
  required String licenseCategory,
  required int lessonNumber,
  required int sheetNumber,
}) => 'set-$licenseCategory-l$lessonNumber-s$sheetNumber';

/// Catalogo quiz_sets fittizio per test (allineato a LicenseCatalog A12/D1).
List<QuizSheetCatalogRow> testLessonSheetCatalog({
  required String licenseCategory,
  Map<int, int>? sheetsPerLesson,
}) {
  final counts =
      sheetsPerLesson ??
      const {
        1: 24,
        2: 24,
        3: 24,
        4: 28,
        5: 20,
        6: 20,
        7: 36,
        8: 20,
        9: 20,
        10: 16,
        11: 28,
        12: 16,
        13: 16,
        14: 36,
      };

  final rows = <QuizSheetCatalogRow>[];
  for (final entry in counts.entries) {
    for (var sheet = 1; sheet <= entry.value; sheet++) {
      rows.add(
        QuizSheetCatalogRow(
          id: 'set-$licenseCategory-l${entry.key}-s$sheet',
          kind: 'lesson',
          licenseCategory: licenseCategory,
          lessonNumber: entry.key,
          sheetNumber: sheet,
        ),
      );
    }
  }
  return rows;
}

int testCatalogTotalSheets(Map<int, int>? sheetsPerLesson) {
  final counts =
      sheetsPerLesson ??
      const {
        1: 24,
        2: 24,
        3: 24,
        4: 28,
        5: 20,
        6: 20,
        7: 36,
        8: 20,
        9: 20,
        10: 16,
        11: 28,
        12: 16,
        13: 16,
        14: 36,
      };
  return counts.values.fold<int>(0, (sum, value) => sum + value);
}

/// Catalogo D1 con alcune lezioni senza schede (es. lezione 14 assente).
List<QuizSheetCatalogRow> testD1PartialCatalog() {
  return testLessonSheetCatalog(
    licenseCategory: 'D1',
    sheetsPerLesson: const {
      1: 24,
      2: 24,
      3: 24,
      4: 28,
      5: 20,
      6: 20,
      7: 36,
      8: 20,
      9: 20,
      10: 16,
      11: 28,
      12: 16,
      13: 16,
    },
  );
}
