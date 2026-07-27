import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/exam_quiz_attempt_models.dart';
import 'package:scuola_nautica_liana/domain/exam_quiz_rules.dart';
import 'package:scuola_nautica_liana/models/lesson_quiz_sheet_content.dart';
import 'package:scuola_nautica_liana/models/lesson_sheet_completion_snapshot.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';
import 'package:scuola_nautica_liana/models/quiz_question.dart';
import 'package:scuola_nautica_liana/pages/quiz_exam_player_page.dart';
import 'package:scuola_nautica_liana/pages/quiz_sheet_detail_page.dart';
import 'package:scuola_nautica_liana/repositories/exam_quiz_attempt_repository.dart';
import 'package:scuola_nautica_liana/repositories/quiz_attempt_repository.dart';
import 'package:scuola_nautica_liana/repositories/student_quiz_repository.dart';
import 'package:scuola_nautica_liana/repositories/study_access_repository.dart';
import 'package:scuola_nautica_liana/theme/quiz_player_visual_tokens.dart';
import 'package:scuola_nautica_liana/widgets/quiz_player_answer_tile.dart';
import 'package:scuola_nautica_liana/widgets/quiz_question_image.dart';
import 'package:scuola_nautica_liana/widgets/quiz_question_progress_strip.dart';
import 'package:scuola_nautica_liana/widgets/quiz_question_prompt_panel.dart';

