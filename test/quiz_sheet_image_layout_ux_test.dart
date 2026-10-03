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
import 'package:scuola_nautica_liana/widgets/quiz_question_image.dart';
import 'package:scuola_nautica_liana/widgets/quiz_question_prompt_panel.dart';

QuizQuestion _q(int n, {String? imagePath}) => QuizQuestion(
  id: 'img-q$n',
  prompt: 'Domanda con figura $n — testo abbastanza lungo per layout',
  optionA: 'Opzione A della domanda $n',
  optionB: 'Opzione B della domanda $n',
  optionC: 'Opzione C della domanda $n',
  correctOption: QuizAnswerOption.a,
  lessonNumber: 1,
  licenseCategory: 'A12',
  imagePath: imagePath,
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
    quizSetId: 'set-img',
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

ConstrainedBox? _boxWithMaxWidth(WidgetTester tester, double maxWidth) {
  for (final box in tester.widgetList<ConstrainedBox>(
    find.byType(ConstrainedBox),
  )) {
    if (box.constraints.maxWidth == maxWidth) return box;
  }
  return null;
}

Future<void> _pumpSheetWithImage(
  WidgetTester tester, {
  required Size viewport,
}) async {
  studyAccessWritableRepository.applyLessonQuizSheetUnlock(
    categoryId: LicenseCategoryId.motore,
    lessonNumber: 1,
    sheetNumber: 1,
    unlocked: true,
  );
  addTearDown(() {
    studyAccessWritableRepository.resetDemoAssignments();
  });

  final questions = List.generate(
    3,
    (i) => _q(i + 1, imagePath: i == 0 ? 'figures/sample.png' : null),
  );

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
          studentQuizRepositoryOverride: _FakeStudentRepo(questions),
          quizAttemptRepositoryOverride: _FakeAttemptRepo(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('STUDIO.SCHEDE.UX.2 — figure responsive + exam width', () {
    testWidgets('prompt side image scales with available width', (
      tester,
    ) async {
      Future<double> sideWidth(Size size) async {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(size: size),
            child: const MaterialApp(
              home: Scaffold(
                body: Padding(
                  padding: EdgeInsets.all(16),
                  child: QuizQuestionPromptPanel(
                    questionNumber: 1,
                    prompt: 'Con figura laterale',
                    imagePath: 'figures/sample.png',
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final side = find.byKey(const Key('quiz_prompt_side_image'));
        expect(side, findsOneWidget);
        return tester.getSize(side).width;
      }

      final w1024 = await sideWidth(const Size(1024, 768));
      final w1440 = await sideWidth(const Size(1440, 900));
      expect(w1440, greaterThan(220));
      expect(w1440, greaterThanOrEqualTo(w1024));
      expect(w1440, lessThanOrEqualTo(360));
      await tester.binding.setSurfaceSize(null);
    });

    for (final size in const [
      Size(390, 844),
      Size(768, 1024),
      Size(1024, 768),
      Size(1440, 900),
    ]) {
      testWidgets('sheet with image ${size.width.toInt()}px no overflow', (
        tester,
      ) async {
        await _pumpSheetWithImage(tester, viewport: size);
        expect(find.byType(QuizQuestionImage), findsOneWidget);
        expect(find.textContaining('Opzione A'), findsWidgets);
        expect(tester.takeException(), isNull);
        if (size.width >= 600) {
          expect(
            find.byKey(const Key('quiz_prompt_side_image')),
            findsOneWidget,
          );
          final w = tester
              .getSize(find.byKey(const Key('quiz_prompt_side_image')))
              .width;
          if (size.width >= 1440) {
            expect(w, greaterThan(220));
          }
        } else {
          expect(
            find.byKey(const Key('quiz_prompt_stacked_image')),
            findsOneWidget,
          );
        }
      });
    }

    testWidgets('Exam simulation content width resta 720', (tester) async {
      const viewport = Size(1440, 900);
      await tester.binding.setSurfaceSize(viewport);
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      final questions = List.generate(5, (i) => _q(i + 1));
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: viewport),
          child: MaterialApp(
            home: QuizExamPlayerPage(
              categoryId: LicenseCategoryId.motore,
              questions: questions,
              clientAttemptToken: 'exam-img-test',
              repository: ExamQuizAttemptRepositoryFake(
                submitResult: ExamQuizAttemptSubmitResult(
                  idempotent: false,
                  attempt: ExamQuizAttemptSummary(
                    id: 'att',
                    licenseCategory: LicenseCategoryId.motore,
                    completedAt: DateTime.utc(2026, 10, 2),
                    duration: const Duration(minutes: 10),
                    timeExpired: false,
                    totalQuestions: 5,
                    correctCount: 0,
                    wrongCount: 5,
                    unansweredCount: 0,
                    outcome: ExamQuizOutcome.failed,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        _boxWithMaxWidth(tester, QuizPlayerVisual.contentMaxWidth),
        isNotNull,
      );
      expect(
        _boxWithMaxWidth(tester, QuizPlayerVisual.lessonSheetContentMaxWidth),
        isNull,
      );
    });
  });
}
