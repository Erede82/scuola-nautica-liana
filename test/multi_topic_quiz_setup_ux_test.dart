import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/models/lesson_quiz_sheet_content.dart';
import 'package:scuola_nautica_liana/models/lesson_sheet_completion_snapshot.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';
import 'package:scuola_nautica_liana/models/quiz_question.dart';
import 'package:scuola_nautica_liana/pages/multi_topic_quiz_player_page.dart';
import 'package:scuola_nautica_liana/pages/multi_topic_quiz_setup_page.dart';
import 'package:scuola_nautica_liana/repositories/student_quiz_repository.dart';
import 'package:scuola_nautica_liana/repositories/study_access_repository.dart';

QuizQuestion _q(String id, {required int lesson}) => QuizQuestion(
  id: id,
  prompt: 'Prompt $id',
  optionA: 'A',
  optionB: 'B',
  optionC: 'C',
  correctOption: QuizAnswerOption.a,
  lessonNumber: lesson,
  licenseCategory: 'A12',
);

class _FakeQuizRepo implements StudentQuizRepository {
  _FakeQuizRepo({
    required this.sheetNumbersByLesson,
    required this.poolByLesson,
    this.throwOnSheetNumbers = false,
  });

  final Map<int, List<int>> sheetNumbersByLesson;
  final Map<int, List<QuizQuestion>> poolByLesson;
  final bool throwOnSheetNumbers;

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
  }) async => LessonSheetCompletionSnapshot.empty;

  @override
  Future<Map<String, List<QuizQuestion>>> fetchExamQuestionsByTopic({
    required LicenseCategoryId categoryId,
  }) async => {};

  @override
  Future<Map<int, List<QuizQuestion>>> fetchQuestionsForLessons({
    required LicenseCategoryId categoryId,
    required List<int> lessonNumbers,
  }) async {
    return {
      for (final lesson in lessonNumbers)
        lesson: List<QuizQuestion>.from(
          poolByLesson[lesson] ?? const <QuizQuestion>[],
        ),
    };
  }

  @override
  Future<Map<int, List<int>>> fetchLessonSheetNumbersByLesson({
    required LicenseCategoryId categoryId,
  }) async {
    if (throwOnSheetNumbers) {
      throw StateError('catalog fetch failed');
    }
    return {
      for (final entry in sheetNumbersByLesson.entries)
        entry.key: List<int>.from(entry.value),
    };
  }
}

void _unlockSheets({required int lessonNumber, required Iterable<int> sheets}) {
  for (final sheet in sheets) {
    studyAccessWritableRepository.applyLessonQuizSheetUnlock(
      categoryId: LicenseCategoryId.motore,
      lessonNumber: lessonNumber,
      sheetNumber: sheet,
      unlocked: true,
    );
  }
}

