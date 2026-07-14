import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/models/lesson_quiz_performance_snapshot.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';
import 'package:scuola_nautica_liana/models/quiz_attempt_activity.dart';
import 'package:scuola_nautica_liana/models/quiz_category_statistics.dart';
import 'package:scuola_nautica_liana/models/quiz_statistics_summary.dart';
import 'package:scuola_nautica_liana/pages/statistics_page.dart';
import 'package:scuola_nautica_liana/repositories/quiz_statistics_repository.dart';
import 'package:scuola_nautica_liana/services/student_area_context.dart';

class _FakeQuizStatisticsRepository implements QuizStatisticsRepository {
  _FakeQuizStatisticsRepository({
    this.result,
    this.error,
    this.unauthenticated = false,
    this.delay = Duration.zero,
  });

  QuizCategoryStatistics? result;
  Object? error;
  bool unauthenticated;
  Duration delay;
  int fetchCount = 0;
  LicenseCategoryId? lastCategoryId;

  @override
  Future<QuizCategoryStatistics> fetchCategoryStatistics({
    required LicenseCategoryId categoryId,
  }) async {
    fetchCount++;
    lastCategoryId = categoryId;
    await Future<void>.delayed(delay);
    if (unauthenticated) {
      throw const QuizStatisticsUnauthenticatedException();
    }
    if (error != null) throw error!;
    return result ?? QuizCategoryStatistics.empty(categoryId);
  }
}

QuizCategoryStatistics _motoreStatsWithData({int ignored = 0}) {
  return QuizCategoryStatistics(
    categoryId: LicenseCategoryId.motore,
    summary: QuizStatisticsSummary(
      completedSheetsCount: 6,
      totalQuestions: 120,
      correctCount: 3,
      wrongCount: 22,
      unansweredCount: 95,
      accuracyPercentage: 2.5,
      errorPercentage: 97.5,
      averageErrorsPerSheet: 22 / 6,
      ignoredIncompleteAttempts: ignored,
      lastActivityAt: DateTime.utc(2026, 7, 10, 12),
      lastLessonNumber: 1,
      lastSheetNumber: 6,
    ),
    lessonSnapshots: const [
      LessonQuizPerformanceSnapshot(
        categoryId: LicenseCategoryId.motore,
        lessonNumber: 1,
        lessonTitle: '1. Teoria dello scafo',
        totalAttempts: 6,
        averageErrorPercentage: 97.5,
      ),
    ],
    recentAttempts: [
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
    ],
  );
}

