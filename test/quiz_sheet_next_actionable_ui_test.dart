import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/models/lesson_quiz_sheet_content.dart';
import 'package:scuola_nautica_liana/models/lesson_sheet_completion_snapshot.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';
import 'package:scuola_nautica_liana/models/quiz_question.dart';
import 'package:scuola_nautica_liana/pages/quiz_sheet_detail_page.dart';
import 'package:scuola_nautica_liana/repositories/quiz_attempt_repository.dart';
import 'package:scuola_nautica_liana/repositories/student_quiz_repository.dart';
import 'package:scuola_nautica_liana/repositories/study_access_repository.dart';

QuizQuestion _q(int n) => QuizQuestion(
  id: 'q$n',
  prompt: 'Domanda $n next-actionable',
  optionA: 'Opzione A della domanda $n',
  optionB: 'Opzione B della domanda $n',
  optionC: 'Opzione C della domanda $n',
  correctOption: QuizAnswerOption.a,
  lessonNumber: 1,
  licenseCategory: 'A12',
);

class _FakeStudentQuizRepo implements StudentQuizRepository {
  _FakeStudentQuizRepo({
    required this.content,
    required this.sheetNumbersByLesson,
  });

  final LessonQuizSheetContent content;
  final Map<int, List<int>> sheetNumbersByLesson;
  int fetchSheetNumbersCalls = 0;

  @override
  Future<LessonQuizSheetContent?> fetchLessonSheetContent({
    required LicenseCategoryId categoryId,
    required int lessonNumber,
    required int sheetNumber,
  }) async => content;

  @override
  Future<List<QuizQuestion>> fetchLessonSheetQuestions({
    required LicenseCategoryId categoryId,
    required int lessonNumber,
    required int sheetNumber,
    int? limit,
  }) async => content.questions;

  @override
  Future<LessonSheetCompletionSnapshot> fetchLessonSheetCompletion({
    required LicenseCategoryId categoryId,
    required int lessonNumber,
  }) async => LessonSheetCompletionSnapshot.empty;

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
  }) async {
    fetchSheetNumbersCalls++;
    return sheetNumbersByLesson;
  }
}

class _FakeAttemptRepo implements QuizAttemptRepository {
  @override
  Future<QuizAttemptSubmitResult> submitLessonSheetAttempt({
    required String quizSetId,
    required List<QuizQuestion> questions,
    required List<QuizAnswerOption?> answers,
    required DateTime startedAt,
    required DateTime completedAt,
    String? existingQuizResultId,
  }) async => const QuizAttemptSubmitResult(quizResultId: 'result-next');
}

