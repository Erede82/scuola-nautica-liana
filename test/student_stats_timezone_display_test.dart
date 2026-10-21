import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/student_quiz_statistics_models.dart';
import 'package:scuola_nautica_liana/domain/student_stats_source.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';
import 'package:scuola_nautica_liana/pages/statistics_page.dart';
import 'package:scuola_nautica_liana/repositories/staff_student_quiz_statistics_repository.dart';
import 'package:scuola_nautica_liana/repositories/student_quiz_statistics_repository.dart';
import 'package:scuola_nautica_liana/widgets/staff_student_statistics_panel.dart';
import 'package:scuola_nautica_liana/widgets/student_quiz_statistics_dashboard.dart';
import 'package:scuola_nautica_liana/widgets/student_stats_exam_card.dart';

/// RPC-style UTC instant from production screenshot case.
final _completedAtUtc = DateTime.parse('2026-10-21T18:56:00Z');

StudentQuizStatistics _statsWithExamUtc() {
  return StudentQuizStatistics(
    categoryId: LicenseCategoryId.motore,
    study: const StudyStatistics(
      sheetsCompleted: 0,
      correct: 0,
      wrong: 0,
      unanswered: 0,
      topicsStudied: 0,
      topicsTotal: 1,
    ),
    exam: ExamStatistics(
      simulationsCount: 1,
      passedCount: 1,
      averageErrors: 2,
      recentResults: [
        RecentExamResult(
          attemptId: 'exam-1',
          completedAt: _completedAtUtc,
          passed: true,
          errorCount: 2,
        ),
      ],
    ),
    topicsAll: const [],
    topicsStudy: const [],
    topicsExam: const [],
    reviewAll: const [],
    reviewStudy: const [],
    reviewExam: const [],
  );
}

void main() {
  testWidgets(
    'shared dashboard shows Europe/Rome for UTC exam completed_at',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudentQuizStatisticsDashboard(
              statistics: _statsWithExamUtc(),
              reviewSource: StudentStatsSource.all,
              topicSource: StudentStatsSource.all,
              onReviewSourceChanged: (_) {},
              onTopicSourceChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(StudentStatsExamCard), findsOneWidget);
      expect(find.text('21 ottobre 2026 · 20:56'), findsOneWidget);
      expect(find.text('21 ottobre 2026 · 18:56'), findsNothing);
    },
  );

  testWidgets(
    'staff panel renders Rome time for RPC UTC completed_at',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StaffStudentStatisticsPanel(
              studentId: 'student-1',
              categoryId: LicenseCategoryId.motore,
              repository: _StaffRepo(
                StaffStudentQuizStatisticsLoaded(_statsWithExamUtc()),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('21 ottobre 2026 · 20:56'), findsOneWidget);
      expect(find.text('Ultime simulazioni'), findsOneWidget);
    },
  );

  testWidgets(
    'student StatisticsPage renders same Rome time',
    (tester) async {
      tester.view.physicalSize = const Size(1024, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = _SelfRepo(_statsWithExamUtc());
      await tester.pumpWidget(
        MaterialApp(
          home: StatisticsPage(
            categoryId: LicenseCategoryId.motore,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('21 ottobre 2026 · 20:56'), findsOneWidget);
      expect(find.text('21 ottobre 2026 · 18:56'), findsNothing);
    },
  );
}

class _StaffRepo implements StaffStudentQuizStatisticsRepository {
  _StaffRepo(this.result);
  final StaffStudentQuizStatisticsResult result;

  @override
  Future<StaffStudentQuizStatisticsResult> fetchStudentCategoryStatistics({
    required String studentId,
    required LicenseCategoryId categoryId,
  }) async => result;
}

class _SelfRepo implements StudentQuizStatisticsRepository {
  _SelfRepo(this.result);
  final StudentQuizStatistics result;

  @override
  Future<StudentQuizStatistics> fetchCategoryStatistics({
    required LicenseCategoryId categoryId,
  }) async => result;
}
