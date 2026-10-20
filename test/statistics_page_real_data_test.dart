import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/student_quiz_statistics_models.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';
import 'package:scuola_nautica_liana/pages/statistics_page.dart';
import 'package:scuola_nautica_liana/repositories/quiz_statistics_repository.dart';
import 'package:scuola_nautica_liana/repositories/student_quiz_statistics_repository.dart';
import 'package:scuola_nautica_liana/services/student_area_context.dart';

class _FakeStudentStatsRepo implements StudentQuizStatisticsRepository {
  _FakeStudentStatsRepo({
    this.result,
    this.error,
    this.unauthenticated = false,
    this.delay = Duration.zero,
  });

  StudentQuizStatistics? result;
  Object? error;
  bool unauthenticated;
  Duration delay;
  int fetchCount = 0;
  LicenseCategoryId? lastCategoryId;

  @override
  Future<StudentQuizStatistics> fetchCategoryStatistics({
    required LicenseCategoryId categoryId,
  }) async {
    fetchCount++;
    lastCategoryId = categoryId;
    await Future<void>.delayed(delay);
    if (unauthenticated) {
      throw const QuizStatisticsUnauthenticatedException();
    }
    if (error != null) throw error!;
    return result ?? StudentQuizStatistics.empty(categoryId);
  }
}

StudentQuizStatistics _motoreStatsWithData({int ignoredLesson = 0}) {
  final at = DateTime.utc(2026, 7, 10, 12);
  final topic = TopicStatistics(
    lessonNumber: 1,
    title: '1. Teoria dello scafo',
    counts: TopicAnswerCounts(
      correct: 3,
      wrong: 22,
      unanswered: 95,
      lastActivity: at,
    ),
  );
  return StudentQuizStatistics(
    categoryId: LicenseCategoryId.motore,
    study: const StudyStatistics(
      sheetsCompleted: 6,
      correct: 3,
      wrong: 22,
      unanswered: 95,
      topicsStudied: 1,
      topicsTotal: 14,
    ),
    exam: ExamStatistics(
      simulationsCount: 1,
      passedCount: 0,
      averageErrors: 8,
      recentResults: [
        RecentExamResult(
          attemptId: 'e1',
          completedAt: at,
          passed: false,
          errorCount: 8,
        ),
      ],
    ),
    topicsAll: [topic],
    topicsStudy: [topic],
    topicsExam: const [],
    reviewAll: [ReviewTopic(rank: 1, topic: topic)],
    reviewStudy: [ReviewTopic(rank: 1, topic: topic)],
    reviewExam: const [],
    ignoredIncompleteLessonAttempts: ignoredLesson,
  );
}

void main() {
  tearDown(() {
    studentAreaPreviewActiveMode.value = null;
  });

  group('StatisticsPage real data (STUDENT.STATS.1)', () {
    testWidgets('loading iniziale', (tester) async {
      final repo = _FakeStudentStatsRepo(
        result: _motoreStatsWithData(),
        delay: const Duration(milliseconds: 80),
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
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('student-stats-studio-card')), findsOneWidget);
    });

    testWidgets('dashboard con dati', (tester) async {
      final repo = _FakeStudentStatsRepo(result: _motoreStatsWithData());
      await tester.pumpWidget(
        MaterialApp(
          home: StatisticsPage(
            categoryId: LicenseCategoryId.motore,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Studio'), findsWidgets);
      expect(find.text('Da ripassare'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('student-stats-topic-section')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Statistiche per argomento'), findsOneWidget);
      expect(repo.fetchCount, 1);
      expect(repo.lastCategoryId, LicenseCategoryId.motore);
    });

    testWidgets('empty senza catalogo né attività', (tester) async {
      final repo = _FakeStudentStatsRepo(
        result: StudentQuizStatistics.empty(LicenseCategoryId.motore),
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
      expect(find.text('Nessuna attività'), findsOneWidget);
    });

    testWidgets('errore di rete', (tester) async {
      final repo = _FakeStudentStatsRepo(error: Exception('network'));
      await tester.pumpWidget(
        MaterialApp(
          home: StatisticsPage(
            categoryId: LicenseCategoryId.motore,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Errore di caricamento'), findsOneWidget);
      expect(find.text('Riprova'), findsOneWidget);
    });

    testWidgets('unauthenticated', (tester) async {
      final repo = _FakeStudentStatsRepo(unauthenticated: true);
      await tester.pumpWidget(
        MaterialApp(
          home: StatisticsPage(
            categoryId: LicenseCategoryId.motore,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sessione non disponibile'), findsOneWidget);
    });

    testWidgets('staff preview non carica repo', (tester) async {
      studentAreaPreviewActiveMode.value = StudentAreaMode.staffPreview;
      final repo = _FakeStudentStatsRepo(result: _motoreStatsWithData());
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
      expect(find.textContaining('anteprima'), findsWidgets);
    });

    testWidgets('pull-to-refresh richiama fetch', (tester) async {
      final repo = _FakeStudentStatsRepo(result: _motoreStatsWithData());
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
      await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      expect(repo.fetchCount, greaterThanOrEqualTo(2));
    });
  });
}
