import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/student_quiz_statistics_models.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';
import 'package:scuola_nautica_liana/pages/statistics_page.dart';
import 'package:scuola_nautica_liana/repositories/student_quiz_statistics_repository.dart';
import 'package:scuola_nautica_liana/services/student_area_context.dart';

class _FakeStudentStatsRepo implements StudentQuizStatisticsRepository {
  _FakeStudentStatsRepo({
    this.result,
    this.error,
  });

  StudentQuizStatistics? result;
  Object? error;
  int fetchCount = 0;

  @override
  Future<StudentQuizStatistics> fetchCategoryStatistics({
    required LicenseCategoryId categoryId,
  }) async {
    fetchCount++;
    if (error != null) throw error!;
    return result ?? StudentQuizStatistics.empty(categoryId, topicsTotal: 14);
  }
}

StudentQuizStatistics _richStats() {
  final at = DateTime.utc(2026, 10, 10, 12);
  final topics = [
    TopicStatistics(
      lessonNumber: 1,
      title: '1. Teoria dello scafo',
      counts: TopicAnswerCounts(
        correct: 10,
        wrong: 6,
        unanswered: 4,
        lastActivity: at,
      ),
    ),
    TopicStatistics(
      lessonNumber: 2,
      title: '2. Motori endotermici',
      counts: TopicAnswerCounts(
        correct: 12,
        wrong: 5,
        unanswered: 3,
        lastActivity: at,
      ),
    ),
    TopicStatistics(
      lessonNumber: 3,
      title: '3. Sicurezza',
      counts: TopicAnswerCounts(
        correct: 8,
        wrong: 8,
        unanswered: 4,
        lastActivity: at,
      ),
    ),
  ];
  return StudentQuizStatistics(
    categoryId: LicenseCategoryId.motore,
    study: const StudyStatistics(
      sheetsCompleted: 12,
      correct: 80,
      wrong: 30,
      unanswered: 20,
      topicsStudied: 3,
      topicsTotal: 14,
    ),
    exam: ExamStatistics(
      simulationsCount: 3,
      passedCount: 2,
      averageErrors: 4.5,
      recentResults: [
        RecentExamResult(
          attemptId: 'e1',
          completedAt: at,
          passed: true,
          errorCount: 3,
        ),
        RecentExamResult(
          attemptId: 'e2',
          completedAt: at.subtract(const Duration(days: 1)),
          passed: false,
          errorCount: 7,
        ),
      ],
    ),
    topicsAll: topics,
    topicsStudy: topics,
    topicsExam: const [],
    reviewAll: [
      ReviewTopic(rank: 1, topic: topics[2]),
      ReviewTopic(rank: 2, topic: topics[0]),
      ReviewTopic(rank: 3, topic: topics[1]),
    ],
    reviewStudy: [
      ReviewTopic(rank: 1, topic: topics[2]),
      ReviewTopic(rank: 2, topic: topics[0]),
      ReviewTopic(rank: 3, topic: topics[1]),
    ],
    reviewExam: const [],
  );
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required Size size,
  required _FakeStudentStatsRepo repo,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      home: StatisticsPage(
        categoryId: LicenseCategoryId.motore,
        repository: repo,
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() {
    studentAreaPreviewActiveMode.value = null;
  });

  group('Student stats dashboard layout', () {
    for (final size in [
      const Size(390, 844),
      const Size(768, 1024),
      const Size(1440, 900),
    ]) {
      testWidgets('viewport ${size.width.toInt()} shows 3 cards + topics', (
        tester,
      ) async {
        final repo = _FakeStudentStatsRepo(result: _richStats());
        await _pumpPage(tester, size: size, repo: repo);

        expect(find.byKey(const ValueKey('student-stats-studio-card')), findsOneWidget);
        expect(find.byKey(const ValueKey('student-stats-exam-card')), findsOneWidget);
        expect(find.byKey(const ValueKey('student-stats-review-card')), findsOneWidget);
        expect(find.text('Studio'), findsWidgets);
        expect(find.text('Simulazioni d\'esame'), findsOneWidget);
        expect(find.text('Da ripassare'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('student-stats-topic-section')),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.byKey(const ValueKey('student-stats-topic-section')), findsOneWidget);
        expect(find.text('Statistiche per argomento'), findsOneWidget);
        expect(tester.takeException(), isNull);

        final overflow = find.byWidgetPredicate(
          (w) =>
              w is ErrorWidget ||
              (w is Text && (w.data?.contains('OVERFLOW') ?? false)),
        );
        expect(overflow, findsNothing);
      });
    }

    testWidgets('filter chips switch review source', (tester) async {
      final repo = _FakeStudentStatsRepo(result: _richStats());
      await _pumpPage(tester, size: const Size(390, 844), repo: repo);

      expect(find.text('Continua ad esercitarti'), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('student-stats-review-filter-exam')),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Continua ad esercitarti'),
        findsWidgets,
      );
    });

    testWidgets('empty state', (tester) async {
      final repo = _FakeStudentStatsRepo(
        result: StudentQuizStatistics.empty(
          LicenseCategoryId.motore,
          topicsTotal: 0,
        ),
      );
      await _pumpPage(tester, size: const Size(390, 844), repo: repo);
      expect(find.text('Nessuna attività'), findsOneWidget);
    });

    testWidgets('error state', (tester) async {
      final repo = _FakeStudentStatsRepo(error: Exception('boom'));
      await _pumpPage(tester, size: const Size(390, 844), repo: repo);
      expect(find.text('Errore di caricamento'), findsOneWidget);
    });

    testWidgets('vela unsupported copy', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: StatisticsPage(
            categoryId: LicenseCategoryId.vela,
            repository: _FakeStudentStatsRepo(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Statistiche non disponibili'),
        findsWidgets,
      );
    });
  });
}
