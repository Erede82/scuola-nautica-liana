import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';
import 'package:scuola_nautica_liana/models/quiz_question.dart';
import 'package:scuola_nautica_liana/models/quiz_wrong_answer_entry.dart';
import 'package:scuola_nautica_liana/repositories/study_access_repository.dart';
import 'package:scuola_nautica_liana/widgets/nautical_answer_marker.dart';
import 'package:scuola_nautica_liana/widgets/quiz_wrong_answer_card.dart';

QuizWrongAnswerEntry _entry({
  int lessonNumber = 1,
  String? explanation,
  String? imagePath,
}) {
  return QuizWrongAnswerEntry(
    questionId: 'q1',
    prompt: 'Domanda di prova per il ripasso',
    optionA: 'Alpha',
    optionB: 'Bravo',
    optionC: 'Charlie',
    latestSelectedOption: QuizAnswerOption.a,
    correctOption: QuizAnswerOption.b,
    explanation: explanation,
    imagePath: imagePath,
    lessonNumber: lessonNumber,
    sheetNumbers: const [2, 5],
    licenseCategoryId: LicenseCategoryId.motore,
    errorCount: 3,
    firstWrongAt: DateTime.utc(2026, 6, 1),
    lastWrongAt: DateTime.utc(2026, 7, 15, 14, 30),
  );
}

void main() {
  tearDown(() {
    studyAccessWritableRepository.resetDemoAssignments();
  });

  group('QuizWrongAnswerCard', () {
    testWidgets('card chiusa mostra prompt e conteggi', (tester) async {
      studyAccessWritableRepository.applyErrorReviewTopicUnlock(
        categoryId: LicenseCategoryId.motore,
        lessonNumber: 1,
        unlocked: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuizWrongAnswerCard(
              entry: _entry(),
              categoryId: LicenseCategoryId.motore,
            ),
          ),
        ),
      );

      expect(find.textContaining('Domanda di prova'), findsOneWidget);
      expect(find.textContaining('Sbagliata 3 volte'), findsOneWidget);
      expect(find.textContaining('Hai risposto'), findsOneWidget);
      expect(find.textContaining('Corretta'), findsOneWidget);
      expect(find.textContaining('q1'), findsNothing);
    });

    testWidgets('espansione mostra opzioni e spiegazione', (tester) async {
      studyAccessWritableRepository.applyErrorReviewTopicUnlock(
        categoryId: LicenseCategoryId.motore,
        lessonNumber: 1,
        unlocked: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuizWrongAnswerCard(
              entry: _entry(explanation: 'Perché B è corretta.'),
              categoryId: LicenseCategoryId.motore,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.expand_more_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Spiegazione'), findsOneWidget);
      expect(find.text('Perché B è corretta.'), findsOneWidget);
      expect(find.textContaining('A. Alpha'), findsOneWidget);
      expect(find.textContaining('B. Bravo'), findsOneWidget);
      expect(find.byType(NauticalAnswerMarker), findsWidgets);
    });

    testWidgets('senza spiegazione non mostra sezione', (tester) async {
      studyAccessWritableRepository.applyErrorReviewTopicUnlock(
        categoryId: LicenseCategoryId.motore,
        lessonNumber: 1,
        unlocked: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuizWrongAnswerCard(
              entry: _entry(),
              categoryId: LicenseCategoryId.motore,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.expand_more_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Spiegazione'), findsNothing);
    });

    testWidgets('lezione bloccata nasconde contenuto', (tester) async {
      studyAccessWritableRepository.applyErrorReviewTopicUnlock(
        categoryId: LicenseCategoryId.motore,
        lessonNumber: 1,
        unlocked: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuizWrongAnswerCard(
              entry: _entry(),
              categoryId: LicenseCategoryId.motore,
            ),
          ),
        ),
      );

      expect(find.text('Ripasso non ancora disponibile'), findsOneWidget);
      expect(find.textContaining('Domanda di prova'), findsNothing);
      expect(find.textContaining('Alpha'), findsNothing);
    });

    testWidgets('gate aggiornato via listenable', (tester) async {
      studyAccessWritableRepository.applyErrorReviewTopicUnlock(
        categoryId: LicenseCategoryId.motore,
        lessonNumber: 1,
        unlocked: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: studyAccessListenable,
              builder: (context, _) => QuizWrongAnswerCard(
                entry: _entry(),
                categoryId: LicenseCategoryId.motore,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Ripasso non ancora disponibile'), findsOneWidget);

      studyAccessWritableRepository.applyErrorReviewTopicUnlock(
        categoryId: LicenseCategoryId.motore,
        lessonNumber: 1,
        unlocked: true,
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Domanda di prova'), findsOneWidget);
      expect(find.text('Ripasso non ancora disponibile'), findsNothing);
    });
  });
}
