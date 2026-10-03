import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/models/lesson_quiz_sheet_content.dart';
import 'package:scuola_nautica_liana/models/lesson_sheet_completion_snapshot.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';
import 'package:scuola_nautica_liana/models/quiz_question.dart';
import 'package:scuola_nautica_liana/pages/lesson_quiz_list_page.dart';
import 'package:scuola_nautica_liana/repositories/student_quiz_repository.dart';
import 'package:scuola_nautica_liana/repositories/study_access_repository.dart';

class _FakeRepo implements StudentQuizRepository {
  _FakeRepo({required this.sheetNumbersByLesson});

  final Map<int, List<int>> sheetNumbersByLesson;

  @override
  Future<LessonQuizSheetContent?> fetchLessonSheetContent({
    required LicenseCategoryId categoryId,
    required int lessonNumber,
    required int sheetNumber,
  }) async => null;

  @override
  Future<List<QuizQuestion>> fetchLessonSheetQuestions({
    required LicenseCategoryId categoryId,
    required int lessonNumber,
    required int sheetNumber,
    int? limit,
  }) async => const [];

  @override
  Future<LessonSheetCompletionSnapshot> fetchLessonSheetCompletion({
    required LicenseCategoryId categoryId,
    required int lessonNumber,
  }) async {
    final sheets = sheetNumbersByLesson[lessonNumber] ?? const <int>[];
    return LessonSheetCompletionSnapshot(
      quizSetIdBySheet: {
        for (final sheet in sheets) sheet: 'set-$lessonNumber-$sheet',
      },
      completedSheetNumbers: const {},
    );
  }

  @override
  Future<Map<String, List<QuizQuestion>>> fetchExamQuestionsByTopic({
    required LicenseCategoryId categoryId,
  }) async => {};

  @override
  Future<Map<int, List<QuizQuestion>>> fetchQuestionsForLessons({
    required LicenseCategoryId categoryId,
    required List<int> lessonNumbers,
  }) async => {};

  @override
  Future<Map<int, List<int>>> fetchLessonSheetNumbersByLesson({
    required LicenseCategoryId categoryId,
  }) async => {
    for (final entry in sheetNumbersByLesson.entries)
      entry.key: List<int>.from(entry.value),
  };
}

Future<void> _pumpList(
  WidgetTester tester, {
  required StudentQuizRepository repo,
}) async {
  await tester.binding.setSurfaceSize(const Size(900, 2000));
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(size: Size(900, 2000)),
      child: MaterialApp(
        home: LessonQuizListPage(
          lessonNumber: 2,
          categoryId: LicenseCategoryId.motore,
          studentQuizRepositoryOverride: repo,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('STUDIO.SCHEDE.UX.2 — LessonQuizListPage real sheets', () {
    setUp(() {
      MutableMockStudyAccessRepository.debugAllowDemoAccessSeedOverride = false;
      studyAccessWritableRepository.resetDemoAssignments();
    });

    tearDown(() {
      MutableMockStudyAccessRepository.debugAllowDemoAccessSeedOverride = null;
      studyAccessWritableRepository.resetDemoAssignments();
    });

    testWidgets('renders real quiz_sets sheets, not LicenseCatalog 24', (
      tester,
    ) async {
      for (var s = 1; s <= 6; s++) {
        studyAccessWritableRepository.applyLessonQuizSheetUnlock(
          categoryId: LicenseCategoryId.motore,
          lessonNumber: 2,
          sheetNumber: s,
          unlocked: true,
        );
      }

      await _pumpList(
        tester,
        repo: _FakeRepo(
          sheetNumbersByLesson: {
            2: [1, 2, 3, 4, 5, 6],
          },
        ),
      );

      expect(find.text('Scheda 1'), findsOneWidget);
      expect(find.text('Scheda 6'), findsOneWidget);
      expect(find.text('Scheda 7'), findsNothing);
      expect(find.text('Scheda 24'), findsNothing);
      expect(find.textContaining('6 schede'), findsWidgets);
    });

    testWidgets('locked sheets shown but not actionable in summary count', (
      tester,
    ) async {
      for (var s = 1; s <= 4; s++) {
        studyAccessWritableRepository.applyLessonQuizSheetUnlock(
          categoryId: LicenseCategoryId.motore,
          lessonNumber: 2,
          sheetNumber: s,
          unlocked: true,
        );
      }
      studyAccessWritableRepository.applyLessonQuizSheetUnlock(
        categoryId: LicenseCategoryId.motore,
        lessonNumber: 2,
        sheetNumber: 5,
        unlocked: false,
      );
      studyAccessWritableRepository.applyLessonQuizSheetUnlock(
        categoryId: LicenseCategoryId.motore,
        lessonNumber: 2,
        sheetNumber: 6,
        unlocked: false,
      );

      await _pumpList(
        tester,
        repo: _FakeRepo(
          sheetNumbersByLesson: {
            2: [1, 2, 3, 4, 5, 6],
          },
        ),
      );

      expect(find.text('Scheda 5'), findsOneWidget);
      expect(find.text('Scheda 6'), findsOneWidget);
      expect(find.text('Bloccata'), findsNWidgets(2));
      expect(find.textContaining('Abilitate 4 di 6'), findsOneWidget);
    });

    testWidgets('duplicate sheet_number rows do not inflate list', (
      tester,
    ) async {
      for (var s = 1; s <= 3; s++) {
        studyAccessWritableRepository.applyLessonQuizSheetUnlock(
          categoryId: LicenseCategoryId.motore,
          lessonNumber: 2,
          sheetNumber: s,
          unlocked: true,
        );
      }

      await _pumpList(
        tester,
        repo: _FakeRepo(
          sheetNumbersByLesson: {
            2: [1, 2, 3],
          },
        ),
      );
      expect(find.textContaining('Scheda '), findsNWidgets(3));
    });
  });
}
