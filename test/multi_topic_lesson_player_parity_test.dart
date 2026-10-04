import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/multi_topic_quiz_attempt_result.dart';
import 'package:scuola_nautica_liana/domain/multi_topic_quiz_session.dart';
import 'package:scuola_nautica_liana/models/lesson_quiz_sheet_content.dart';
import 'package:scuola_nautica_liana/models/lesson_sheet_completion_snapshot.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';
import 'package:scuola_nautica_liana/models/quiz_question.dart';
import 'package:scuola_nautica_liana/pages/multi_topic_quiz_player_page.dart';
import 'package:scuola_nautica_liana/pages/quiz_sheet_detail_page.dart';
import 'package:scuola_nautica_liana/repositories/multi_topic_quiz_attempt_repository.dart';
import 'package:scuola_nautica_liana/repositories/quiz_attempt_repository.dart';
import 'package:scuola_nautica_liana/repositories/student_quiz_repository.dart';
import 'package:scuola_nautica_liana/repositories/study_access_repository.dart';
import 'package:scuola_nautica_liana/theme/quiz_player_visual_tokens.dart';
import 'package:scuola_nautica_liana/widgets/lesson_style_quiz_player_shell.dart';
import 'package:scuola_nautica_liana/widgets/quiz_lesson_sheet_progress_panel.dart';
import 'package:scuola_nautica_liana/widgets/quiz_player_answer_tile.dart';
import 'package:scuola_nautica_liana/widgets/quiz_question_prompt_panel.dart';

QuizQuestion _fixture(int n, {String? imagePath}) => QuizQuestion(
  id: 'parity-q$n',
  prompt: 'Domanda parity $n — testo condiviso Scheda/Multischeda',
  optionA: 'Opzione A parity $n',
  optionB: 'Opzione B parity $n',
  optionC: 'Opzione C parity $n',
  correctOption: QuizAnswerOption.a,
  lessonNumber: 1,
  licenseCategory: 'A12',
  imagePath: imagePath,
);

List<QuizQuestion> _sheetQuestions({bool withImage = false}) => List.generate(
  20,
  (i) => _fixture(
    i + 1,
    imagePath: withImage && i == 0
        ? 'assets/images/welcome/welcome_boat.jpg'
        : null,
  ),
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
    quizSetId: 'set-parity',
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

Size? _questionCardSize(WidgetTester tester) {
  final card = find.byKey(const Key('lesson_style_question_card'));
  if (card.evaluate().isEmpty) return null;
  return tester.getSize(card);
}

Future<void> _pumpLessonSheet(
  WidgetTester tester, {
  required Size viewport,
  bool withImage = false,
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
            _sheetQuestions(withImage: withImage),
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
  bool withImage = false,
}) async {
  final imagePath = withImage ? 'assets/images/welcome/welcome_boat.jpg' : null;
  // Stessa figura su tutto il pool: la domanda corrente ha sempre image.
  final lesson1 = List.generate(
    20,
    (i) => _fixture(i + 1, imagePath: imagePath),
  );
  final lesson2 = List.generate(
    20,
    (i) => _fixture(100 + i, imagePath: imagePath),
  );
  // Forza selezione deterministica: history vuota, pool tale che sheet1
  // può pescare le stesse 20 di lesson1 se quotas lo consentono — per parity
  // struttuale usiamo comunque gli stessi widget condivisi.
  final session = MultiTopicQuizSession(
    sessionId: 'parity-session',
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
              attemptId: 'att-parity',
              sessionId: 'parity-session',
              sheetIndex: 1,
              totalSheets: 2,
              licenseCategory: LicenseCategoryId.motore,
              lessonNumbers: const [1, 2],
              completedAt: DateTime.utc(2026, 10, 3),
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
  group('CONTINUITY.4 — true visual parity Scheda vs Multischeda', () {
    testWidgets('shared shell + prompt + progress + answers @1440', (
      tester,
    ) async {
      await _pumpLessonSheet(tester, viewport: const Size(1440, 900));
      expect(find.byType(LessonStyleQuizPlayerShell), findsOneWidget);
      expect(find.byType(QuizQuestionPromptPanel), findsOneWidget);
      expect(find.byType(QuizLessonSheetProgressPanel), findsOneWidget);
      expect(find.byType(QuizPlayerAnswerTile), findsNWidgets(3));
      final lessonWidth = _shellWidth(tester);
      final lessonCard = _questionCardSize(tester);
      expect(lessonWidth, closeTo(1120, 1.0));
      expect(lessonCard, isNotNull);

      await _pumpMulti(tester, viewport: const Size(1440, 900));
      expect(find.byType(LessonStyleQuizPlayerShell), findsOneWidget);
      expect(find.byType(QuizQuestionPromptPanel), findsOneWidget);
      expect(find.byType(QuizLessonSheetProgressPanel), findsOneWidget);
      expect(find.byType(QuizPlayerAnswerTile), findsNWidgets(3));
      expect(find.text('Scheda 1 di 2'), findsWidgets);
      final multiWidth = _shellWidth(tester);
      final multiCard = _questionCardSize(tester);
      expect(multiWidth, closeTo(1120, 1.0));
      expect(multiCard, isNotNull);
      expect(multiCard!.width, closeTo(lessonCard!.width, 1.0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('image side layout equivalent @1440', (tester) async {
      await _pumpLessonSheet(
        tester,
        viewport: const Size(1440, 900),
        withImage: true,
      );
      expect(find.byKey(const Key('quiz_prompt_side_image')), findsOneWidget);
      final lessonSide = tester.getSize(
        find.byKey(const Key('quiz_prompt_side_image')),
      );

      await _pumpMulti(
        tester,
        viewport: const Size(1440, 900),
        withImage: true,
      );
      expect(find.byKey(const Key('quiz_prompt_side_image')), findsOneWidget);
      final multiSide = tester.getSize(
        find.byKey(const Key('quiz_prompt_side_image')),
      );
      expect(multiSide.width, closeTo(lessonSide.width, 1.0));
      expect(find.byType(LessonStyleQuizPlayerShell), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final size in const [
      Size(390, 844),
      Size(768, 1024),
      Size(1024, 768),
      Size(1440, 900),
    ]) {
      testWidgets('responsive ${size.width.toInt()}px both players', (
        tester,
      ) async {
        await _pumpLessonSheet(tester, viewport: size);
        expect(find.byType(LessonStyleQuizPlayerShell), findsOneWidget);
        expect(tester.takeException(), isNull);
        final lessonW = _shellWidth(tester);
        expect(lessonW, isNotNull);

        await _pumpMulti(tester, viewport: size);
        expect(find.byType(LessonStyleQuizPlayerShell), findsOneWidget);
        expect(tester.takeException(), isNull);
        final multiW = _shellWidth(tester);
        expect(multiW, closeTo(lessonW!, 1.0));
      });
    }
  });
}
