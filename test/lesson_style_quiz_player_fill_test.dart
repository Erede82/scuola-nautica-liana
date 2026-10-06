import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/multi_topic_quiz_attempt_result.dart';
import 'package:scuola_nautica_liana/domain/multi_topic_quiz_session.dart';
import 'package:scuola_nautica_liana/models/lesson_quiz_sheet_content.dart';
import 'package:scuola_nautica_liana/models/lesson_sheet_completion_snapshot.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';
import 'package:scuola_nautica_liana/models/quiz_question.dart';
import 'package:scuola_nautica_liana/pages/multi_topic_quiz_player_page.dart';
import 'package:scuola_nautica_liana/pages/quiz_exam_player_page.dart';
import 'package:scuola_nautica_liana/pages/quiz_sheet_detail_page.dart';
import 'package:scuola_nautica_liana/repositories/exam_quiz_attempt_repository.dart';
import 'package:scuola_nautica_liana/repositories/multi_topic_quiz_attempt_repository.dart';
import 'package:scuola_nautica_liana/repositories/quiz_attempt_repository.dart';
import 'package:scuola_nautica_liana/repositories/student_quiz_repository.dart';
import 'package:scuola_nautica_liana/repositories/study_access_repository.dart';
import 'package:scuola_nautica_liana/theme/quiz_player_density.dart';
import 'package:scuola_nautica_liana/theme/quiz_player_visual_tokens.dart';
import 'package:scuola_nautica_liana/widgets/lesson_style_quiz_player_shell.dart';
import 'package:scuola_nautica_liana/widgets/quiz_player_answer_tile.dart';

const _imagePath = 'assets/images/welcome/welcome_boat.jpg';

QuizQuestion _q({
  required int n,
  String? imagePath,
  String? prompt,
  String? optionText,
}) => QuizQuestion(
  id: 'fill-q$n',
  prompt: prompt ?? 'Domanda fill $n — testo Scheda/Multischeda',
  optionA: optionText ?? 'Opzione A fill $n',
  optionB: optionText ?? 'Opzione B fill $n',
  optionC: optionText ?? 'Opzione C fill $n',
  correctOption: QuizAnswerOption.a,
  lessonNumber: 1,
  licenseCategory: 'A12',
  imagePath: imagePath,
);

List<QuizQuestion> _sheetQs({String? imagePath, String? prompt}) =>
    List.generate(
      20,
      (i) => _q(n: i + 1, imagePath: i == 0 ? imagePath : null, prompt: prompt),
    );

class _FakeStudentRepo implements StudentQuizRepository {
  _FakeStudentRepo(this.questions);

  final List<QuizQuestion> questions;

  @override
  Future<LessonQuizSheetContent?> fetchLessonSheetContent({
    required LicenseCategoryId categoryId,
    required int lessonNumber,
    required int sheetNumber,
  }) async => LessonQuizSheetContent(
    quizSetId: 'set-fill',
    categoryId: categoryId,
    lessonNumber: lessonNumber,
    sheetNumber: sheetNumber,
    questions: questions,
  );

  @override
  Future<List<QuizQuestion>> fetchLessonSheetQuestions({
    required LicenseCategoryId categoryId,
    required int lessonNumber,
    required int sheetNumber,
    int? limit,
  }) async => questions;

  @override
  Future<LessonSheetCompletionSnapshot> fetchLessonSheetCompletion({
    required LicenseCategoryId categoryId,
    required int lessonNumber,
  }) async => LessonSheetCompletionSnapshot.empty;

  @override
  Future<Map<String, List<QuizQuestion>>> fetchExamQuestionsByTopic({
    required LicenseCategoryId categoryId,
  }) async => {'Navigazione': questions};

  @override
  Future<Map<int, List<QuizQuestion>>> fetchQuestionsForLessons({
    required LicenseCategoryId categoryId,
    required List<int> lessonNumbers,
  }) async => {};

  @override
  Future<Map<int, List<int>>> fetchLessonSheetNumbersByLesson({
    required LicenseCategoryId categoryId,
  }) async => {
    1: [1, 2, 3],
  };
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
  }) async => const QuizAttemptSubmitResult(quizResultId: 'ok');
}