QuizQuestion _q(int n, {required String category, String? imagePath}) =>
    QuizQuestion(
      id: 'q$n',
      prompt: 'Domanda condivisa $n per coerenza visiva',
      optionA: 'Risposta A della domanda $n con testo lungo',
      optionB: 'Risposta B della domanda $n con testo lungo',
      optionC: 'Risposta C della domanda $n con testo lungo',
      correctOption: QuizAnswerOption.a,
      lessonNumber: 1,
      licenseCategory: category,
      imagePath: imagePath,
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

Future<void> _pumpSheet(
  WidgetTester tester, {
  required LicenseCategoryId categoryId,
  required int count,
  required Size viewport,
  String? imagePath,
}) async {
  final db = categoryId == LicenseCategoryId.d1 ? 'D1' : 'A12';
  final questions = List.generate(
    count,
    (i) => _q(i + 1, category: db, imagePath: i == 0 ? imagePath : null),
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
              quizSetId: 'set',
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

Future<void> _pumpExam(
  WidgetTester tester, {
  required LicenseCategoryId categoryId,
  required int count,
  required Size viewport,
  String? imagePath,
}) async {
  final db = categoryId == LicenseCategoryId.d1 ? 'D1' : 'A12';
  final questions = List.generate(
    count,
    (i) => _q(i + 1, category: db, imagePath: i == 0 ? imagePath : null),
  );
  await tester.binding.setSurfaceSize(viewport);
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: viewport),
      child: MaterialApp(
        home: QuizExamPlayerPage(
          categoryId: categoryId,
          questions: questions,
          clientAttemptToken: 'ui2-token',
          repository: ExamQuizAttemptRepositoryFake(
            submitResult: ExamQuizAttemptSubmitResult(
              idempotent: false,
              attempt: ExamQuizAttemptSummary(
                id: 'att',
                licenseCategory: categoryId,
                completedAt: DateTime.utc(2026, 7, 27),
                duration: const Duration(minutes: 10),
                timeExpired: false,
                totalQuestions: count,
                correctCount: 0,
                wrongCount: count,
                unansweredCount: 0,
                outcome: ExamQuizOutcome.failed,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Finder _progressCells() => find.descendant(
  of: find.byType(QuizQuestionProgressStrip),
  matching: find.byWidgetPredicate(
    (widget) =>
        widget.key is ValueKey<String> &&
        (widget.key! as ValueKey<String>).value.startsWith(
          'quiz-progress-cell-',
        ),
  ),
);

Padding _tileContentPadding(WidgetTester tester) {
  final tileFinder = find.byType(QuizPlayerAnswerTile).first;
  final paddings = tester.widgetList<Padding>(
    find.descendant(of: tileFinder, matching: find.byType(Padding)),
  );
  final match = paddings.where(
    (p) => p.padding == QuizPlayerVisual.answerPadding,
  );
  expect(match, isNotEmpty);
  return match.first;
}

ConstrainedBox? _contentMaxWidthBox(WidgetTester tester) {
  final boxes = tester.widgetList<ConstrainedBox>(find.byType(ConstrainedBox));
  for (final box in boxes) {
    if (box.constraints.maxWidth == QuizPlayerVisual.contentMaxWidth) {
      return box;
    }
  }
  return null;
}

void main() {
  group('QuizPlayerVisual tokens', () {
    test('palette senza bianco puro sulle superfici', () {
      expect(QuizPlayerVisual.pageBackground, isNot(Colors.white));
      expect(QuizPlayerVisual.cardSurface, isNot(Colors.white));
      expect(QuizPlayerVisual.pageBackground, const Color(0xFFF7F3ED));
      expect(QuizPlayerVisual.cardSurface, const Color(0xFFFBF8F3));
      expect(QuizPlayerVisual.cardBorder, const Color(0xFFD8C8B5));
      expect(QuizPlayerVisual.ink, const Color(0xFF171717));
      expect(QuizPlayerVisual.accent, const Color(0xFF005E83));
    });

    testWidgets('esame e scheda condividono font, padding e metriche reali', (
      tester,
    ) async {
      const viewport = Size(1366, 768);
      await _pumpExam(
        tester,
        categoryId: LicenseCategoryId.d1,
        count: 15,
        viewport: viewport,
      );
      final examTile = tester.widget<QuizPlayerAnswerTile>(
        find.byType(QuizPlayerAnswerTile).first,
      );
      final examPadding = _tileContentPadding(tester);
      final examAnswerStyle = QuizPlayerVisual.answerStyle(
        tester.element(find.byType(QuizPlayerAnswerTile).first),
      );
      final examQuestionStyle = QuizPlayerVisual.questionStyle(
        tester.element(find.byType(QuizQuestionPromptPanel)),
      );
      final examScaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(_contentMaxWidthBox(tester), isNotNull);

      await _pumpSheet(
        tester,
        categoryId: LicenseCategoryId.d1,
        count: 15,
        viewport: viewport,
      );
      final sheetTile = tester.widget<QuizPlayerAnswerTile>(
        find.byType(QuizPlayerAnswerTile).first,
      );
      final sheetPadding = _tileContentPadding(tester);
      final sheetAnswerStyle = QuizPlayerVisual.answerStyle(
        tester.element(find.byType(QuizPlayerAnswerTile).first),
      );
      final sheetQuestionStyle = QuizPlayerVisual.questionStyle(
        tester.element(find.byType(QuizQuestionPromptPanel)),
      );
      final sheetScaffold = tester.widget<Scaffold>(
        find.byType(Scaffold).first,
      );
      expect(_contentMaxWidthBox(tester), isNotNull);

      expect(examAnswerStyle.fontSize, sheetAnswerStyle.fontSize);
      expect(examQuestionStyle.fontSize, sheetQuestionStyle.fontSize);
      expect(examTile.minHeight, sheetTile.minHeight);
      expect(examTile.minHeight, QuizPlayerVisual.answerMinHeight);
      expect(examTile.cardRadius, sheetTile.cardRadius);
      expect(examTile.cardRadius, QuizPlayerVisual.cardRadius);
      expect(examTile.contentPadding, QuizPlayerVisual.answerPadding);
      expect(sheetTile.contentPadding, QuizPlayerVisual.answerPadding);
      expect(examTile.contentPadding, sheetTile.contentPadding);
      expect(examPadding.padding, QuizPlayerVisual.answerPadding);
      expect(sheetPadding.padding, QuizPlayerVisual.answerPadding);
      expect(examPadding.padding, sheetPadding.padding);
      expect(examTile.backgroundColor, QuizPlayerVisual.cardSurface);
      expect(sheetTile.backgroundColor, QuizPlayerVisual.cardSurface);
      expect(examTile.borderColor, QuizPlayerVisual.cardBorder);
      expect(sheetTile.borderColor, QuizPlayerVisual.cardBorder);
      expect(examScaffold.backgroundColor, QuizPlayerVisual.pageBackground);
      expect(sheetScaffold.backgroundColor, QuizPlayerVisual.pageBackground);
    });
  });

  group('responsive matrix', () {
    testWidgets('360×800 A12 esame e scheda', (tester) async {
      await _pumpExam(
        tester,
        categoryId: LicenseCategoryId.motore,
        count: 20,
        viewport: const Size(360, 800),
      );
      expect(find.text('1/20'), findsOneWidget);
      expect(_progressCells(), findsNWidgets(20));
      expect(tester.takeException(), isNull);

      await _pumpSheet(
        tester,
        categoryId: LicenseCategoryId.motore,
        count: 20,
        viewport: const Size(360, 800),
      );
      expect(find.text('1/20'), findsOneWidget);
      expect(_progressCells(), findsNWidgets(20));
      expect(tester.takeException(), isNull);
    });

    testWidgets('390×844 D1 esame e scheda', (tester) async {
      await _pumpExam(
        tester,
        categoryId: LicenseCategoryId.d1,
        count: 15,
        viewport: const Size(390, 844),
      );
      expect(find.text('1/15'), findsOneWidget);
      expect(_progressCells(), findsNWidgets(15));
      expect(find.textContaining(':'), findsWidgets);
      expect(find.text('Avanti'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _pumpSheet(
        tester,
        categoryId: LicenseCategoryId.d1,
        count: 15,
        viewport: const Size(390, 844),
      );
      expect(find.text('1/15'), findsOneWidget);
      expect(_progressCells(), findsNWidgets(15));
      expect(find.text('Avanti'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('430×932 D1 esame: timer, risposte, bottom bar', (
      tester,
    ) async {
      await _pumpExam(
        tester,
        categoryId: LicenseCategoryId.d1,
        count: 15,
        viewport: const Size(430, 932),
        imagePath: 'figures/sample.png',
      );
      expect(find.byType(QuizQuestionProgressStrip), findsOneWidget);
      expect(find.text('1/15'), findsOneWidget);
      expect(_progressCells(), findsNWidgets(15));
      expect(find.textContaining(':'), findsWidgets);
      expect(
        find.text('Domanda condivisa 1 per coerenza visiva'),
        findsOneWidget,
      );
      expect(find.byType(QuizQuestionImage), findsOneWidget);

      final imageTop = tester.getTopLeft(find.byType(QuizQuestionImage)).dy;
      final promptTop = tester
          .getTopLeft(find.text('Domanda condivisa 1 per coerenza visiva'))
          .dy;
      expect(imageTop, lessThan(promptTop));

      final last = find.textContaining('Risposta C della domanda 1');
      await tester.ensureVisible(last);
      expect(last.hitTestable(), findsOneWidget);
      expect(find.text('Avanti'), findsOneWidget);
      final lastBottom = tester.getRect(last).bottom;
      final barTop = tester.getRect(find.text('Avanti')).top;
      expect(lastBottom, lessThanOrEqualTo(barTop + 1.0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('430×932 D1 scheda: scale allineata all’esame', (tester) async {
      await _pumpExam(
        tester,
        categoryId: LicenseCategoryId.d1,
        count: 15,
        viewport: const Size(430, 932),
      );
      final examTile = tester.widget<QuizPlayerAnswerTile>(
        find.byType(QuizPlayerAnswerTile).first,
      );
      final examAnswerSize = QuizPlayerVisual.answerStyle(
        tester.element(find.byType(QuizPlayerAnswerTile).first),
      ).fontSize;
      final examQuestionSize = QuizPlayerVisual.questionStyle(
        tester.element(find.byType(QuizQuestionPromptPanel)),
      ).fontSize;

      await _pumpSheet(
        tester,
        categoryId: LicenseCategoryId.d1,
        count: 15,
        viewport: const Size(430, 932),
      );
      expect(find.text('1/15'), findsOneWidget);
      expect(_progressCells(), findsNWidgets(15));
      final sheetTile = tester.widget<QuizPlayerAnswerTile>(
        find.byType(QuizPlayerAnswerTile).first,
      );
      expect(
        QuizPlayerVisual.answerStyle(
          tester.element(find.byType(QuizPlayerAnswerTile).first),
        ).fontSize,
        examAnswerSize,
      );
      expect(
        QuizPlayerVisual.questionStyle(
          tester.element(find.byType(QuizQuestionPromptPanel)),
        ).fontSize,
        examQuestionSize,
      );
      expect(sheetTile.minHeight, examTile.minHeight);
      expect(sheetTile.contentPadding, examTile.contentPadding);
      expect(sheetTile.cardRadius, examTile.cardRadius);

      final last = find.textContaining('Risposta C della domanda 1');
      await tester.ensureVisible(last);
      expect(last.hitTestable(), findsOneWidget);
      expect(find.text('Avanti'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('768×1024 Quiz Esame D1 tablet', (tester) async {
      await _pumpExam(
        tester,
        categoryId: LicenseCategoryId.d1,
        count: 15,
        viewport: const Size(768, 1024),
        imagePath: 'figures/sample.png',
      );
      expect(
        QuizPlayerVisual.isCompact(tester.element(find.byType(Scaffold))),
        isFalse,
      );
      expect(find.text('1/15'), findsOneWidget);
      expect(_progressCells(), findsNWidgets(15));
      expect(find.textContaining(':'), findsWidgets);
      expect(find.byType(QuizQuestionImage), findsOneWidget);
      final last = find.textContaining('Risposta C della domanda 1');
      await tester.ensureVisible(last);
      expect(last.hitTestable(), findsOneWidget);
      expect(find.text('Avanti'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('768×1024 Scheda D1 tablet', (tester) async {
      await _pumpSheet(
        tester,
        categoryId: LicenseCategoryId.d1,
        count: 15,
        viewport: const Size(768, 1024),
      );
      expect(find.text('1/15'), findsOneWidget);
      expect(_progressCells(), findsNWidgets(15));
      expect(tester.takeException(), isNull);
    });

    testWidgets('1366×768 D1 esame e scheda desktop', (tester) async {
      await _pumpExam(
        tester,
        categoryId: LicenseCategoryId.d1,
        count: 15,
        viewport: const Size(1366, 768),
      );
      expect(find.text('1/15'), findsOneWidget);
      expect(_contentMaxWidthBox(tester), isNotNull);
      expect(tester.takeException(), isNull);

      await _pumpSheet(
        tester,
        categoryId: LicenseCategoryId.d1,
        count: 15,
        viewport: const Size(1366, 768),
      );
      expect(find.text('1/15'), findsOneWidget);
      expect(_contentMaxWidthBox(tester), isNotNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('1440×900 Quiz Esame D1 desktop', (tester) async {
      await _pumpExam(
        tester,
        categoryId: LicenseCategoryId.d1,
        count: 15,
        viewport: const Size(1440, 900),
      );
      expect(find.text('1/15'), findsOneWidget);
      expect(_progressCells(), findsNWidgets(15));
      expect(find.textContaining(':'), findsWidgets);
      expect(_contentMaxWidthBox(tester), isNotNull);

      final last = find.textContaining('Risposta C della domanda 1');
      await tester.ensureVisible(last);
      expect(last.hitTestable(), findsOneWidget);
      final lastBottom = tester.getRect(last).bottom;
      final barTop = tester.getRect(find.text('Avanti')).top;
      expect(lastBottom, lessThanOrEqualTo(barTop + 1.0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('1440×900 Scheda D1 desktop', (tester) async {
      await _pumpSheet(
        tester,
        categoryId: LicenseCategoryId.d1,
        count: 15,
        viewport: const Size(1440, 900),
      );
      expect(find.text('1/15'), findsOneWidget);
      expect(_progressCells(), findsNWidgets(15));
      expect(_contentMaxWidthBox(tester), isNotNull);
      expect(tester.takeException(), isNull);
    });
  });

  group('immagine laterale', () {
    testWidgets('sideImageBoxHeight desktop = 140', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: Size(1440, 900)),
            child: Scaffold(
              body: QuizQuestionPromptPanel(
                questionNumber: 1,
                prompt: 'Con figura',
                imagePath: 'figures/sample.png',
              ),
            ),
          ),
        ),
      );
      final height = QuizQuestionPromptPanel.sideImageBoxHeight(
        tester.element(find.byType(QuizQuestionPromptPanel)),
      );
      expect(height, 140);
      expect(height, lessThanOrEqualTo(140));
    });
  });

  group('superfici player', () {
    testWidgets('scheda usa fondo avorio e card calde', (tester) async {
      await _pumpSheet(
        tester,
        categoryId: LicenseCategoryId.d1,
        count: 15,
        viewport: const Size(1366, 768),
      );
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, QuizPlayerVisual.pageBackground);

      final tiles = tester.widgetList<QuizPlayerAnswerTile>(
        find.byType(QuizPlayerAnswerTile),
      );
      for (final tile in tiles) {
        expect(tile.backgroundColor, isNot(Colors.white));
        expect(tile.backgroundColor, isNot(const Color(0xFFFFFFFF)));
      }
    });
  });
}