void main() {
  tearDown(() {
    studentAreaPreviewActiveMode.value = null;
  });

  group('StatisticsPage real data', () {
    testWidgets('loading iniziale', (tester) async {
      final repo = _FakeQuizStatisticsRepository(
        result: _motoreStatsWithData(),
        delay: const Duration(milliseconds: 200),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StatisticsPage(
            categoryId: LicenseCategoryId.motore,
            repository: repo,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Caricamento statistiche…'), findsOneWidget);
      expect(repo.fetchCount, 1);

      await tester.pumpAndSettle();
      expect(find.text('Caricamento statistiche…'), findsNothing);
    });

    testWidgets('dati reali mostrati con KPI e sezioni', (tester) async {
      final repo = _FakeQuizStatisticsRepository(
        result: _motoreStatsWithData(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StatisticsPage(
            categoryId: LicenseCategoryId.motore,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Riepilogo'), findsOneWidget);
      expect(find.text('6'), findsWidgets);
      expect(find.text('2,5%'), findsOneWidget);
      expect(find.text('22'), findsWidgets);
      expect(find.text('95'), findsOneWidget);
      expect(find.textContaining('3,7'), findsOneWidget);
      expect(find.text('Argomenti da ripassare'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Risposte non corrette per lezione'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Risposte non corrette per lezione'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Ultime schede svolte'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Ultime schede svolte'), findsOneWidget);
      expect(find.text('Lezione 1 · Scheda 6'), findsOneWidget);
    });

    testWidgets('storico vuoto', (tester) async {
      final repo = _FakeQuizStatisticsRepository(
        result: QuizCategoryStatistics.empty(LicenseCategoryId.motore),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StatisticsPage(
            categoryId: LicenseCategoryId.motore,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Non hai ancora completato schede per questo percorso.'),
        findsOneWidget,
      );
      expect(find.text('Vai alle schede'), findsOneWidget);
    });

    testWidgets('errore repository', (tester) async {
      final repo = _FakeQuizStatisticsRepository(error: Exception('network'));

      await tester.pumpWidget(
        MaterialApp(
          home: StatisticsPage(
            categoryId: LicenseCategoryId.motore,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Non è stato possibile caricare le statistiche.'),
        findsOneWidget,
      );
      expect(find.text('Riprova'), findsOneWidget);
    });

    testWidgets('utente non autenticato', (tester) async {
      final repo = _FakeQuizStatisticsRepository(unauthenticated: true);

      await tester.pumpWidget(
        MaterialApp(
          home: StatisticsPage(
            categoryId: LicenseCategoryId.motore,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('La sessione non è disponibile. Accedi nuovamente.'),
        findsOneWidget,
      );
    });

    testWidgets('ignored-only state', (tester) async {
      final repo = _FakeQuizStatisticsRepository(
        result: QuizCategoryStatistics.ignoredOnly(
          categoryId: LicenseCategoryId.motore,
          ignoredIncompleteAttempts: 3,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StatisticsPage(
            categoryId: LicenseCategoryId.motore,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Alcuni tentativi non possono essere inclusi nelle statistiche.',
        ),
        findsOneWidget,
      );
      expect(find.text('Riprova'), findsOneWidget);
    });

    testWidgets('dati validi + ignored attempts mostra nota', (tester) async {
      final repo = _FakeQuizStatisticsRepository(
        result: _motoreStatsWithData(ignored: 2),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StatisticsPage(
            categoryId: LicenseCategoryId.motore,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('2 tentativi incompleti non inclusi'),
        findsOneWidget,
      );
      expect(find.text('Riepilogo'), findsOneWidget);
    });

    testWidgets('preview staff non invoca repository', (tester) async {
      final repo = _FakeQuizStatisticsRepository(
        result: _motoreStatsWithData(),
      );
      studentAreaPreviewActiveMode.value = StudentAreaMode.staffPreview;

      await tester.pumpWidget(
        MaterialApp(
          home: StudentAreaContext(
            mode: StudentAreaMode.staffPreview,
            readOnly: true,
            child: StatisticsPage(
              categoryId: LicenseCategoryId.motore,
              repository: repo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(repo.fetchCount, 0);
      expect(find.text('Statistiche allievo'), findsOneWidget);
      expect(find.text('Anteprima staff'), findsOneWidget);
      expect(find.text('Riepilogo'), findsNothing);
      expect(find.text('6'), findsNothing);
    });

    testWidgets('preview staff non mostra dati staff', (tester) async {
      final repo = _FakeQuizStatisticsRepository(
        result: _motoreStatsWithData(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StudentAreaContext(
            mode: StudentAreaMode.staffPreview,
            readOnly: true,
            child: StatisticsPage(
              categoryId: LicenseCategoryId.motore,
              repository: repo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('22'), findsNothing);
      expect(find.text('95'), findsNothing);
    });

    testWidgets('refresh invoca nuovamente il repository', (tester) async {
      final repo = _FakeQuizStatisticsRepository(
        result: _motoreStatsWithData(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StatisticsPage(
            categoryId: LicenseCategoryId.motore,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.fetchCount, 1);

      await tester.tap(find.byIcon(Icons.refresh_rounded));
      await tester.pumpAndSettle();
      expect(repo.fetchCount, 2);
    });

    testWidgets('vela mostra percorso non disponibile senza errore tecnico', (
      tester,
    ) async {
      final repo = _FakeQuizStatisticsRepository(
        result: _motoreStatsWithData(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StatisticsPage(
            categoryId: LicenseCategoryId.vela,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(repo.fetchCount, 0);
      expect(
        find.text(
          'Le statistiche per questo percorso non sono ancora disponibili.',
        ),
        findsOneWidget,
      );
    });
  });
}
