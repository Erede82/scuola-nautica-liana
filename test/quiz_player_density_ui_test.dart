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
import 'package:scuola_nautica_liana/theme/quiz_player_density.dart';
import 'package:scuola_nautica_liana/theme/quiz_player_visual_tokens.dart';
import 'package:scuola_nautica_liana/widgets/quiz_player_answer_tile.dart';

const _longPrompt = "Cosa si intende per rollio di un'unità navale?";

const _longA =
    "Il movimento oscillatorio dell'unità intorno al suo asse longitudinale, "
    'che provoca l’inclinazione alternata a dritta e a sinistra.';

const _longB =
    "Il movimento oscillatorio dell'unità intorno al suo asse verticale, "
    'che provoca lo sbandamento permanente verso una sola murata.';

const _longC =
    "Il movimento oscillatorio dell'unità intorno al suo asse trasversale, "
    'che provoca l’alzarsi e l’abbassarsi alternato di prua e poppa.';

const _shortPrompt = 'Il rollio è un movimento?';
const _shortA = 'Sì, laterale';
const _shortB = 'No';
const _shortC = 'Solo in porto';

QuizQuestion _longQuestion({required String category, String id = 'long-1'}) =>
    QuizQuestion(
      id: id,
      prompt: _longPrompt,
      optionA: _longA,
      optionB: _longB,
      optionC: _longC,
      correctOption: QuizAnswerOption.a,
      lessonNumber: 1,
      licenseCategory: category,
    );

QuizQuestion _shortQuestion({
  required String category,
  String id = 'short-1',
}) => QuizQuestion(
  id: id,
  prompt: _shortPrompt,
  optionA: _shortA,
  optionB: _shortB,
  optionC: _shortC,
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

ExamQuizAttemptSubmitResult _d1Submit() => ExamQuizAttemptSubmitResult(
  idempotent: false,
  attempt: ExamQuizAttemptSummary(
    id: 'att-dense',
    licenseCategory: LicenseCategoryId.d1,
    completedAt: DateTime.utc(2026, 7, 26),
    duration: const Duration(minutes: 10),
    timeExpired: false,
    totalQuestions: 15,
    correctCount: 15,
    wrongCount: 0,
    unansweredCount: 0,
    outcome: ExamQuizOutcome.passed,
  ),
);

Future<void> _pumpExam(
  WidgetTester tester, {
  required Size viewport,
  required List<QuizQuestion> questions,
}) async {
  await tester.binding.setSurfaceSize(viewport);
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: viewport),
      child: MaterialApp(
        home: QuizExamPlayerPage(
          categoryId: LicenseCategoryId.d1,
          questions: questions,
          clientAttemptToken: 'dense-exam-token',
          repository: ExamQuizAttemptRepositoryFake(submitResult: _d1Submit()),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpSheet(
  WidgetTester tester, {
  required Size viewport,
  required List<QuizQuestion> questions,
}) async {
  studyAccessWritableRepository.applyLessonQuizSheetUnlock(
    categoryId: LicenseCategoryId.d1,
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
          categoryId: LicenseCategoryId.d1,
          studentQuizRepositoryOverride: _FakeStudentQuizRepo(
            LessonQuizSheetContent(
              quizSetId: 'set-dense',
              categoryId: LicenseCategoryId.d1,
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

void _expectDenseActive(WidgetTester tester) {
  expect(
    find.byKey(const ValueKey('quiz-player-density-dense')),
    findsOneWidget,
  );
  expect(
    find.byKey(const ValueKey('quiz-player-density-standard')),
    findsNothing,
  );
  final tile = tester.widget<QuizPlayerAnswerTile>(
    find.byType(QuizPlayerAnswerTile).first,
  );
  expect(tile.density, QuizPlayerContentDensity.dense);
  expect(tile.minHeight, QuizPlayerVisual.answerMinHeightDense);
}

void _expectStandardActive(WidgetTester tester) {
  expect(
    find.byKey(const ValueKey('quiz-player-density-standard')),
    findsOneWidget,
  );
  expect(find.byKey(const ValueKey('quiz-player-density-dense')), findsNothing);
  final tile = tester.widget<QuizPlayerAnswerTile>(
    find.byType(QuizPlayerAnswerTile).first,
  );
  expect(tile.density, QuizPlayerContentDensity.standard);
  expect(tile.minHeight, QuizPlayerVisual.answerMinHeight);
}

Future<void> _assertLongContentReachable(WidgetTester tester) async {
  expect(find.text(_longPrompt), findsOneWidget);
  expect(find.text(_longA), findsOneWidget);
  expect(find.text(_longB), findsOneWidget);
  expect(find.text(_longC), findsOneWidget);

  final last = find.text(_longC);
  await tester.ensureVisible(last);
  expect(last.hitTestable(), findsOneWidget);

  final lastBottom = tester.getRect(last).bottom;
  final barLabel = find.text('Avanti');
  expect(barLabel, findsOneWidget);
  final barTop = tester.getRect(barLabel).top;
  expect(lastBottom, lessThanOrEqualTo(barTop + 1.0));
  expect(tester.takeException(), isNull);
}

void main() {
  group('P9F-UI.3 densità adattiva contenuti lunghi', () {
    for (final size in const [Size(390, 844), Size(430, 932)]) {
      testWidgets(
        'Quiz Esame D1 dense ${size.width.toInt()}×${size.height.toInt()}',
        (tester) async {
          final questions = [
            _longQuestion(category: 'D1'),
            ...List.generate(
              14,
              (i) => _shortQuestion(category: 'D1', id: 'short-${i + 2}'),
            ),
          ];
          await _pumpExam(tester, viewport: size, questions: questions);
          _expectDenseActive(tester);
          await _assertLongContentReachable(tester);
        },
      );

      testWidgets(
        'Scheda D1 dense ${size.width.toInt()}×${size.height.toInt()}',
        (tester) async {
          final questions = [
            _longQuestion(category: 'D1'),
            ...List.generate(
              14,
              (i) => _shortQuestion(category: 'D1', id: 'short-${i + 2}'),
            ),
          ];
          await _pumpSheet(tester, viewport: size, questions: questions);
          _expectDenseActive(tester);
          await _assertLongContentReachable(tester);
        },
      );
    }

    testWidgets('contenuto breve resta standard su 390×844', (tester) async {
      final questions = List.generate(
        15,
        (i) => _shortQuestion(category: 'D1', id: 's$i'),
      );
      await _pumpExam(
        tester,
        viewport: const Size(390, 844),
        questions: questions,
      );
      _expectStandardActive(tester);
      expect(find.text(_shortA), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('scheda breve resta standard su 390×844', (tester) async {
      final questions = List.generate(
        15,
        (i) => _shortQuestion(category: 'D1', id: 's$i'),
      );
      await _pumpSheet(
        tester,
        viewport: const Size(390, 844),
        questions: questions,
      );
      _expectStandardActive(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('desktop lungo resta standard (1366×768)', (tester) async {
      await _pumpExam(
        tester,
        viewport: const Size(1366, 768),
        questions: [
          _longQuestion(category: 'D1'),
          ...List.generate(
            14,
            (i) => _shortQuestion(category: 'D1', id: 'd$i'),
          ),
        ],
      );
      _expectStandardActive(tester);
      expect(tester.takeException(), isNull);
    });
  });
}
