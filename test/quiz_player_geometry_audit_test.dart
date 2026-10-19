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
import 'package:scuola_nautica_liana/widgets/quiz_question_prompt_panel.dart';

/// UNIFY.2 classroom scale — Lesson↔Exam geometry + typography parity.
const _widthTolerance = 6.0;

QuizQuestion _q(int n, {String? imagePath}) => QuizQuestion(
  id: 'q$n',
  prompt: 'Domanda audit $n — navigazione in prossimità di un porto',
  optionA: 'Risposta A della domanda $n con testo sufficiente',
  optionB: 'Risposta B della domanda $n con testo sufficiente',
  optionC: 'Risposta C della domanda $n con testo sufficiente',
  correctOption: QuizAnswerOption.a,
  lessonNumber: 1,
  licenseCategory: 'D1',
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

  @override
  Future<Map<int, List<QuizQuestion>>> fetchQuestionsForLessons({
    required LicenseCategoryId categoryId,
    required List<int> lessonNumbers,
  }) async => {};

  @override
  Future<Map<int, List<int>>> fetchLessonSheetNumbersByLesson({
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

double _w(WidgetTester tester, Finder f) => tester.getSize(f).width;

Finder get _mediaImage => find.byKey(const Key('quiz_player_media_image'));
Finder get _stackedImage => find.byKey(const Key('quiz_prompt_stacked_image'));

void main() {
  Future<void> pumpExam(
    WidgetTester tester, {
    required Size viewport,
    String? imagePath,
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
            questions: [_q(1, imagePath: imagePath)],
            clientAttemptToken: 'geom-exam',
            repository: ExamQuizAttemptRepositoryFake(
              submitResult: ExamQuizAttemptSubmitResult(
                idempotent: false,
                attempt: ExamQuizAttemptSummary(
                  id: 'att',
                  licenseCategory: LicenseCategoryId.d1,
                  completedAt: DateTime.utc(2026, 10, 16),
                  duration: const Duration(minutes: 10),
                  timeExpired: false,
                  totalQuestions: 1,
                  correctCount: 0,
                  wrongCount: 1,
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

  Future<void> pumpLesson(
    WidgetTester tester, {
    required Size viewport,
    String? imagePath,
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
    final questions = [_q(1, imagePath: imagePath)];
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
                quizSetId: 'set',
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

  for (final viewport in const [
    Size(1440, 900),
    Size(1600, 900),
    Size(1920, 1080),
    Size(1280, 720),
    Size(390, 844),
  ]) {
    testWidgets(
      'UNIFY.2 no-image parity ${viewport.width.toInt()}',
      (tester) async {
        await pumpExam(tester, viewport: viewport);
        final examPrompt = _w(tester, find.byType(QuizQuestionPromptPanel));
        final examAnswer = _w(tester, find.byType(QuizPlayerAnswerTile).first);
        final examQFont = QuizPlayerVisual.questionFontSize(
          tester.element(find.byType(QuizQuestionPromptPanel)),
          scale: QuizPlayerTypeScale.classroom,
        );
        final examAFont = QuizPlayerVisual.answerFontSize(
          tester.element(find.byType(QuizPlayerAnswerTile).first),
          scale: QuizPlayerTypeScale.classroom,
        );

        await pumpLesson(tester, viewport: viewport);
        final lessonPrompt = _w(tester, find.byType(QuizQuestionPromptPanel));
        final lessonAnswer =
            _w(tester, find.byType(QuizPlayerAnswerTile).first);
        final lessonQFont = QuizPlayerVisual.questionFontSize(
          tester.element(find.byType(QuizQuestionPromptPanel)),
          scale: QuizPlayerTypeScale.classroom,
        );
        final lessonAFont = QuizPlayerVisual.answerFontSize(
          tester.element(find.byType(QuizPlayerAnswerTile).first),
          scale: QuizPlayerTypeScale.classroom,
        );

        expect(lessonPrompt, closeTo(examPrompt, _widthTolerance));
        expect(lessonAnswer, closeTo(examAnswer, _widthTolerance));
        expect(lessonQFont, examQFont);
        expect(lessonAFont, examAFont);

        if (viewport.width >= 1440 && viewport.height >= 900) {
          expect(examAnswer, greaterThanOrEqualTo(1100));
          expect(examQFont, greaterThanOrEqualTo(28));
          expect(examAFont, greaterThanOrEqualTo(20));
        }
      },
    );

    testWidgets(
      'UNIFY.2 image parity ${viewport.width.toInt()}',
      (tester) async {
        const imagePath = 'figures/sample.png';
        await pumpExam(tester, viewport: viewport, imagePath: imagePath);
        final examAnswer = _w(tester, find.byType(QuizPlayerAnswerTile).first);
        final examMedia = _mediaImage.evaluate().isNotEmpty
            ? _w(tester, _mediaImage)
            : (_stackedImage.evaluate().isNotEmpty
                  ? _w(tester, _stackedImage)
                  : 0.0);

        await pumpLesson(tester, viewport: viewport, imagePath: imagePath);
        final lessonAnswer =
            _w(tester, find.byType(QuizPlayerAnswerTile).first);
        final lessonMedia = _mediaImage.evaluate().isNotEmpty
            ? _w(tester, _mediaImage)
            : (_stackedImage.evaluate().isNotEmpty
                  ? _w(tester, _stackedImage)
                  : 0.0);

        expect(lessonAnswer, closeTo(examAnswer, _widthTolerance));
        expect(lessonMedia, closeTo(examMedia, _widthTolerance));
        expect(examMedia, greaterThan(0));

        if (viewport.width >= 1440 && viewport.height >= 900) {
          expect(find.byKey(const Key('quiz_player_body_image_side')), findsWidgets);
          expect(examMedia, greaterThanOrEqualTo(200));
          // Q/A column remains majority of content.
          expect(examAnswer, greaterThan(examMedia * 1.5));
        }
      },
    );
  }
}
