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

double? _shellWidth(WidgetTester tester) {
  for (final box in tester.widgetList<ConstrainedBox>(
    find.byType(ConstrainedBox),
  )) {
    if (box.constraints.maxWidth ==
        QuizPlayerVisual.lessonSheetContentMaxWidth) {
      final elements = find
          .byWidgetPredicate((w) => identical(w, box))
          .evaluate();
      if (elements.isEmpty) continue;
      final render = elements.first.renderObject as RenderBox?;
      return render?.size.width;
    }
  }
  return null;
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
  group('FILL.5 — question card min-height strategy', () {
    test('desktop leftover clamped; compact = 0', () {
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
        lessThanOrEqualTo(
          600 * LessonStyleQuizPlayerShell.questionCardMaxBodyFraction,
        ),
      );

      final compact = LessonStyleQuizPlayerShell.resolveQuestionCardMinHeight(
        availableBodyHeight: 600,
        compact: true,
        optionCount: 3,
        density: QuizPlayerContentDensity.standard,
      );
      expect(compact, 0);
    });
  });

  group('FILL.5 — image / no-image + normal / multi', () {
    testWidgets('A. normal + image: wide card @1440', (tester) async {
      await _pumpLesson(
        tester,
        viewport: const Size(1440, 900),
        imagePath: _imagePath,
      );
      final card = _cardSize(tester);
      expect(card, isNotNull);
      expect(
        card!.height,
        greaterThanOrEqualTo(
          LessonStyleQuizPlayerShell.questionCardMinHeightFloor,
        ),
      );
      expect(find.byKey(const Key('quiz_prompt_side_image')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('B. normal no-image: does not collapse @1440', (tester) async {
      await _pumpLesson(tester, viewport: const Size(1440, 900));
      final card = _cardSize(tester);
      expect(card, isNotNull);
      expect(
        card!.height,
        greaterThanOrEqualTo(
          LessonStyleQuizPlayerShell.questionCardMinHeightFloor,
        ),
      );
      // Mini-card collapse (~80–120) non ammesso.
      expect(card.height, greaterThan(180));
      expect(tester.takeException(), isNull);
    });

    testWidgets('C. multi + image: wide card @1440', (tester) async {
      await _pumpMulti(
        tester,
        viewport: const Size(1440, 900),
        imagePath: _imagePath,
      );
      final card = _cardSize(tester);
      expect(card, isNotNull);
      expect(
        card!.height,
        greaterThanOrEqualTo(
          LessonStyleQuizPlayerShell.questionCardMinHeightFloor,
        ),
      );
      expect(find.byKey(const Key('quiz_prompt_side_image')), findsOneWidget);
    });

    testWidgets('D. multi no-image: does not collapse @1440', (tester) async {
      await _pumpMulti(tester, viewport: const Size(1440, 900));
      final card = _cardSize(tester);
      expect(card, isNotNull);
      expect(card!.height, greaterThan(180));
    });

    testWidgets('E/F. image vs no-image same shell geometry @1440', (
      tester,
    ) async {
      await _pumpLesson(tester, viewport: const Size(1440, 900));
      final noImage = _cardSize(tester)!;
      final noImageW = _shellWidth(tester)!;

      await _pumpLesson(
        tester,
        viewport: const Size(1440, 900),
        imagePath: _imagePath,
      );
      final withImage = _cardSize(tester)!;
      final withImageW = _shellWidth(tester)!;

      expect(noImageW, closeTo(withImageW, 1.0));
      expect(noImage.width, closeTo(withImage.width, 1.0));
      // Stessa min-height strategy → altezze allineate (tolleranza padding/figura).
      expect((noImage.height - withImage.height).abs(), lessThan(80));
      expect(find.byType(LessonStyleQuizPlayerShell), findsOneWidget);
    });

    testWidgets('G. footer anchored near viewport bottom', (tester) async {
      await _pumpLesson(tester, viewport: const Size(1440, 900));
      final footer = find.byKey(const Key('lesson_style_quiz_player_footer'));
      expect(footer, findsOneWidget);
      final footerTop = tester.getTopLeft(footer).dy;
      expect(footerTop, greaterThan(700));
      expect(find.text('Avanti'), findsOneWidget);
    });

    for (final size in const [
      Size(390, 844),
      Size(768, 1024),
      Size(1024, 768),
      Size(1440, 900),
    ]) {
      testWidgets('H-K responsive ${size.width.toInt()}px no overflow', (
        tester,
      ) async {
        await _pumpLesson(tester, viewport: size);
        expect(find.byType(LessonStyleQuizPlayerShell), findsOneWidget);
        expect(tester.takeException(), isNull);

        await _pumpMulti(tester, viewport: size);
        expect(find.byType(LessonStyleQuizPlayerShell), findsOneWidget);
        expect(tester.takeException(), isNull);

        if (size.width >= QuizPlayerVisual.compactWidthBreakpoint) {
          final card = _cardSize(tester);
          expect(card, isNotNull);
          expect(
            card!.height,
            greaterThanOrEqualTo(
              LessonStyleQuizPlayerShell.questionCardMinHeightFloor,
            ),
          );
        }
      });
    }

    testWidgets('L. long question scrolls without overflow', (tester) async {
      final long = List.filled(
        40,
        'Testo molto lungo della domanda.',
      ).join(' ');
      await _pumpLesson(tester, viewport: const Size(1440, 900), prompt: long);
      expect(find.byType(LessonStyleQuizPlayerShell), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(_cardSize(tester)!.height, greaterThan(180));
    });

    testWidgets('M. long answers no overflow', (tester) async {
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

    testWidgets('N. normal/multi no-image height parity @1440', (tester) async {
      await _pumpLesson(tester, viewport: const Size(1440, 900));
      final lesson = _cardSize(tester)!;
      await _pumpMulti(tester, viewport: const Size(1440, 900));
      final multi = _cardSize(tester)!;
      expect(multi.width, closeTo(lesson.width, 1.0));
      expect((multi.height - lesson.height).abs(), lessThan(40));
    });

    testWidgets('O. Exam still uses 720 content max width', (tester) async {
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
      // Exam non usa LessonStyleQuizPlayerShell.
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
      expect(find.byKey(const Key('lesson_style_question_card')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
