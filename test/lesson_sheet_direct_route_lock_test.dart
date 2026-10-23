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

class _Repo implements StudentQuizRepository {
  int contentLoads = 0;

  @override
  Future<LessonQuizSheetContent?> fetchLessonSheetContent({
    required LicenseCategoryId categoryId,
    required int lessonNumber,
    required int sheetNumber,
  }) async {
    contentLoads++;
    return LessonQuizSheetContent(
      quizSetId: 'set-1',
      categoryId: categoryId,
      lessonNumber: lessonNumber,
      sheetNumber: sheetNumber,
      questions: const [
        QuizQuestion(
          id: 'q1',
          prompt: 'Domanda che non deve comparire',
          optionA: 'A',
          optionB: 'B',
          optionC: 'C',
          correctOption: QuizAnswerOption.a,
          lessonNumber: 1,
          licenseCategory: 'A12',
        ),
      ],
    );
  }

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
  }) async {
    return const LessonSheetCompletionSnapshot(
      quizSetIdBySheet: {1: 'set-1'},
      completedSheetNumbers: {1},
    );
  }

  @override
  Future<Map<String, List<QuizQuestion>>> fetchExamQuestionsByTopic({
    required LicenseCategoryId categoryId,
  }) async => const {};

  @override
  Future<Map<int, List<QuizQuestion>>> fetchQuestionsForLessons({
    required LicenseCategoryId categoryId,
    required List<int> lessonNumbers,
  }) async => const {};

  @override
  Future<Map<int, List<int>>> fetchLessonSheetNumbersByLesson({
    required LicenseCategoryId categoryId,
  }) async => const {};
}

class _Attempts implements QuizAttemptRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('direct sheet route stays locked after completion', (
    tester,
  ) async {
    studyAccessWritableRepository.applyLessonQuizSheetUnlock(
      categoryId: LicenseCategoryId.motore,
      lessonNumber: 1,
      sheetNumber: 1,
      unlocked: true,
    );
    addTearDown(studyAccessWritableRepository.resetDemoAssignments);

    final repo = _Repo();
    await tester.pumpWidget(
      MaterialApp(
        home: QuizSheetDetailPage(
          lessonNumber: 1,
          sheetNumber: 1,
          categoryId: LicenseCategoryId.motore,
          studentQuizRepositoryOverride: repo,
          quizAttemptRepositoryOverride: _Attempts(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Scheda già svolta'), findsOneWidget);
    expect(find.text('Domanda che non deve comparire'), findsNothing);
    expect(repo.contentLoads, 0);
  });
}
