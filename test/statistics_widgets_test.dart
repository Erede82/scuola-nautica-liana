import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/models/error_review_recommendation.dart';
import 'package:scuola_nautica_liana/models/lesson_quiz_performance_snapshot.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';
import 'package:scuola_nautica_liana/models/lesson_quiz_progress.dart';
import 'package:scuola_nautica_liana/models/quiz_attempt_activity.dart';
import 'package:scuola_nautica_liana/models/quiz_statistics_summary.dart';
import 'package:scuola_nautica_liana/services/error_review_provider.dart';
import 'package:scuola_nautica_liana/services/student_area_context.dart';
import 'package:scuola_nautica_liana/widgets/statistics_error_trend.dart';
import 'package:scuola_nautica_liana/widgets/statistics_lesson_error_chart.dart';
import 'package:scuola_nautica_liana/widgets/statistics_recent_attempts_section.dart';
import 'package:scuola_nautica_liana/widgets/statistics_recommended_review_section.dart';
import 'package:scuola_nautica_liana/widgets/statistics_summary_section.dart';
import 'package:scuola_nautica_liana/widgets/statistics_topic_progress_section.dart';

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

CategoryQuizProgress _progress() {
  return const CategoryQuizProgress(
    totalAvailableSheets: 328,
    totalCompletedUniqueSheets: 6,
    overallCompletionPercentage: 1.8,
    lessonProgress: [
      LessonQuizProgress(
        lessonNumber: 1,
        lessonTitle: '1. Teoria dello scafo',
        availableSheetsCount: 24,
        completedUniqueSheetsCount: 6,
        completionPercentage: 25,
        isAvailable: true,
        isComplete: false,
      ),
    ],
    completedLessonsCount: 0,
    availableLessonsCount: 14,
    inProgressLessonsCount: 1,
  );
}

List<QuizAttemptActivity> _recentAttempts() {
  return [
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
}

void main() {
  group('StatisticsSummarySection', () {
    testWidgets('KPI schede, precisione, media e simulazioni neutre', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatisticsSummarySection(
                summary: _summary(),
                progress: _progress(),
                recentAttempts: _recentAttempts(),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Schede completate'), findsOneWidget);
      expect(find.text('6 su 328'), findsOneWidget);
      expect(find.text('Progresso argomenti'), findsOneWidget);
      expect(find.text('0 su 14 completati'), findsOneWidget);
      expect(find.text('Simulazioni esame'), findsOneWidget);
      expect(find.text('Storico non ancora disponibile'), findsOneWidget);
      expect(find.text('Precisione'), findsOneWidget);
      expect(find.text('2,5%'), findsOneWidget);
      expect(find.text('Risposte errate'), findsNothing);
      expect(find.text('Non risposte'), findsNothing);
      expect(find.text('Media errori per scheda'), findsOneWidget);
      expect(find.text('Entro la soglia'), findsOneWidget);
      expect(find.text('Ultima attività'), findsOneWidget);
      expect(find.textContaining('Lezione 1'), findsOneWidget);
    });

    testWidgets('media senza tentativi è neutra', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatisticsSummarySection(
                summary: QuizStatisticsSummary.empty,
                progress: CategoryQuizProgress.empty,
                recentAttempts: const [],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Nessuna scheda'), findsWidgets);
      expect(find.text('Entro la soglia'), findsNothing);
      expect(find.text('Sopra la soglia'), findsNothing);
    });

    test('formattazione percentuali', () {
      expect(StatisticsSummarySection.formatPercent(0), '0%');
      expect(StatisticsSummarySection.formatPercent(25), '25%');
      expect(StatisticsSummarySection.formatPercent(18.34), '18,3%');
    });

    testWidgets('media 4,0 mostra Entro la soglia', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatisticsSummarySection(
                summary: QuizStatisticsSummary(
                  completedSheetsCount: 10,
                  totalQuestions: 200,
                  correctCount: 2,
                  wrongCount: 40,
                  unansweredCount: 158,
                  accuracyPercentage: 1,
                  errorPercentage: 99,
                  averageErrorsPerSheet: 4.0,
                  ignoredIncompleteAttempts: 0,
                  lastActivityAt: DateTime.utc(2026, 7, 10, 12),
                  lastLessonNumber: 1,
                  lastSheetNumber: 6,
                ),
                progress: _progress(),
                recentAttempts: _recentAttempts(),
              ),
            ),
          ),
        ),
      );

      expect(find.text('4'), findsWidgets);
      expect(find.text('Entro la soglia'), findsOneWidget);
      expect(find.text('Sopra la soglia'), findsNothing);
    });

    testWidgets('media 4,1 mostra Sopra la soglia', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatisticsSummarySection(
                summary: QuizStatisticsSummary(
                  completedSheetsCount: 10,
                  totalQuestions: 200,
                  correctCount: 2,
                  wrongCount: 41,
                  unansweredCount: 157,
                  accuracyPercentage: 1,
                  errorPercentage: 99,
                  averageErrorsPerSheet: 4.1,
                  ignoredIncompleteAttempts: 0,
                  lastActivityAt: DateTime.utc(2026, 7, 10, 12),
                  lastLessonNumber: 1,
                  lastSheetNumber: 6,
                ),
                progress: _progress(),
                recentAttempts: _recentAttempts(),
              ),
            ),
          ),
        ),
      );

      expect(find.textContaining('4,1'), findsOneWidget);
      expect(find.text('Sopra la soglia'), findsOneWidget);
      expect(find.text('Entro la soglia'), findsNothing);
    });
  });

  group('StatisticsTopicProgressSection', () {
    testWidgets('mostra 14 argomenti ordinati', (tester) async {
      final lessons = List<LessonQuizProgress>.generate(
        14,
        (index) => LessonQuizProgress(
          lessonNumber: index + 1,
          lessonTitle: '${index + 1}. Argomento ${index + 1}',
          availableSheetsCount: 10,
          completedUniqueSheetsCount: index == 0 ? 10 : 0,
          completionPercentage: index == 0 ? 100 : 0,
          isAvailable: true,
          isComplete: index == 0,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatisticsTopicProgressSection(lessonProgress: lessons),
            ),
          ),
        ),
      );

      expect(find.text('Avanzamento per argomento'), findsOneWidget);
      expect(find.text('Completato'), findsOneWidget);
      expect(find.text('1. Argomento 1'), findsOneWidget);
      expect(find.text('14. Argomento 14'), findsOneWidget);
    });

    testWidgets('lezioni non disponibili mostrano etichetta', (tester) async {
      const lesson = LessonQuizProgress(
        lessonNumber: 14,
        lessonTitle: '14. Normativa 2',
        availableSheetsCount: 0,
        completedUniqueSheetsCount: 0,
        completionPercentage: 0,
        isAvailable: false,
        isComplete: false,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatisticsTopicProgressSection(lessonProgress: [lesson]),
          ),
        ),
      );

      expect(find.text('Non disponibile'), findsWidgets);
      expect(find.text('0%'), findsNothing);
    });
  });

  group('StatisticsErrorTrend', () {
    testWidgets('andamento ultime schede in ordine cronologico', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatisticsErrorTrend(attempts: _recentAttempts()),
          ),
        ),
      );

      expect(find.text('3'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.textContaining('Soglia 4 errori'), findsOneWidget);
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
