import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/models/error_review_recommendation.dart';
import 'package:scuola_nautica_liana/models/lesson_quiz_performance_snapshot.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';
import 'package:scuola_nautica_liana/models/quiz_attempt_activity.dart';
import 'package:scuola_nautica_liana/models/quiz_statistics_summary.dart';
import 'package:scuola_nautica_liana/services/error_review_provider.dart';
import 'package:scuola_nautica_liana/services/student_area_context.dart';
import 'package:scuola_nautica_liana/widgets/statistics_lesson_error_chart.dart';
import 'package:scuola_nautica_liana/widgets/statistics_recent_attempts_section.dart';
import 'package:scuola_nautica_liana/widgets/statistics_recommended_review_section.dart';
import 'package:scuola_nautica_liana/widgets/statistics_summary_section.dart';

List<LessonQuizPerformanceSnapshot> _lessonSnapshots() {
  return const [
    LessonQuizPerformanceSnapshot(
      categoryId: LicenseCategoryId.motore,
      lessonNumber: 1,
      lessonTitle: '1. Teoria dello scafo',
      totalAttempts: 6,
      averageErrorPercentage: 97.5,
    ),
    LessonQuizPerformanceSnapshot(
      categoryId: LicenseCategoryId.motore,
      lessonNumber: 2,
      lessonTitle: '2. Motori endotermici',
      totalAttempts: 2,
      averageErrorPercentage: 40,
    ),
  ];
}

QuizStatisticsSummary _summary() {
  return QuizStatisticsSummary(
    completedSheetsCount: 6,
    totalQuestions: 120,
    correctCount: 3,
    wrongCount: 22,
    unansweredCount: 95,
    accuracyPercentage: 2.5,
    errorPercentage: 97.5,
    averageErrorsPerSheet: 22 / 6,
    ignoredIncompleteAttempts: 0,
    lastActivityAt: DateTime.utc(2026, 7, 10, 12),
    lastLessonNumber: 1,
    lastSheetNumber: 6,
  );
}

void main() {
  group('StatisticsSummarySection', () {
    testWidgets('KPI schede, precisione, errori e media', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: StatisticsSummarySection(summary: _summary())),
        ),
      );

      expect(find.text('Schede completate'), findsOneWidget);
      expect(find.text('6'), findsWidgets);
      expect(find.text('Precisione'), findsOneWidget);
      expect(find.text('2,5%'), findsOneWidget);
      expect(find.text('Risposte errate'), findsOneWidget);
      expect(find.text('22'), findsWidgets);
      expect(find.text('Non risposte'), findsOneWidget);
      expect(find.text('95'), findsOneWidget);
      expect(find.text('Media errori per scheda'), findsOneWidget);
      expect(find.textContaining('3,7'), findsOneWidget);
      expect(find.text('Ultima attività'), findsOneWidget);
      expect(find.textContaining('Lez. 1'), findsOneWidget);
    });

    test('formattazione percentuali', () {
      expect(StatisticsSummarySection.formatPercent(0), '0%');
      expect(StatisticsSummarySection.formatPercent(25), '25%');
      expect(StatisticsSummarySection.formatPercent(18.34), '18,3%');
    });
  });

  group('StatisticsLessonErrorChart', () {
    testWidgets('grafico riceve snapshot reali ordinati per lezione', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatisticsLessonErrorChart(
              lessonSnapshots: _lessonSnapshots(),
            ),
          ),
        ),
      );

      expect(find.text('Risposte non corrette per lezione'), findsOneWidget);
      expect(find.textContaining('Lez. 1'), findsOneWidget);
      expect(find.textContaining('Lez. 2'), findsOneWidget);
      expect(find.text('97,5%'), findsOneWidget);
    });
  });

  group('StatisticsRecentAttemptsSection', () {
    testWidgets('attività recenti ordinate e formattate', (tester) async {
      final attempts = [
        QuizAttemptActivity(
          quizResultId: 'r6',
          lessonNumber: 1,
          sheetNumber: 6,
          totalQuestions: 20,
          correctCount: 0,
          wrongCount: 3,
          unansweredCount: 17,
          errorPercentage: 100,
          completedAt: DateTime.utc(2026, 7, 10, 6),
        ),
        QuizAttemptActivity(
          quizResultId: 'r5',
          lessonNumber: 1,
          sheetNumber: 5,
          totalQuestions: 20,
          correctCount: 0,
          wrongCount: 4,
          unansweredCount: 16,
          errorPercentage: 100,
          completedAt: DateTime.utc(2026, 7, 10, 5),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatisticsRecentAttemptsSection(attempts: attempts),
          ),
        ),
      );

      expect(find.text('Ultime schede svolte'), findsOneWidget);
      expect(find.text('Lezione 1 · Scheda 6'), findsOneWidget);
      expect(find.text('Lezione 1 · Scheda 5'), findsOneWidget);
      expect(find.textContaining('Errate 3'), findsOneWidget);
      expect(find.textContaining('Non risposte 17'), findsOneWidget);
    });

    testWidgets('lista vuota non mostra sezione', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: StatisticsRecentAttemptsSection(attempts: [])),
        ),
      );

      expect(find.text('Ultime schede svolte'), findsNothing);
    });
  });

  group('StatisticsRecommendedReviewSection', () {
    testWidgets('raccomandazioni da snapshot senza secondo fetch', (
      tester,
    ) async {
      final viewData = ErrorReviewProvider.buildViewDataFromSnapshots(
        categoryId: LicenseCategoryId.motore,
        snapshots: _lessonSnapshots(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatisticsRecommendedReviewSection(
              categoryId: LicenseCategoryId.motore,
              viewData: viewData,
            ),
          ),
        ),
      );

      expect(find.text('Argomenti da ripassare'), findsOneWidget);
      expect(
        find.textContaining('Suggerimenti basati sulle tue schede completate'),
        findsOneWidget,
      );
      expect(find.textContaining('Teoria dello scafo'), findsOneWidget);
      expect(find.text('Apri Ripasso errori'), findsOneWidget);
    });

    testWidgets('CTA assente in preview staff', (tester) async {
      final viewData = ErrorReviewProvider.buildViewDataFromSnapshots(
        categoryId: LicenseCategoryId.motore,
        snapshots: _lessonSnapshots(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StudentAreaContext(
            mode: StudentAreaMode.staffPreview,
            readOnly: true,
            child: Scaffold(
              body: StatisticsRecommendedReviewSection(
                categoryId: LicenseCategoryId.motore,
                viewData: viewData,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Apri Ripasso errori'), findsNothing);
    });
  });

  group('ErrorReviewProvider.buildViewDataFromSnapshots', () {
    test('costruisce raccomandazioni da snapshot caricati', () {
      final view = ErrorReviewProvider.buildViewDataFromSnapshots(
        categoryId: LicenseCategoryId.motore,
        snapshots: _lessonSnapshots(),
      );

      expect(view.emptyKind, isNull);
      expect(view.recommendations, isNotEmpty);
      expect(view.recommendations.first.lessonNumber, 1);
    });

    test('snapshot vuoti → noQuizData', () {
      final view = ErrorReviewProvider.buildViewDataFromSnapshots(
        categoryId: LicenseCategoryId.motore,
        snapshots: const [],
      );

      expect(view.emptyKind, ErrorReviewEmptyKind.noQuizData);
      expect(view.recommendations, isEmpty);
    });
  });
}
