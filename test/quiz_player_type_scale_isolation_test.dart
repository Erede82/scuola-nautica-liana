import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/exam_quiz_attempt_models.dart';
import 'package:scuola_nautica_liana/domain/exam_quiz_rules.dart';
import 'package:scuola_nautica_liana/models/assigned_quiz_models.dart';
import 'package:scuola_nautica_liana/models/lesson_quiz_sheet_content.dart';
import 'package:scuola_nautica_liana/models/lesson_sheet_completion_snapshot.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';
import 'package:scuola_nautica_liana/models/quiz_question.dart';
import 'package:scuola_nautica_liana/pages/assigned_quiz_player_page.dart';
import 'package:scuola_nautica_liana/pages/assigned_quiz_review_page.dart';
import 'package:scuola_nautica_liana/pages/quiz_exam_player_page.dart';
import 'package:scuola_nautica_liana/pages/quiz_sheet_detail_page.dart';
import 'package:scuola_nautica_liana/repositories/assigned_quiz_repository.dart';
import 'package:scuola_nautica_liana/repositories/exam_quiz_attempt_repository.dart';
import 'package:scuola_nautica_liana/repositories/quiz_attempt_repository.dart';
import 'package:scuola_nautica_liana/repositories/student_quiz_repository.dart';
import 'package:scuola_nautica_liana/repositories/study_access_repository.dart';
import 'package:scuola_nautica_liana/theme/quiz_player_visual_tokens.dart';
import 'package:scuola_nautica_liana/widgets/quiz_question_prompt_panel.dart';

/// Legge fontSize del testo prompt (non della label "Domanda N").
double _promptFontSize(WidgetTester tester, {required String prompt}) {
  final text = tester.widget<Text>(find.text(prompt));
  return text.style?.fontSize ?? 0;
}

QuizQuestion _examQ({required String prompt}) => QuizQuestion(
  id: 'q1',
  prompt: prompt,
  optionA: 'Opzione A',
  optionB: 'Opzione B',
  optionC: 'Opzione C',
  correctOption: QuizAnswerOption.a,
  lessonNumber: 1,
  licenseCategory: 'D1',
);

AssignedQuizQuestion _assignedQ({required String prompt}) =>
    AssignedQuizQuestion(
      assignmentItemId: 'item-1',
      position: 1,
      prompt: prompt,
      optionA: 'Opzione A',
      optionB: 'Opzione B',
      optionC: 'Opzione C',
      lessonNumber: 1,
    );

AssignedQuizSummary _summary() => AssignedQuizSummary(
  id: 'a1',
  publicCode: 'AQZ-a1',
  studentId: 'st-1',
  studentUserId: 'user-1',
  licenseCategory: 'A12',
  title: 'Quiz scuola',
  staffNote: null,
  status: AssignedQuizStatus.assigned,
  questionCount: 1,
  repeatPolicy: AssignedQuizRepeatPolicy.unlimited,
  maxAttempts: null,
  createdAt: DateTime.utc(2026, 7, 1),
  assignedAt: DateTime.utc(2026, 7, 2),
  expiresAt: null,
  submittedAttemptsCount: null,
  hasInProgressAttempt: null,
  attemptsCount: null,
  attemptsUsedCount: null,
  bestScorePercentage: null,
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
  }) async => const QuizAttemptSubmitResult(quizResultId: 'ok');
}

