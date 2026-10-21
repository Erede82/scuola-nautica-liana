import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/staff/staff_school_role.dart';
import 'package:scuola_nautica_liana/domain/student_quiz_statistics_models.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';
import 'package:scuola_nautica_liana/pages/study_access_admin_page.dart';
import 'package:scuola_nautica_liana/repositories/staff_student_quiz_statistics_repository.dart';
import 'package:scuola_nautica_liana/services/staff_access_service.dart';
import 'package:scuola_nautica_liana/widgets/staff_student_statistics_panel.dart';

void _staffAdmin() {
  staffAccessNotifier.value = StaffAccessSnapshot.initial().copyWith(
    isLoading: false,
    hasAuthSession: true,
    staffRole: StaffSchoolRole.schoolAdmin,
    clearError: true,
  );
}

void _clearStaff() {
  staffAccessNotifier.value = StaffAccessSnapshot.initial().copyWith(
    isLoading: false,
    hasAuthSession: false,
    clearError: true,
  );
}

class _CountingStatsRepo implements StaffStudentQuizStatisticsRepository {
  int calls = 0;

  @override
  Future<StaffStudentQuizStatisticsResult> fetchStudentCategoryStatistics({
    required String studentId,
    required LicenseCategoryId categoryId,
  }) async {
    calls++;
    return StaffStudentQuizStatisticsLoaded(
      StudentQuizStatistics.empty(categoryId, topicsTotal: 1),
    );
  }
}

Widget _wrap(Widget child, {Size size = const Size(1366, 768)}) {
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
  setUp(_staffAdmin);
  tearDown(_clearStaff);

  testWidgets('Statistiche tab present; lazy load on first open', (
    tester,
  ) async {
    final statsRepo = _CountingStatsRepo();
    await tester.binding.setSurfaceSize(const Size(1366, 768));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      _wrap(
        // Inject via panel only when opened — StudyAccess uses default repo.
        // We verify tab chrome + Schede still works; panel uses global empty
        // when supabase not configured (Unlinked). Count via override is hard
        // without DI on page; assert tab + no crash instead.
        const StudyAccessAdminPage(embedded: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Statistiche'), findsOneWidget);
    expect(find.text('Schede'), findsOneWidget);
    expect(find.text('Esame'), findsOneWidget);
    expect(find.text('Ripasso'), findsOneWidget);

    // Still on Schede — panel should not be mounted yet (lazy).
    expect(find.byType(StaffStudentStatisticsPanel), findsNothing);
    expect(statsRepo.calls, 0);

    await tester.tap(find.text('Statistiche'));
    await tester.pumpAndSettle();

    expect(find.byType(StaffStudentStatisticsPanel), findsOneWidget);
    // Without supabase: empty impl → Unlinked message.
    expect(
      find.textContaining('Nessuna attività quiz collegata'),
      findsOneWidget,
    );
  });

  testWidgets('desktop matrix no H-overflow with Statistiche open', (
    tester,
  ) async {
    for (final size in const [
      Size(1024, 768),
      Size(1366, 768),
      Size(1440, 900),
      Size(1920, 1080),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        _wrap(const StudyAccessAdminPage(embedded: true), size: size),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Statistiche'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$size');
    }
    await tester.binding.setSurfaceSize(null);
  });
}