Size? _cardSize(WidgetTester tester) {
  final card = find.byKey(const Key('lesson_style_question_card'));
  if (card.evaluate().isEmpty) return null;
  return tester.getSize(card);
}

Future<void> _pumpLesson(
  WidgetTester tester, {
  required Size viewport,
  String? imagePath,
  String? prompt,
}) async {
  studyAccessWritableRepository.applyLessonQuizSheetUnlock(
    categoryId: LicenseCategoryId.motore,
    lessonNumber: 1,
    sheetNumber: 1,
    unlocked: true,
  );
  addTearDown(studyAccessWritableRepository.resetDemoAssignments);

  await tester.binding.setSurfaceSize(viewport);
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: viewport),
      child: MaterialApp(
        home: QuizSheetDetailPage(
          lessonNumber: 1,
          sheetNumber: 1,
          categoryId: LicenseCategoryId.motore,
          studentQuizRepositoryOverride: _FakeStudentRepo(
            _sheetQs(imagePath: imagePath, prompt: prompt),
          ),
          quizAttemptRepositoryOverride: _FakeAttemptRepo(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpMulti(
  WidgetTester tester, {
  required Size viewport,
  String? imagePath,
  String? prompt,
}) async {
  final lesson1 = List.generate(
    20,
    (i) => _q(n: i + 1, imagePath: imagePath, prompt: prompt),
  );
  final lesson2 = List.generate(
    20,
    (i) => _q(n: 100 + i, imagePath: imagePath, prompt: prompt),
  );
  final session = MultiTopicQuizSession(
    sessionId: 'fill-session',
    licenseCategory: LicenseCategoryId.motore,
    selectedLessonNumbers: const [1, 2],
    totalSheets: 2,
    poolByLesson: {1: lesson1, 2: lesson2},
  );

  await tester.binding.setSurfaceSize(viewport);
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: viewport),
      child: MaterialApp(
        home: MultiTopicQuizPlayerPage(
          session: session,
          attemptRepositoryOverride: MultiTopicQuizAttemptRepositoryFake(
            submitResult: MultiTopicQuizAttemptResult(
              attemptId: 'att-fill',
              sessionId: 'fill-session',
              sheetIndex: 1,
              totalSheets: 2,
              licenseCategory: LicenseCategoryId.motore,
              lessonNumbers: const [1, 2],
              completedAt: DateTime.utc(2026, 10, 4),
              durationSeconds: 10,
              totalQuestions: 20,
              correctCount: 0,
              wrongCount: 0,
              unansweredCount: 20,
              idempotent: false,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('FILL.5 — layout resolution', () {
    test('resolveLayout: no image / side / stacked + height gate', () {
      expect(
        LessonStyleQuizPlayerShell.resolveLayout(
          imagePath: null,
          compact: false,
          contentWidth: 1440,
          availableBodyHeight: 700,
        ),
        LessonStyleQuizLayout.noImage,
      );
      expect(
        LessonStyleQuizPlayerShell.resolveLayout(
          imagePath: '',
          compact: false,
          contentWidth: 1440,
          availableBodyHeight: 700,
        ),
        LessonStyleQuizLayout.noImage,
      );
      expect(
        LessonStyleQuizPlayerShell.resolveLayout(
          imagePath: '   ',
          compact: false,
          contentWidth: 1440,
          availableBodyHeight: 700,
        ),
        LessonStyleQuizLayout.noImage,
      );
      expect(
        LessonStyleQuizPlayerShell.resolveLayout(
          imagePath: _imagePath,
          compact: false,
          contentWidth: 1440,
          availableBodyHeight: 700,
        ),
        LessonStyleQuizLayout.withImageSide,
      );
      expect(
        LessonStyleQuizPlayerShell.resolveLayout(
          imagePath: _imagePath,
          compact: false,
          contentWidth: 1024,
          availableBodyHeight: 560,
        ),
        LessonStyleQuizLayout.withImageSide,
      );
      expect(
        LessonStyleQuizPlayerShell.resolveLayout(
          imagePath: _imagePath,
          compact: true,
          contentWidth: 390,
          availableBodyHeight: 700,
        ),
        LessonStyleQuizLayout.withImageStacked,
      );
      expect(
        LessonStyleQuizPlayerShell.resolveLayout(
          imagePath: _imagePath,
          compact: false,
          contentWidth: 500,
          availableBodyHeight: 700,
        ),
        LessonStyleQuizLayout.withImageStacked,
      );
      // Wide-but-short: width ok, body height insufficient → stacked
      expect(
        LessonStyleQuizPlayerShell.resolveLayout(
          imagePath: _imagePath,
          compact: false,
          contentWidth: 844,
          availableBodyHeight: 280,
        ),
        LessonStyleQuizLayout.withImageStacked,
      );
      expect(
        LessonStyleQuizPlayerShell.resolveLayout(
          imagePath: _imagePath,
          compact: false,
          contentWidth: 844,
          availableBodyHeight:
              LessonStyleQuizPlayerShell.sideLayoutMinBodyHeight - 1,
        ),
        LessonStyleQuizLayout.withImageStacked,
      );
      expect(
        LessonStyleQuizPlayerShell.resolveLayout(
          imagePath: _imagePath,
          compact: false,
          contentWidth: 844,
          availableBodyHeight:
              LessonStyleQuizPlayerShell.sideLayoutMinBodyHeight,
        ),
        LessonStyleQuizLayout.withImageSide,
      );
    });

    test('width boundary 599/600/601 with sufficient height', () {
      expect(
        LessonStyleQuizPlayerShell.resolveLayout(
          imagePath: _imagePath,
          compact: false,
          contentWidth: 599,
          availableBodyHeight: 700,
        ),
        LessonStyleQuizLayout.withImageStacked,
      );
      expect(
        LessonStyleQuizPlayerShell.resolveLayout(
          imagePath: _imagePath,
          compact: false,
          contentWidth: 600,
          availableBodyHeight: 700,
        ),
        LessonStyleQuizLayout.withImageSide,
      );
      expect(
        LessonStyleQuizPlayerShell.resolveLayout(
          imagePath: _imagePath,
          compact: false,
          contentWidth: 601,
          availableBodyHeight: 700,
        ),
        LessonStyleQuizLayout.withImageSide,
      );
    });

    test('side image maxHeight adapts to short body', () {
      final short = LessonStyleQuizPlayerShell.resolveSideImageMaxHeight(
        availableBodyHeight: 300,
        minRowHeight: 300,
      );
      expect(short, lessThanOrEqualTo(300 - 24));
      expect(
        short,
        greaterThanOrEqualTo(
          LessonStyleQuizPlayerShell.sideImageMinHeightFloor,
        ),
      );

      final tall = LessonStyleQuizPlayerShell.resolveSideImageMaxHeight(
        availableBodyHeight: 800,
        minRowHeight: 500,
      );
      expect(
        tall,
        lessThanOrEqualTo(LessonStyleQuizPlayerShell.sideImageMaxHeightCap),
      );
    });

    test('desktop leftover clamped; compact = 0; long content skips fill', () {
      final desktop = LessonStyleQuizPlayerShell.resolveQuestionCardMinHeight(
        availableBodyHeight: 600,
        compact: false,
        optionCount: 3,
        density: QuizPlayerContentDensity.standard,
      );
      expect(
        desktop,
        greaterThanOrEqualTo(
          LessonStyleQuizPlayerShell.questionCardMinHeightFloor,
        ),
      );
      expect(
        desktop,
        lessThanOrEqualTo(600 * LessonStyleQuizPlayerShell.questionCardMaxBodyFraction),
      );

      final compact = LessonStyleQuizPlayerShell.resolveQuestionCardMinHeight(
        availableBodyHeight: 600,
        compact: true,
        optionCount: 3,
        density: QuizPlayerContentDensity.standard,
      );
      expect(compact, 0);

      final longContent =
          LessonStyleQuizPlayerShell.resolveQuestionCardMinHeight(
            availableBodyHeight: 600,
            compact: false,
            optionCount: 3,
            density: QuizPlayerContentDensity.standard,
            estimatedContentLines:
                LessonStyleQuizPlayerShell.longContentSkipFillLines + 1,
          );
      expect(longContent, 0);
    });
  });

  group('FILL.5 — visual refinement image / no-image', () {
    testWidgets('A. desktop no-image: full-width question + answers', (
      tester,
    ) async {
      await _pumpLesson(tester, viewport: const Size(1440, 900));
      expect(
        find.byKey(const Key('lesson_style_layout_no_image')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('lesson_style_image_column')), findsNothing);
      expect(find.byType(QuizPlayerAnswerTile), findsNWidgets(3));
      final card = _cardSize(tester)!;
      expect(card.height, greaterThan(140));
      expect(
        card.width,
        lessThanOrEqualTo(QuizPlayerVisual.noImageReadingMaxWidth + 1),
      );
      expect(card.width, greaterThan(700));
      expect(tester.takeException(), isNull);
    });

    testWidgets('B. desktop image: left image + right question/answers', (
      tester,
    ) async {
      await _pumpLesson(
        tester,
        viewport: const Size(1440, 900),
        imagePath: _imagePath,
      );
      expect(
        find.byKey(const Key('lesson_style_layout_with_image_side')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('lesson_style_image_column')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('lesson_style_right_column')),
        findsOneWidget,
      );
      expect(find.byType(QuizPlayerAnswerTile), findsNWidgets(3));

      final imageLeft = tester
          .getTopLeft(find.byKey(const Key('lesson_style_image_column')))
          .dx;
      final rightLeft = tester
          .getTopLeft(find.byKey(const Key('lesson_style_right_column')))
          .dx;
      final answerLeft = tester
          .getTopLeft(find.byType(QuizPlayerAnswerTile).first)
          .dx;
      expect(rightLeft, greaterThan(imageLeft));
      expect(answerLeft, greaterThan(imageLeft + 100));
      expect(tester.takeException(), isNull);
    });

    testWidgets('C. normal/multi no-image parity', (tester) async {
      await _pumpLesson(tester, viewport: const Size(1440, 900));
      final lessonCard = _cardSize(tester)!;
      expect(
        find.byKey(const Key('lesson_style_layout_no_image')),
        findsOneWidget,
      );

      await _pumpMulti(tester, viewport: const Size(1440, 900));
      final multiCard = _cardSize(tester)!;
      expect(
        find.byKey(const Key('lesson_style_layout_no_image')),
        findsOneWidget,
      );
      expect(multiCard.width, closeTo(lessonCard.width, 2.0));
      expect((multiCard.height - lessonCard.height).abs(), lessThan(40));
    });

    testWidgets('D. normal/multi image side parity', (tester) async {
      await _pumpLesson(
        tester,
        viewport: const Size(1440, 900),
        imagePath: _imagePath,
      );
      final lessonImg = tester.getSize(
        find.byKey(const Key('lesson_style_image_column')),
      );

      await _pumpMulti(
        tester,
        viewport: const Size(1440, 900),
        imagePath: _imagePath,
      );
      final multiImg = tester.getSize(
        find.byKey(const Key('lesson_style_image_column')),
      );
      expect(multiImg.width, closeTo(lessonImg.width, 2.0));
      expect(
        find.byKey(const Key('lesson_style_layout_with_image_side')),
        findsOneWidget,
      );
    });

    testWidgets('E. answer tiles shared in both layouts', (tester) async {
      await _pumpLesson(tester, viewport: const Size(1440, 900));
      expect(find.byType(QuizPlayerAnswerTile), findsNWidgets(3));
      await _pumpLesson(
        tester,
        viewport: const Size(1440, 900),
        imagePath: _imagePath,
      );
      expect(find.byType(QuizPlayerAnswerTile), findsNWidgets(3));
    });

    testWidgets('F. image column absent when imagePath null/empty/whitespace', (
      tester,
    ) async {
      for (final path in <String?>[null, '', '   ']) {
        await _pumpLesson(
          tester,
          viewport: const Size(1440, 900),
          imagePath: path,
        );
        expect(
          find.byKey(const Key('lesson_style_layout_no_image')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('lesson_style_image_column')),
          findsNothing,
        );
        expect(find.byKey(const Key('quiz_prompt_side_image')), findsNothing);
        expect(
          find.byKey(const Key('quiz_prompt_stacked_image')),
          findsNothing,
        );
      }
    });

    testWidgets('G. 390 stacked layout with image', (tester) async {
      await _pumpLesson(
        tester,
        viewport: const Size(390, 844),
        imagePath: _imagePath,
      );
      expect(
        find.byKey(const Key('lesson_style_layout_with_image_stacked')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('lesson_style_image_column')), findsNothing);
      expect(
        find.byKey(const Key('quiz_prompt_stacked_image')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('G2. 844×390 wide-but-short → stacked (not side)', (
      tester,
    ) async {
      await _pumpLesson(
        tester,
        viewport: const Size(844, 390),
        imagePath: _imagePath,
      );
      expect(
        find.byKey(const Key('lesson_style_layout_with_image_stacked')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('lesson_style_layout_with_image_side')),
        findsNothing,
      );
      expect(find.byKey(const Key('lesson_style_image_column')), findsNothing);
      expect(
        find.byKey(const Key('quiz_prompt_stacked_image')),
        findsOneWidget,
      );
      expect(find.byType(QuizPlayerAnswerTile), findsNWidgets(3));
      expect(
        find.byKey(const Key('lesson_style_quiz_player_footer')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('G3. Normal/Multi 844×390 image parity → stacked', (
      tester,
    ) async {
      await _pumpLesson(
        tester,
        viewport: const Size(844, 390),
        imagePath: _imagePath,
      );
      expect(
        find.byKey(const Key('lesson_style_layout_with_image_stacked')),
        findsOneWidget,
      );

      await _pumpMulti(
        tester,
        viewport: const Size(844, 390),
        imagePath: _imagePath,
      );
      expect(
        find.byKey(const Key('lesson_style_layout_with_image_stacked')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('lesson_style_layout_with_image_side')),
        findsNothing,
      );
    });

    testWidgets('G4. 844×390 long content stacked, scroll, no overflow', (
      tester,
    ) async {
      final longPrompt = List.filled(
        40,
        'Testo molto lungo della domanda.',
      ).join(' ');
      final longOpt = List.filled(20, 'risposta lunga').join(' ');
      studyAccessWritableRepository.applyLessonQuizSheetUnlock(
        categoryId: LicenseCategoryId.motore,
        lessonNumber: 1,
        sheetNumber: 1,
        unlocked: true,
      );
      addTearDown(studyAccessWritableRepository.resetDemoAssignments);
      await tester.binding.setSurfaceSize(const Size(844, 390));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(844, 390)),
          child: MaterialApp(
            home: QuizSheetDetailPage(
              lessonNumber: 1,
              sheetNumber: 1,
              categoryId: LicenseCategoryId.motore,
              studentQuizRepositoryOverride: _FakeStudentRepo([
                _q(
                  n: 1,
                  imagePath: _imagePath,
                  prompt: longPrompt,
                  optionText: longOpt,
                ),
                ..._sheetQs().skip(1),
              ]),
              quizAttemptRepositoryOverride: _FakeAttemptRepo(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('lesson_style_layout_with_image_stacked')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('lesson_style_quiz_player_footer')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('H. 768×1024 image → side (tall enough body)', (tester) async {
      await _pumpLesson(
        tester,
        viewport: const Size(768, 1024),
        imagePath: _imagePath,
      );
      expect(
        find.byKey(const Key('lesson_style_layout_with_image_side')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('I. 1024×768 two-column image', (tester) async {
      await _pumpLesson(
        tester,
        viewport: const Size(1024, 768),
        imagePath: _imagePath,
      );
      expect(
        find.byKey(const Key('lesson_style_layout_with_image_side')),
        findsOneWidget,
      );
    });

    testWidgets('I2. 1366×768 two-column image', (tester) async {
      await _pumpLesson(
        tester,
        viewport: const Size(1366, 768),
        imagePath: _imagePath,
      );
      expect(
        find.byKey(const Key('lesson_style_layout_with_image_side')),
        findsOneWidget,
      );
    });

    testWidgets('J. 1440×900 two-column image', (tester) async {
      await _pumpLesson(
        tester,
        viewport: const Size(1440, 900),
        imagePath: _imagePath,
      );
      expect(
        find.byKey(const Key('lesson_style_layout_with_image_side')),
        findsOneWidget,
      );
    });

    testWidgets('J2. width boundary widgets 599/600/601 no overflow', (
      tester,
    ) async {
      for (final width in const [599.0, 600.0, 601.0]) {
        await _pumpLesson(
          tester,
          viewport: Size(width, 900),
          imagePath: _imagePath,
        );
        expect(tester.takeException(), isNull);
        if (width < LessonStyleQuizPlayerShell.sideLayoutMinWidth) {
          expect(
            find.byKey(const Key('lesson_style_layout_with_image_stacked')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('lesson_style_image_column')),
            findsNothing,
          );
        } else {
          // 600/601: not compact, body tall → side
          expect(
            find.byKey(const Key('lesson_style_layout_with_image_side')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('lesson_style_image_column')),
            findsOneWidget,
          );
        }
      }
    });

    testWidgets('K. long prompt no overflow', (tester) async {
      final long = List.filled(
        40,
        'Testo molto lungo della domanda.',
      ).join(' ');
      await _pumpLesson(tester, viewport: const Size(1440, 900), prompt: long);
      expect(tester.takeException(), isNull);
      expect(_cardSize(tester)!.height, greaterThan(180));
    });

    testWidgets('L. long answers no overflow', (tester) async {
      final longOpt = List.filled(20, 'risposta lunga').join(' ');
      studyAccessWritableRepository.applyLessonQuizSheetUnlock(
        categoryId: LicenseCategoryId.motore,
        lessonNumber: 1,
        sheetNumber: 1,
        unlocked: true,
      );
      addTearDown(studyAccessWritableRepository.resetDemoAssignments);
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(1440, 900)),
          child: MaterialApp(
            home: QuizSheetDetailPage(
              lessonNumber: 1,
              sheetNumber: 1,
              categoryId: LicenseCategoryId.motore,
              studentQuizRepositoryOverride: _FakeStudentRepo([
                _q(n: 1, optionText: longOpt),
                ..._sheetQs().skip(1),
              ]),
              quizAttemptRepositoryOverride: _FakeAttemptRepo(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('M. no overflow matrix incl. 844×390', (tester) async {
      for (final size in const [
        Size(390, 844),
        Size(844, 390),
        Size(768, 1024),
        Size(1024, 768),
        Size(1366, 768),
        Size(1440, 900),
      ]) {
        await _pumpLesson(tester, viewport: size);
        expect(tester.takeException(), isNull);
        await _pumpLesson(tester, viewport: size, imagePath: _imagePath);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('N. footer remains bottomNavigationBar', (tester) async {
      await _pumpLesson(tester, viewport: const Size(1440, 900));
      final footer = find.byKey(const Key('lesson_style_quiz_player_footer'));
      expect(footer, findsOneWidget);
      expect(tester.getTopLeft(footer).dy, greaterThan(700));
      expect(find.text('Avanti'), findsOneWidget);
    });

    testWidgets('O. Exam still 720, no lesson shell', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(1440, 900)),
          child: MaterialApp(
            home: QuizExamPlayerPage(
              categoryId: LicenseCategoryId.motore,
              questions: List.generate(5, (i) => _q(n: i + 1)),
              clientAttemptToken: 'fill-exam-token',
              repository: const ExamQuizAttemptRepositoryEmpty(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LessonStyleQuizPlayerShell), findsNothing);
      var found720 = false;
      for (final box in tester.widgetList<ConstrainedBox>(
        find.byType(ConstrainedBox),
      )) {
        if (box.constraints.maxWidth == QuizPlayerVisual.contentMaxWidth) {
          found720 = true;
          break;
        }
      }
      expect(found720, isTrue);
      expect(tester.takeException(), isNull);
    });
  });
}