void main() {
  const shortPrompt = 'Domanda corta isolation scale';

  Future<void> pumpExam(WidgetTester tester, Size size, {double textScale = 1}) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: MaterialApp(
          home: QuizExamPlayerPage(
            categoryId: LicenseCategoryId.d1,
            questions: [_examQ(prompt: shortPrompt)],
            clientAttemptToken: 'scale-exam',
            repository: ExamQuizAttemptRepositoryFake(
              submitResult: ExamQuizAttemptSubmitResult(
                idempotent: false,
                attempt: ExamQuizAttemptSummary(
                  id: 'att',
                  licenseCategory: LicenseCategoryId.d1,
                  completedAt: DateTime.utc(2026, 10, 17),
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

  Future<void> pumpLesson(WidgetTester tester, Size size) async {
    studyAccessWritableRepository.applyLessonQuizSheetUnlock(
      categoryId: LicenseCategoryId.d1,
      lessonNumber: 1,
      sheetNumber: 1,
      unlocked: true,
    );
    await tester.binding.setSurfaceSize(size);
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      studyAccessWritableRepository.resetDemoAssignments();
    });
    final qs = [_examQ(prompt: shortPrompt)];
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: size),
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
                questions: qs,
              ),
            ),
            quizAttemptRepositoryOverride: _FakeAttemptRepo(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpAssignedPlayer(
    WidgetTester tester,
    Size size, {
    double textScale = 1,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    final repo = AssignedQuizRepositoryFake(
      questions: [_assignedQ(prompt: shortPrompt)],
    );
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: MaterialApp(
          home: AssignedQuizPlayerPage(
            repository: repo,
            assignment: _summary(),
            start: const AssignedQuizAttemptStartResult(
              attemptId: 'att-1',
              attemptNumber: 1,
              resumed: false,
              questionCount: 1,
              attemptsUsed: 1,
            ),
            questions: repo.questions,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpAssignedReview(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    final repo = AssignedQuizRepositoryFake(
      reviewItems: [
        const AssignedQuizReviewItem(
          position: 1,
          prompt: shortPrompt,
          optionA: 'Opzione A',
          optionB: 'Opzione B',
          optionC: 'Opzione C',
          correctOption: 'A',
          selectedOption: 'B',
          isCorrect: false,
          lessonNumber: 1,
        ),
      ],
    );
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: size),
        child: MaterialApp(
          home: AssignedQuizReviewPage(
            repository: repo,
            attemptId: 'att-1',
            assignmentTitle: 'Quiz',
            publicCode: 'AQZ-1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('classroom opt-in vs Assigned legacy', () {
    for (final size in const [
      Size(390, 844),
      Size(768, 1024),
      Size(1024, 768),
      Size(1440, 900),
      Size(1920, 1080),
    ]) {
      testWidgets('Assigned player legacy @${size.width.toInt()}', (
        tester,
      ) async {
        await pumpAssignedPlayer(tester, size);
        final panel = tester.widget<QuizQuestionPromptPanel>(
          find.byType(QuizQuestionPromptPanel),
        );
        expect(panel.classroomScale, isFalse);
        final font = _promptFontSize(tester, prompt: shortPrompt);
        final expected = QuizPlayerVisual.questionFontSize(
          tester.element(find.byType(QuizQuestionPromptPanel)),
          scale: QuizPlayerTypeScale.legacy,
        );
        expect(font, expected);
        expect(font, lessThanOrEqualTo(QuizPlayerVisual.questionFontLegacyDesktop));
        expect(font, isNot(QuizPlayerVisual.questionFontLargeDesktop));
        expect(font, isNot(QuizPlayerVisual.questionFontDesktop));
      });

      testWidgets('Assigned review legacy @${size.width.toInt()}', (
        tester,
      ) async {
        await pumpAssignedReview(tester, size);
        final panel = tester.widget<QuizQuestionPromptPanel>(
          find.byType(QuizQuestionPromptPanel),
        );
        expect(panel.classroomScale, isFalse);
        final font = _promptFontSize(tester, prompt: shortPrompt);
        expect(
          font,
          QuizPlayerVisual.questionFontSize(
            tester.element(find.byType(QuizQuestionPromptPanel)),
            scale: QuizPlayerTypeScale.legacy,
          ),
        );
        expect(font, lessThanOrEqualTo(18.5));
      });
    }

    testWidgets('Exam classroom @1920', (tester) async {
      await pumpExam(tester, const Size(1920, 1080));
      final panel = tester.widget<QuizQuestionPromptPanel>(
        find.byType(QuizQuestionPromptPanel),
      );
      expect(panel.classroomScale, isTrue);
      final font = _promptFontSize(tester, prompt: shortPrompt);
      expect(font, QuizPlayerVisual.questionFontLargeDesktop);
    });

    testWidgets('Lesson classroom @1920', (tester) async {
      await pumpLesson(tester, const Size(1920, 1080));
      final panel = tester.widget<QuizQuestionPromptPanel>(
        find.byType(QuizQuestionPromptPanel),
      );
      expect(panel.classroomScale, isTrue);
      final font = _promptFontSize(tester, prompt: shortPrompt);
      expect(font, QuizPlayerVisual.questionFontLargeDesktop);
    });

    testWidgets('Exam classroom @1440 and Assigned diverge', (tester) async {
      await pumpExam(tester, const Size(1440, 900));
      final examFont = _promptFontSize(tester, prompt: shortPrompt);
      await pumpAssignedPlayer(tester, const Size(1440, 900));
      final assignedFont = _promptFontSize(tester, prompt: shortPrompt);
      expect(examFont, QuizPlayerVisual.questionFontLargeDesktop);
      expect(assignedFont, QuizPlayerVisual.questionFontLegacyDesktop);
      expect(examFont, greaterThan(assignedFont));
    });
  });

  group('textScale accessibility', () {
    const longPrompt = 'Domanda lunga isolation. '
        'Testo ripetuto per coprire la soglia di riduzione tipografica. '
        'Ancora contenuto didattico nautico su regole di navigazione e priorità.';

    testWidgets('classroom desktop textScale 1.3/1.5 no overflow', (
      tester,
    ) async {
      for (final scale in [1.3, 1.5]) {
        await tester.binding.setSurfaceSize(const Size(1440, 900));
        addTearDown(() async {
          await tester.binding.setSurfaceSize(null);
        });
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: const Size(1440, 900),
              textScaler: TextScaler.linear(scale),
            ),
            child: MaterialApp(
              home: QuizExamPlayerPage(
                categoryId: LicenseCategoryId.d1,
                questions: [_examQ(prompt: longPrompt)],
                clientAttemptToken: 'scale-ts',
                repository: ExamQuizAttemptRepositoryFake(
                  submitResult: ExamQuizAttemptSubmitResult(
                    idempotent: false,
                    attempt: ExamQuizAttemptSummary(
                      id: 'att',
                      licenseCategory: LicenseCategoryId.d1,
                      completedAt: DateTime.utc(2026, 10, 17),
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
        expect(find.textContaining('Domanda lunga'), findsOneWidget);
        expect(find.byType(FilledButton), findsWidgets);
        expect(tester.takeException(), isNull);
        final panel = tester.widget<QuizQuestionPromptPanel>(
          find.byType(QuizQuestionPromptPanel),
        );
        expect(panel.classroomScale, isTrue);
      }
    });

    testWidgets('Assigned legacy textScale 1.3/1.5 no overflow', (tester) async {
      for (final scale in [1.3, 1.5]) {
        await pumpAssignedPlayer(
          tester,
          const Size(1440, 900),
          textScale: scale,
        );
        expect(find.text(shortPrompt), findsOneWidget);
        expect(tester.takeException(), isNull);
        final panel = tester.widget<QuizQuestionPromptPanel>(
          find.byType(QuizQuestionPromptPanel),
        );
        expect(panel.classroomScale, isFalse);
        expect(
          _promptFontSize(tester, prompt: shortPrompt),
          QuizPlayerVisual.questionFontLegacyDesktop,
        );
      }
    });
  });
}