Future<_FakeStudentQuizRepo> _pumpToSummary(
  WidgetTester tester, {
  required int currentSheet,
  required Set<int> unlockedSheets,
  required List<int> catalogSheets,
}) async {
  const viewport = Size(1100, 1400);
  final questions = List.generate(2, (i) => _q(i + 1));
  final repo = _FakeStudentQuizRepo(
    content: LessonQuizSheetContent(
      quizSetId: 'set-next',
      categoryId: LicenseCategoryId.motore,
      lessonNumber: 1,
      sheetNumber: currentSheet,
      questions: questions,
    ),
    sheetNumbersByLesson: {1: catalogSheets},
  );

  for (final sheet in unlockedSheets) {
    studyAccessWritableRepository.applyLessonQuizSheetUnlock(
      categoryId: LicenseCategoryId.motore,
      lessonNumber: 1,
      sheetNumber: sheet,
      unlocked: true,
    );
  }

  await tester.binding.setSurfaceSize(viewport);
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
    studyAccessWritableRepository.resetDemoAssignments();
  });

  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(size: viewport),
      child: MaterialApp(
        home: QuizSheetDetailPage(
          lessonNumber: 1,
          sheetNumber: currentSheet,
          categoryId: LicenseCategoryId.motore,
          studentQuizRepositoryOverride: repo,
          quizAttemptRepositoryOverride: _FakeAttemptRepo(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  // Answer both questions and close.
  await tester.tap(find.text('Opzione A della domanda 1'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Avanti'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Opzione A della domanda 2'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Chiudi scheda'));
  await tester.pumpAndSettle();
  expect(find.text('Riepilogo scheda'), findsOneWidget);
  return repo;
}

void main() {
  group('QuizSheetDetailPage next actionable CTA', () {
    testWidgets(
      'A. unlock 1..4 current 4 → no Prossima scheda (skips locked 5)',
      (tester) async {
        final repo = await _pumpToSummary(
          tester,
          currentSheet: 4,
          unlockedSheets: {1, 2, 3, 4},
          catalogSheets: const [1, 2, 3, 4, 5, 6],
        );

        expect(find.textContaining('Prossima scheda'), findsNothing);
        expect(
          find.textContaining('Non ci sono altre schede abilitate'),
          findsOneWidget,
        );
        // Catalog fetched once at load — not after close/summary.
        expect(repo.fetchSheetNumbersCalls, 1);
      },
    );

    testWidgets('B. unlock {1,2,4,6} current 2 → Prossima scheda (4)', (
      tester,
    ) async {
      await _pumpToSummary(
        tester,
        currentSheet: 2,
        unlockedSheets: {1, 2, 4, 6},
        catalogSheets: const [1, 2, 3, 4, 5, 6],
      );

      expect(find.text('Prossima scheda (4)'), findsOneWidget);
      expect(find.textContaining('Prossima scheda (3)'), findsNothing);
    });

    testWidgets('C. unlock {1,2,4,6} current 4 → Prossima scheda (6)', (
      tester,
    ) async {
      await _pumpToSummary(
        tester,
        currentSheet: 4,
        unlockedSheets: {1, 2, 4, 6},
        catalogSheets: const [1, 2, 3, 4, 5, 6],
      );

      expect(find.text('Prossima scheda (6)'), findsOneWidget);
    });

    testWidgets('D. current last actionable → no next CTA', (tester) async {
      await _pumpToSummary(
        tester,
        currentSheet: 6,
        unlockedSheets: {1, 2, 4, 6},
        catalogSheets: const [1, 2, 3, 4, 5, 6],
      );

      expect(find.textContaining('Prossima scheda'), findsNothing);
      expect(
        find.textContaining('Non ci sono altre schede abilitate'),
        findsOneWidget,
      );
    });

    testWidgets('H. fully unlocked → Prossima scheda (current+1)', (
      tester,
    ) async {
      await _pumpToSummary(
        tester,
        currentSheet: 2,
        unlockedSheets: {1, 2, 3, 4, 5, 6},
        catalogSheets: const [1, 2, 3, 4, 5, 6],
      );

      expect(find.text('Prossima scheda (3)'), findsOneWidget);
    });

    testWidgets('locked sheet empty-state copy is per-scheda', (tester) async {
      studyAccessWritableRepository.resetDemoAssignments();
      // Override esplicito: spegne seed demo e forza lock su questa scheda.
      studyAccessWritableRepository.applyLessonQuizSheetUnlock(
        categoryId: LicenseCategoryId.motore,
        lessonNumber: 1,
        sheetNumber: 5,
        unlocked: false,
      );
      addTearDown(studyAccessWritableRepository.resetDemoAssignments);

      await tester.pumpWidget(
        const MaterialApp(
          home: QuizSheetDetailPage(
            lessonNumber: 1,
            sheetNumber: 5,
            categoryId: LicenseCategoryId.motore,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Scheda non ancora abilitata'), findsOneWidget);
      expect(find.text('Lezione non ancora abilitata'), findsNothing);
      expect(find.textContaining('tutte le schede'), findsNothing);
      expect(find.textContaining('Scheda in attesa'), findsOneWidget);
    });
  });
}
