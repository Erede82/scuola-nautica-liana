import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/data/supabase/dto/quiz_result_row.dart';
import 'package:scuola_nautica_liana/data/supabase/dto/quiz_sheet_catalog_row.dart';
import 'package:scuola_nautica_liana/data/supabase/mappers/quiz_statistics_mapper.dart';
import 'package:scuola_nautica_liana/data/supabase/quiz_attempt_history_data_source.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';
import 'package:scuola_nautica_liana/repositories/quiz_statistics_repository.dart';
import 'package:scuola_nautica_liana/widgets/statistics_summary_section.dart';

import 'helpers/statistics_catalog_fixtures.dart';

QuizResultRow _result({
  required String id,
  String? quizSetId,
  required int lessonNumber,
  required int sheetNumber,
  int wrong = 3,
  String licenseCategory = 'A12',
}) {
  return QuizResultRow(
    id: id,
    quizSetId:
        quizSetId ??
        testCatalogQuizSetId(
          licenseCategory: licenseCategory,
          lessonNumber: lessonNumber,
          sheetNumber: sheetNumber,
        ),
    totalQuestions: 20,
    correctCount: 1,
    wrongCount: wrong,
    unansweredCount: 19 - wrong,
    lessonNumber: lessonNumber,
    sheetNumber: sheetNumber,
    licenseCategory: licenseCategory,
    kind: 'lesson',
    completedAt: DateTime.utc(2026, 7, 10, sheetNumber),
  );
}

List<QuizSheetCatalogRow> _catalogRows(
  List<({String id, int lesson, int sheet})> items,
) {
  return items
      .map(
        (item) => QuizSheetCatalogRow(
          id: item.id,
          kind: 'lesson',
          licenseCategory: 'A12',
          lessonNumber: item.lesson,
          sheetNumber: item.sheet,
        ),
      )
      .toList(growable: false);
}