Future<void> _pumpSetup(
  WidgetTester tester, {
  required StudentQuizRepository repo,
  void Function()? unlockBeforeLoad,
}) async {
  MutableMockStudyAccessRepository.debugAllowDemoAccessSeedOverride = false;
  studyAccessWritableRepository.resetDemoAssignments();
  unlockBeforeLoad?.call();
  addTearDown(() {
    MutableMockStudyAccessRepository.debugAllowDemoAccessSeedOverride = null;
    studyAccessWritableRepository.resetDemoAssignments();
  });

  await tester.pumpWidget(
    MaterialApp(
      home: MultiTopicQuizSetupPage(
        categoryId: LicenseCategoryId.motore,
        studentQuizRepositoryOverride: repo,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _lessonTile(int lessonNumber) => find.text('Lezione $lessonNumber');

Future<void> _toggleLesson(WidgetTester tester, int lessonNumber) async {
  final tile = _lessonTile(lessonNumber);
  expect(tile, findsOneWidget);
  await tester.ensureVisible(tile);
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

void _unlockStandard() {
  _unlockSheets(lessonNumber: 2, sheets: [1, 2, 3, 4, 5, 6]);
  _unlockSheets(lessonNumber: 4, sheets: [1, 2, 3, 4, 5, 6, 7]);
  _unlockSheets(lessonNumber: 6, sheets: [1, 2, 3, 4, 5]);
}

void main() {
  group('STUDIO.SCHEDE.UX.2 — MultiTopicQuizSetupPage live total', () {
    late _FakeQuizRepo repo;

    setUp(() {
      repo = _FakeQuizRepo(
        sheetNumbersByLesson: {
          2: [1, 2, 3, 4, 5, 6],
          4: [1, 2, 3, 4, 5, 6, 7],
          6: [1, 2, 3, 4, 5],
          9: [1, 2, 3],
        },
        poolByLesson: {
          2: List.generate(40, (i) => _q('l2-$i', lesson: 2)),
          4: List.generate(40, (i) => _q('l4-$i', lesson: 4)),
          6: List.generate(40, (i) => _q('l6-$i', lesson: 6)),
          9: List.generate(40, (i) => _q('l9-$i', lesson: 9)),
        },
      );
    });

    testWidgets('L2 only → <2 argomenti, start disabled', (tester) async {
      await _pumpSetup(tester, repo: repo, unlockBeforeLoad: _unlockStandard);

      await _toggleLesson(tester, 2);
      expect(find.textContaining('Seleziona almeno 2 argomenti'), findsWidgets);
      final start = tester.widget<FilledButton>(
        find.byKey(const Key('multi_topic_start_button')),
      );
      expect(start.onPressed, isNull);
    });

    testWidgets('L2+L4 → totale 13 e start crea session.totalSheets=13', (
      tester,
    ) async {
      await _pumpSetup(tester, repo: repo, unlockBeforeLoad: _unlockStandard);

      await _toggleLesson(tester, 2);
      await _toggleLesson(tester, 4);
      expect(
        find.byKey(const Key('multi_topic_total_sheets_value_13')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('multi_topic_start_button')));
      await tester.pumpAndSettle();

      final player = tester.widget<MultiTopicQuizPlayerPage>(
        find.byType(MultiTopicQuizPlayerPage),
      );
      expect(player.session.totalSheets, 13);
      expect(find.text('Scheda 1 di 13'), findsWidgets);
    });

    testWidgets('add L6 → 18; remove L4 → 11', (tester) async {
      await _pumpSetup(tester, repo: repo, unlockBeforeLoad: _unlockStandard);

      await _toggleLesson(tester, 2);
      await _toggleLesson(tester, 4);
      expect(
        find.byKey(const Key('multi_topic_total_sheets_value_13')),
        findsOneWidget,
      );

      await _toggleLesson(tester, 6);
      expect(
        find.byKey(const Key('multi_topic_total_sheets_value_18')),
        findsOneWidget,
      );

      await _toggleLesson(tester, 4);
      expect(
        find.byKey(const Key('multi_topic_total_sheets_value_11')),
        findsOneWidget,
      );
    });

    testWidgets('0 actionable sheets → lesson not selectable', (tester) async {
      await _pumpSetup(
        tester,
        repo: repo,
        unlockBeforeLoad: () {
          _unlockSheets(lessonNumber: 2, sheets: [1, 2, 3, 4, 5, 6]);
          _unlockSheets(lessonNumber: 4, sheets: [1, 2, 3, 4, 5, 6, 7]);
        },
      );

      expect(_lessonTile(2), findsOneWidget);
      expect(_lessonTile(4), findsOneWidget);
      expect(_lessonTile(9), findsNothing);
    });

    testWidgets('rapid toggle non lascia stale total', (tester) async {
      await _pumpSetup(tester, repo: repo, unlockBeforeLoad: _unlockStandard);

      await _toggleLesson(tester, 2);
      await _toggleLesson(tester, 4);
      await _toggleLesson(tester, 6);
      await _toggleLesson(tester, 6);
      await _toggleLesson(tester, 4);
      await _toggleLesson(tester, 4);
      expect(
        find.byKey(const Key('multi_topic_total_sheets_value_13')),
        findsOneWidget,
      );
    });

    testWidgets('fetch error → Start disabled / empty retry', (tester) async {
      final failing = _FakeQuizRepo(
        sheetNumbersByLesson: const {},
        poolByLesson: const {},
        throwOnSheetNumbers: true,
      );
      await _pumpSetup(tester, repo: failing);
      expect(find.text('Errore'), findsOneWidget);
      expect(find.text('INIZIA MULTISCHEDA'), findsNothing);
    });

    testWidgets('locked subset of sheets reduces Multischeda count', (
      tester,
    ) async {
      await _pumpSetup(
        tester,
        repo: repo,
        unlockBeforeLoad: () {
          _unlockSheets(lessonNumber: 2, sheets: [1, 2, 3, 4]);
          _unlockSheets(lessonNumber: 4, sheets: [1, 2, 3, 4, 5, 6, 7]);
        },
      );

      expect(find.textContaining('4 schede'), findsWidgets);
      await _toggleLesson(tester, 2);
      await _toggleLesson(tester, 4);
      expect(
        find.byKey(const Key('multi_topic_total_sheets_value_11')),
        findsOneWidget,
      );
    });
  });
}
