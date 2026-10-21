import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/student_quiz_statistics_aggregator.dart';
import 'package:scuola_nautica_liana/domain/student_quiz_statistics_models.dart';
import 'package:scuola_nautica_liana/domain/student_stats_layout.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';
import 'package:scuola_nautica_liana/repositories/staff_student_quiz_statistics_repository.dart';
import 'package:scuola_nautica_liana/widgets/staff_student_statistics_panel.dart';
import 'package:scuola_nautica_liana/widgets/student_stats_review_card.dart';
import 'package:scuola_nautica_liana/widgets/student_stats_studio_card.dart';

class _ControllableRepo implements StaffStudentQuizStatisticsRepository {
  final Map<String, Completer<StaffStudentQuizStatisticsResult>> _pending = {};
  int calls = 0;
  final List<String> callLog = [];

  Completer<StaffStudentQuizStatisticsResult> enqueue(String key) {
    final c = Completer<StaffStudentQuizStatisticsResult>();
    _pending[key] = c;
    return c;
  }

  @override
  Future<StaffStudentQuizStatisticsResult> fetchStudentCategoryStatistics({
    required String studentId,
    required LicenseCategoryId categoryId,
  }) async {
    calls++;
    final key = '$studentId-${categoryId.name}';
    callLog.add(key);
    final existing = _pending[key];
    if (existing != null) return existing.future;
    return StaffStudentQuizStatisticsLoaded(
      StudentQuizStatistics.empty(categoryId, topicsTotal: 1),
    );
  }
}

Widget _wrap(Widget child, {Size size = const Size(1024, 768)}) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: size.width,
          height: size.height,
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('unlinked state copy', (tester) async {
    final repo = _StaticRepo(const StaffStudentQuizStatisticsUnlinked());
    await tester.pumpWidget(
      _wrap(
        StaffStudentStatisticsPanel(
          studentId: 's1',
          categoryId: LicenseCategoryId.motore,
          repository: repo,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Nessuna attività quiz collegata a questo allievo.'),
      findsOneWidget,
    );
    expect(find.byType(StudentStatsStudioCard), findsNothing);
  });

  testWidgets('unsupported category — no load semantics', (tester) async {
    final repo = _StaticRepo(
      const StaffStudentQuizStatisticsUnsupportedCategory(),
    );
    await tester.pumpWidget(
      _wrap(
        StaffStudentStatisticsPanel(
          studentId: 's1',
          categoryId: LicenseCategoryId.vela,
          repository: repo,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('non disponibili per questa categoria'),
      findsOneWidget,
    );
  });

  testWidgets('inactive panel does not fetch', (tester) async {
    final repo = _ControllableRepo();
    await tester.pumpWidget(
      _wrap(
        StaffStudentStatisticsPanel(
          studentId: 's1',
          categoryId: LicenseCategoryId.motore,
          repository: repo,
          active: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.calls, 0);
  });

  testWidgets('student race: stale A ignored after B', (tester) async {
    final repo = _ControllableRepo();
    final a = repo.enqueue('A-${LicenseCategoryId.motore.name}');
    final b = repo.enqueue('B-${LicenseCategoryId.motore.name}');

    await tester.pumpWidget(
      _wrap(
        StaffStudentStatisticsPanel(
          key: const ValueKey('panel'),
          studentId: 'A',
          categoryId: LicenseCategoryId.motore,
          repository: repo,
        ),
      ),
    );
    await tester.pump();

    await tester.pumpWidget(
      _wrap(
        StaffStudentStatisticsPanel(
          key: const ValueKey('panel'),
          studentId: 'B',
          categoryId: LicenseCategoryId.motore,
          repository: repo,
        ),
      ),
    );
    await tester.pump();

    b.complete(
      StaffStudentQuizStatisticsLoaded(
        StudentQuizStatistics.empty(
          LicenseCategoryId.motore,
          topicsTotal: 2,
        ),
      ),
    );
    await tester.pumpAndSettle();

    a.complete(
      StaffStudentQuizStatisticsLoaded(
        StudentQuizStatistics.empty(
          LicenseCategoryId.motore,
          topicsTotal: 99,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // B empty with catalog topicsTotal 2 → showDashboard true if catalog.
    expect(find.textContaining('99'), findsNothing);
    expect(repo.callLog.where((e) => e.startsWith('B-')).isNotEmpty, isTrue);
  });

  testWidgets('684px panel: stacked cards (not 3-col)', (tester) async {
    final stats = StudentQuizStatistics.empty(
      LicenseCategoryId.motore,
      topicsTotal: 3,
    );
    // Force hasCatalog dashboard.
    expect(stats.showDashboard, isTrue);

    await tester.pumpWidget(
      _wrap(
        StaffStudentStatisticsPanel(
          studentId: 's1',
          categoryId: LicenseCategoryId.motore,
          repository: _StaticRepo(StaffStudentQuizStatisticsLoaded(stats)),
        ),
        size: const Size(684, 900),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(StudentStatsStudioCard), findsOneWidget);
    expect(find.byType(StudentStatsReviewCard), findsOneWidget);
    // At 684 < 1024, review limit helper is Top3 path.
    expect(
      studentStatsReviewVisibleLimitForWidth(684),
      kStudentStatsTop3Limit,
    );
  });

  testWidgets('refresh increments call', (tester) async {
    final repo = _CountingStaticRepo(
      StaffStudentQuizStatisticsLoaded(
        StudentQuizStatistics.empty(
          LicenseCategoryId.motore,
          topicsTotal: 1,
        ),
      ),
    );
    await tester.pumpWidget(
      _wrap(
        StaffStudentStatisticsPanel(
          studentId: 's1',
          categoryId: LicenseCategoryId.motore,
          repository: repo,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.calls, 1);
    await tester.tap(find.byTooltip('Aggiorna'));
    await tester.pumpAndSettle();
    expect(repo.calls, 2);
  });
}

class _StaticRepo implements StaffStudentQuizStatisticsRepository {
  _StaticRepo(this.result);
  final StaffStudentQuizStatisticsResult result;

  @override
  Future<StaffStudentQuizStatisticsResult> fetchStudentCategoryStatistics({
    required String studentId,
    required LicenseCategoryId categoryId,
  }) async => result;
}

class _CountingStaticRepo implements StaffStudentQuizStatisticsRepository {
  _CountingStaticRepo(this.result);
  final StaffStudentQuizStatisticsResult result;
  int calls = 0;

  @override
  Future<StaffStudentQuizStatisticsResult> fetchStudentCategoryStatistics({
    required String studentId,
    required LicenseCategoryId categoryId,
  }) async {
    calls++;
    return result;
  }
}
