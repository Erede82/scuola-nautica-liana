import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/multi_topic_quiz_history_models.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';
import 'package:scuola_nautica_liana/models/quiz_question.dart';
import 'package:scuola_nautica_liana/pages/multi_topic_quiz_history_detail_page.dart';
import 'package:scuola_nautica_liana/repositories/multi_topic_quiz_attempt_repository.dart';
import 'package:scuola_nautica_liana/widgets/quiz_answer_result_chip.dart';

void main() {
  testWidgets(
    'history detail: unanswered shows Non risposta, not Risposta errata',
    (tester) async {
      const attemptId = 'att-unanswered-ui';
      final detail = MultiTopicQuizAttemptDetail(
        summary: MultiTopicQuizAttemptSummary(
          id: attemptId,
          sessionId: 'sess-ui',
          licenseCategory: LicenseCategoryId.motore,
          lessonNumbers: const [1, 2],
          sheetIndex: 1,
          totalSheets: 1,
          completedAt: DateTime.utc(2026, 9, 26, 12),
          durationSeconds: 30,
          totalQuestions: 20,
          correctCount: 19,
          wrongCount: 0,
          unansweredCount: 1,
        ),
        answers: const [
          MultiTopicQuizAttemptAnswerSnapshot(
            position: 1,
            questionId: 'q-u',
            prompt: 'Prompt non risposta',
            optionA: 'A',
            optionB: 'B',
            optionC: 'C',
            selectedOption: null,
            correctOption: QuizAnswerOption.b,
            isCorrect: false,
            lessonNumber: 1,
            explanation: 'Spiegazione presente',
          ),
        ],
      );

      final fake = MultiTopicQuizAttemptRepositoryFake(
        detailById: {attemptId: detail},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MultiTopicQuizHistoryDetailPage(
            attemptId: attemptId,
            repository: fake,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Non risposta'), findsOneWidget);
      expect(find.text('Risposta errata'), findsNothing);
      expect(find.text('La risposta corretta è B.'), findsOneWidget);
      expect(find.text('Spiegazione presente'), findsOneWidget);
      expect(find.textContaining('La tua risposta:'), findsNothing);

      final chip = tester.widget<QuizAnswerResultChip>(
        find.byType(QuizAnswerResultChip),
      );
      expect(chip.unanswered, isTrue);
    },
  );

  testWidgets('history detail: wrong answer still shows Risposta errata', (
    tester,
  ) async {
    const attemptId = 'att-wrong-ui';
    final detail = MultiTopicQuizAttemptDetail(
      summary: MultiTopicQuizAttemptSummary(
        id: attemptId,
        sessionId: 'sess-w',
        licenseCategory: LicenseCategoryId.d1,
        lessonNumbers: const [3, 4],
        sheetIndex: 1,
        totalSheets: 2,
        completedAt: DateTime.utc(2026, 9, 26, 13),
        durationSeconds: 25,
        totalQuestions: 15,
        correctCount: 14,
        wrongCount: 1,
        unansweredCount: 0,
      ),
      answers: const [
        MultiTopicQuizAttemptAnswerSnapshot(
          position: 1,
          questionId: 'q-w',
          prompt: 'Prompt errata',
          optionA: 'A',
          optionB: 'B',
          optionC: 'C',
          selectedOption: QuizAnswerOption.a,
          correctOption: QuizAnswerOption.c,
          isCorrect: false,
          lessonNumber: 3,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MultiTopicQuizHistoryDetailPage(
          attemptId: attemptId,
          repository: MultiTopicQuizAttemptRepositoryFake(
            detailById: {attemptId: detail},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Risposta errata'), findsOneWidget);
    expect(find.text('Non risposta'), findsNothing);
    expect(find.textContaining('La tua risposta: A'), findsOneWidget);
  });
}
