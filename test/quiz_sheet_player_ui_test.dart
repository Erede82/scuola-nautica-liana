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
import 'package:scuola_nautica_liana/widgets/quiz_question_progress_strip.dart';

QuizQuestion _q(int n, {required String category}) => QuizQuestion(
  id: 'q$n',
  prompt: 'Domanda $n del test layout',
  optionA: 'Opzione A della domanda $n — testo abbastanza lungo',
  optionB: 'Opzione B della domanda $n — testo abbastanza lungo',
  optionC: 'Opzione C della domanda $n — testo abbastanza lungo',
  correctOption: QuizAnswerOption.a,
  lessonNumber: 1,
  licenseCategory: category,
);

class _FakeStudentQuizRepo implements StudentQuizRepository {
  _FakeStudentQuizRepo(this.content);

  final LessonQuizSheetContent content;

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
  }) async => const QuizAttemptSubmitResult(quizResultId: 'result-test');
}

Finder _progressCellsFinder() => find.descendant(
  of: find.byType(QuizQuestionProgressStrip),
  matching: find.byWidgetPredicate(
    (widget) =>
        widget.key is ValueKey<String> &&
        (widget.key! as ValueKey<String>).value.startsWith(
          'quiz-progress-cell-',
        ),
  ),
);

List<Rect> _rectsOf(WidgetTester tester, Finder finder) {
  final count = finder.evaluate().length;
  return List<Rect>.generate(count, (i) => tester.getRect(finder.at(i)));
}

void _expectSingleRow(List<Rect> rects, {required int expectedCount}) {
  expect(rects.length, expectedCount);
  expect(rects, isNotEmpty);
  final firstTop = rects.first.top;
  for (final rect in rects) {
    expect((rect.top - firstTop).abs(), lessThanOrEqualTo(1.0));
    expect(rect.width, greaterThan(0));
    expect(rect.height, greaterThan(0));
  }
}

Future<void> _pumpPlayer(
  WidgetTester tester, {
  required LicenseCategoryId categoryId,
  required int questionCount,
  Size viewport = const Size(1366, 768),
}) async {
  final dbCategory = categoryId == LicenseCategoryId.d1 ? 'D1' : 'A12';
  final questions = List.generate(
    questionCount,
    (i) => _q(i + 1, category: dbCategory),
  );

  studyAccessWritableRepository.applyLessonQuizSheetUnlock(
    categoryId: categoryId,
    lessonNumber: 1,
    sheetNumber: 1,
    unlocked: true,
  );

  await tester.binding.setSurfaceSize(viewport);
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
    studyAccessWritableRepository.resetDemoAssignments();
  });

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: viewport),
      child: MaterialApp(
        home: QuizSheetDetailPage(
          lessonNumber: 1,
          sheetNumber: 1,
          categoryId: categoryId,
          studentQuizRepositoryOverride: _FakeStudentQuizRepo(
            LessonQuizSheetContent(
              quizSetId: 'set-test',
              categoryId: categoryId,
              lessonNumber: 1,
              sheetNumber: 1,
              questions: questions,
            ),
          ),
          quizAttemptRepositoryOverride: _FakeAttemptRepo(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('QuizSheetDetailPage layout desktop', () {
    testWidgets('D1: 15 celle monoriga, ultima risposta sopra la barra', (
      tester,
    ) async {
      await _pumpPlayer(
        tester,
        categoryId: LicenseCategoryId.d1,
        questionCount: 15,
        viewport: const Size(1366, 768),
      );

      expect(find.byType(QuizQuestionProgressStrip), findsOneWidget);
      expect(find.text('1/15'), findsOneWidget);
      _expectSingleRow(
        _rectsOf(tester, _progressCellsFinder()),
        expectedCount: 15,
      );
      expect(tester.takeException(), isNull);

      final optionC = find.textContaining('Opzione C della domanda 1');
      expect(optionC, findsOneWidget);
      await tester.ensureVisible(optionC);
      expect(optionC.hitTestable(), findsOneWidget);
      await tester.tap(optionC);
      await tester.pump();
      expect(tester.takeException(), isNull);

      for (var i = 0; i < 14; i++) {
        await tester.tap(find.text('Avanti'));
        await tester.pumpAndSettle();
      }
      expect(find.text('15/15'), findsOneWidget);
      expect(find.text('Chiudi scheda'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final lastOption = find.textContaining('Opzione A della domanda 15');
      expect(lastOption, findsOneWidget);
      await tester.ensureVisible(lastOption);
      expect(lastOption.hitTestable(), findsOneWidget);

      final lastBottom = tester.getRect(lastOption).bottom;
      final barTop = tester.getRect(find.text('Chiudi scheda')).top;
      expect(lastBottom, lessThanOrEqualTo(barTop + 1.0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('A12: 20 celle monoriga e ultima risposta sopra la barra', (
      tester,
    ) async {
      await _pumpPlayer(
        tester,
        categoryId: LicenseCategoryId.motore,
        questionCount: 20,
        viewport: const Size(1440, 900),
      );

      expect(find.text('1/20'), findsOneWidget);
      _expectSingleRow(
        _rectsOf(tester, _progressCellsFinder()),
        expectedCount: 20,
      );
      expect(tester.takeException(), isNull);

      for (var i = 0; i < 19; i++) {
        await tester.tap(find.text('Avanti'));
        await tester.pumpAndSettle();
      }
      expect(find.text('20/20'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final lastOption = find.textContaining('Opzione A della domanda 20');
      expect(lastOption, findsOneWidget);
      await tester.ensureVisible(lastOption);
      expect(lastOption.hitTestable(), findsOneWidget);

      final lastBottom = tester.getRect(lastOption).bottom;
      final barTop = tester.getRect(find.text('Chiudi scheda')).top;
      expect(lastBottom, lessThanOrEqualTo(barTop + 1.0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('viewport stretta 360×800 D1: 15 celle positive', (
      tester,
    ) async {
      await _pumpPlayer(
        tester,
        categoryId: LicenseCategoryId.d1,
        questionCount: 15,
        viewport: const Size(360, 800),
      );

      expect(find.text('1/15'), findsOneWidget);
      _expectSingleRow(
        _rectsOf(tester, _progressCellsFinder()),
        expectedCount: 15,
      );
      final lastOption = find.textContaining('Opzione C della domanda 1');
      await tester.ensureVisible(lastOption);
      expect(lastOption.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('viewport stretta 360×800 A12: 20 celle positive', (
      tester,
    ) async {
      await _pumpPlayer(
        tester,
        categoryId: LicenseCategoryId.motore,
        questionCount: 20,
        viewport: const Size(360, 800),
      );

      expect(find.text('1/20'), findsOneWidget);
      _expectSingleRow(
        _rectsOf(tester, _progressCellsFinder()),
        expectedCount: 20,
      );
      final lastOption = find.textContaining('Opzione C della domanda 1');
      await tester.ensureVisible(lastOption);
      expect(lastOption.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