void main() {
  group('buildCategoryQuizProgress', () {
    final a12Catalog = testLessonSheetCatalog(licenseCategory: 'A12');
    final d1Catalog = testLessonSheetCatalog(licenseCategory: 'D1');
    final d1Partial = testD1PartialCatalog();

    test('totale schede disponibili A12 = 328', () {
      final progress = buildCategoryQuizProgress(
        categoryId: LicenseCategoryId.motore,
        catalog: a12Catalog,
        completeResults: const [],
      );

      expect(progress.totalAvailableSheets, 328);
      expect(progress.availableLessonsCount, 14);
      expect(progress.lessonProgress.length, 14);
    });

    test('totale schede disponibili D1 = 328 con catalogo completo', () {
      final progress = buildCategoryQuizProgress(
        categoryId: LicenseCategoryId.d1,
        catalog: d1Catalog,
        completeResults: const [],
      );

      expect(progress.totalAvailableSheets, 328);
    });

    test('D1 con lezioni non disponibili esclude lezione 14', () {
      final progress = buildCategoryQuizProgress(
        categoryId: LicenseCategoryId.d1,
        catalog: d1Partial,
        completeResults: const [],
      );

      expect(
        progress.totalAvailableSheets,
        testCatalogTotalSheets(const {
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
        }),
      );
      expect(progress.availableLessonsCount, 13);
      final lesson14 = progress.lessonProgress.last;
      expect(lesson14.lessonNumber, 14);
      expect(lesson14.isAvailable, isFalse);
      expect(lesson14.availableSheetsCount, 0);
    });

    test('deduplica schede completate per quiz_set_id', () {
      final catalog = _catalogRows([
        (id: 'set-shared', lesson: 1, sheet: 1),
        (id: 'set-2', lesson: 1, sheet: 2),
      ]);
      final results = [
        _result(
          id: 'a1',
          quizSetId: 'set-shared',
          lessonNumber: 1,
          sheetNumber: 1,
        ),
        _result(
          id: 'a2',
          quizSetId: 'set-shared',
          lessonNumber: 1,
          sheetNumber: 1,
        ),
        _result(id: 'a3', quizSetId: 'set-2', lessonNumber: 1, sheetNumber: 2),
      ];

      final progress = buildCategoryQuizProgress(
        categoryId: LicenseCategoryId.motore,
        catalog: catalog,
        completeResults: results,
      );

      expect(progress.totalCompletedUniqueSheets, 2);
      expect(progress.lessonProgress.first.completedUniqueSheetsCount, 2);
    });

    test('percentuale complessiva e clamp massimo 100%', () {
      final results = List<QuizResultRow>.generate(
        6,
        (index) =>
            _result(id: 'r$index', lessonNumber: 1, sheetNumber: index + 1),
      );

      final progress = buildCategoryQuizProgress(
        categoryId: LicenseCategoryId.motore,
        catalog: a12Catalog,
        completeResults: results,
      );

      expect(
        progress.lessonProgress.first.completionPercentage,
        closeTo(25, 0.01),
      );
      expect(progress.overallCompletionPercentage, lessThanOrEqualTo(100));
    });

    test('catalogo vuoto → non disponibile', () {
      final progress = buildCategoryQuizProgress(
        categoryId: LicenseCategoryId.motore,
        catalog: const [],
        completeResults: const [],
      );

      expect(progress.hasCatalog, isFalse);
      expect(progress.totalAvailableSheets, 0);
      for (final lesson in progress.lessonProgress) {
        expect(lesson.isAvailable, isFalse);
      }
    });

    test('lezione con 0 schede catalogo → non disponibile', () {
      final progress = buildCategoryQuizProgress(
        categoryId: LicenseCategoryId.d1,
        catalog: d1Partial,
        completeResults: const [],
      );

      final lesson14 = progress.lessonProgress.singleWhere(
        (l) => l.lessonNumber == 14,
      );
      expect(lesson14.isAvailable, isFalse);
      expect(lesson14.completionPercentage, 0);
    });

    test('lezione con 0 completate → 0% da iniziare', () {
      final progress = buildCategoryQuizProgress(
        categoryId: LicenseCategoryId.motore,
        catalog: a12Catalog,
        completeResults: const [],
      );

      final lesson1 = progress.lessonProgress.first;
      expect(lesson1.isAvailable, isTrue);
      expect(lesson1.completedUniqueSheetsCount, 0);
      expect(lesson1.completionPercentage, 0);
      expect(lesson1.isNotStarted, isTrue);
    });

    test('lezione parzialmente completata → in corso', () {
      final results = [_result(id: 'p1', lessonNumber: 1, sheetNumber: 1)];

      final progress = buildCategoryQuizProgress(
        categoryId: LicenseCategoryId.motore,
        catalog: a12Catalog,
        completeResults: results,
      );

      final lesson1 = progress.lessonProgress.first;
      expect(lesson1.isInProgress, isTrue);
      expect(lesson1.isComplete, isFalse);
      expect(lesson1.completedUniqueSheetsCount, 1);
      expect(lesson1.availableSheetsCount, 24);
    });

    test('lezione al 100% → completata', () {
      final results = List<QuizResultRow>.generate(
        24,
        (index) =>
            _result(id: 'c$index', lessonNumber: 1, sheetNumber: index + 1),
      );

      final progress = buildCategoryQuizProgress(
        categoryId: LicenseCategoryId.motore,
        catalog: a12Catalog,
        completeResults: results,
      );

      final lesson1 = progress.lessonProgress.first;
      expect(lesson1.isComplete, isTrue);
      expect(lesson1.completionPercentage, 100);
      expect(progress.completedLessonsCount, 1);
      expect(progress.inProgressLessonsCount, 0);
    });

    test('argomenti ordinati da 1 a 14', () {
      final progress = buildCategoryQuizProgress(
        categoryId: LicenseCategoryId.motore,
        catalog: a12Catalog,
        completeResults: const [],
      );

      expect(
        progress.lessonProgress.map((l) => l.lessonNumber).toList(),
        List<int>.generate(14, (i) => i + 1),
      );
    });
  });

  group('buildCategoryQuizProgress B3F hardening', () {
    test('catalogo duplicato per quiz_set_id non aumenta disponibili', () {
      final catalog = _catalogRows([
        (id: 'set-1', lesson: 1, sheet: 1),
        (id: 'set-1', lesson: 1, sheet: 1),
        (id: 'set-2', lesson: 1, sheet: 2),
      ]);

      final progress = buildCategoryQuizProgress(
        categoryId: LicenseCategoryId.motore,
        catalog: catalog,
        completeResults: const [],
      );

      expect(progress.totalAvailableSheets, 2);
      expect(progress.lessonProgress.first.availableSheetsCount, 2);
    });

    test('completamento orphan non aumenta il progresso catalogo', () {
      final catalog = _catalogRows([(id: 'set-1', lesson: 1, sheet: 1)]);
      final results = [
        _result(
          id: 'r-orphan',
          quizSetId: 'set-orphan',
          lessonNumber: 1,
          sheetNumber: 9,
        ),
      ];

      final progress = buildCategoryQuizProgress(
        categoryId: LicenseCategoryId.motore,
        catalog: catalog,
        completeResults: results,
      );
      final stats = buildQuizCategoryStatistics(
        categoryId: LicenseCategoryId.motore,
        results: results,
        catalog: catalog,
        ignoredIncompleteAttempts: 0,
      );

      expect(stats.summary.completedSheetsCount, 1);
      expect(progress.totalCompletedUniqueSheets, 0);
      expect(progress.lessonProgress.first.completedUniqueSheetsCount, 0);
    });

    test('completamenti misti intersecano il catalogo', () {
      final catalog = _catalogRows([
        (id: 'set-1', lesson: 1, sheet: 1),
        (id: 'set-2', lesson: 1, sheet: 2),
      ]);
      final results = [
        _result(id: 'r1', quizSetId: 'set-1', lessonNumber: 1, sheetNumber: 1),
        _result(id: 'r2', quizSetId: 'set-1', lessonNumber: 1, sheetNumber: 1),
        _result(
          id: 'r3',
          quizSetId: 'set-orphan',
          lessonNumber: 1,
          sheetNumber: 9,
        ),
      ];

      final progress = buildCategoryQuizProgress(
        categoryId: LicenseCategoryId.motore,
        catalog: catalog,
        completeResults: results,
      );

      expect(progress.totalCompletedUniqueSheets, 1);
      expect(progress.totalAvailableSheets, 2);
      expect(progress.overallCompletionPercentage, 50);
      expect(progress.lessonProgress.first.completedUniqueSheetsCount, 1);
      expect(progress.lessonProgress.first.availableSheetsCount, 2);
    });

    test(
      'completamento attribuito alla lezione del catalogo, non del risultato',
      () {
        final catalog = _catalogRows([(id: 'set-1', lesson: 1, sheet: 1)]);
        final results = [
          _result(
            id: 'r1',
            quizSetId: 'set-1',
            lessonNumber: 2,
            sheetNumber: 1,
          ),
        ];

        final progress = buildCategoryQuizProgress(
          categoryId: LicenseCategoryId.motore,
          catalog: catalog,
          completeResults: results,
        );

        final lesson1 = progress.lessonProgress.firstWhere(
          (lesson) => lesson.lessonNumber == 1,
        );
        final lesson2 = progress.lessonProgress.firstWhere(
          (lesson) => lesson.lessonNumber == 2,
        );

        expect(lesson1.completedUniqueSheetsCount, 1);
        expect(lesson2.completedUniqueSheetsCount, 0);
      },
    );

    test('id duplicato con lezione discordante conta una sola volta', () {
      final catalog = _catalogRows([
        (id: 'set-1', lesson: 1, sheet: 1),
        (id: 'set-1', lesson: 2, sheet: 1),
      ]);

      final progress = buildCategoryQuizProgress(
        categoryId: LicenseCategoryId.motore,
        catalog: catalog,
        completeResults: const [],
      );

      expect(progress.totalAvailableSheets, 1);
      expect(progress.lessonProgress.first.availableSheetsCount, 1);
      expect(
        progress.lessonProgress
            .firstWhere((l) => l.lessonNumber == 2)
            .availableSheetsCount,
        0,
      );
    });

    test('completedUniqueSheetsCount non supera availableSheetsCount', () {
      final catalog = _catalogRows([
        (id: 'set-1', lesson: 1, sheet: 1),
        (id: 'set-2', lesson: 1, sheet: 2),
      ]);
      final results = [
        _result(id: 'r1', quizSetId: 'set-1', lessonNumber: 1, sheetNumber: 1),
        _result(id: 'r2', quizSetId: 'set-2', lessonNumber: 1, sheetNumber: 2),
        _result(
          id: 'r3',
          quizSetId: 'set-orphan',
          lessonNumber: 1,
          sheetNumber: 3,
        ),
      ];

      final progress = buildCategoryQuizProgress(
        categoryId: LicenseCategoryId.motore,
        catalog: catalog,
        completeResults: results,
      );

      expect(
        progress.totalCompletedUniqueSheets,
        lessThanOrEqualTo(progress.totalAvailableSheets),
      );
      for (final lesson in progress.lessonProgress.where(
        (l) => l.isAvailable,
      )) {
        expect(
          lesson.completedUniqueSheetsCount,
          lessThanOrEqualTo(lesson.availableSheetsCount),
        );
      }
    });
  });

  group('soglia media errori', () {
    test('media 3,9 entro soglia', () {
      expect(3.9 <= StatisticsSummarySection.averageErrorThreshold, isTrue);
    });

    test('media 4,0 entro soglia', () {
      expect(4.0 <= StatisticsSummarySection.averageErrorThreshold, isTrue);
    });

    test('media 4,1 sopra soglia', () {
      expect(4.1 <= StatisticsSummarySection.averageErrorThreshold, isFalse);
    });

    test('media errori non include non risposte', () {
      final average = averageWrongAnswersPerSheet(
        wrongCount: 12,
        completedSheetsCount: 3,
      );
      expect(average, 4);
    });
  });

  group('QuizStatisticsRepositoryImpl progresso', () {
    test('storico vuoto con catalogo → dashboard disponibile', () async {
      final dataSource = QuizAttemptHistoryDataSourceInMemory(
        catalog: testLessonSheetCatalog(licenseCategory: 'A12'),
      );
      final repository = QuizStatisticsRepositoryImpl(
        dataSource: dataSource,
        resolveUserId: () async => 'user-test',
      );

      final stats = await repository.fetchCategoryStatistics(
        categoryId: LicenseCategoryId.motore,
      );

      expect(stats.hasData, isFalse);
      expect(stats.hasCatalog, isTrue);
      expect(stats.showDashboard, isTrue);
      expect(stats.progress.totalAvailableSheets, 328);
      expect(stats.progress.totalCompletedUniqueSheets, 0);
    });

    test('fetch include catalogo e risultati', () async {
      final results = [_result(id: 'r1', lessonNumber: 1, sheetNumber: 1)];
      final dataSource = QuizAttemptHistoryDataSourceInMemory(
        results: results,
        answerCountsByResultId: {results.first.id: 20},
        catalog: testLessonSheetCatalog(licenseCategory: 'A12'),
      );
      final repository = QuizStatisticsRepositoryImpl(
        dataSource: dataSource,
        resolveUserId: () async => 'user-test',
      );

      final stats = await repository.fetchCategoryStatistics(
        categoryId: LicenseCategoryId.motore,
      );

      expect(stats.summary.completedSheetsCount, 1);
      expect(stats.progress.totalCompletedUniqueSheets, 1);
      expect(stats.summary.completedSheetsCount, 1);
    });
  });
}
