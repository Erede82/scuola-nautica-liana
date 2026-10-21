import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/data/supabase/dto/quiz_sheet_catalog_row.dart';
import 'package:scuola_nautica_liana/data/supabase/dto/staff_student_quiz_statistics_rpc_payload.dart';
import 'package:scuola_nautica_liana/data/supabase/staff_student_quiz_statistics_data_source.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';
import 'package:scuola_nautica_liana/repositories/staff_student_quiz_statistics_repository.dart';
import 'package:scuola_nautica_liana/repositories/student_quiz_statistics_repository.dart';

class _FakeStaffDs implements StaffStudentQuizStatisticsDataSource {
  _FakeStaffDs(this.payload);

  StaffStudentQuizStatisticsRpcPayload payload;
  int calls = 0;
  String? lastStudentId;
  String? lastCategory;

  @override
  Future<StaffStudentQuizStatisticsRpcPayload> fetchInputs({
    required String studentId,
    required String licenseCategoryDb,
  }) async {
    calls++;
    lastStudentId = studentId;
    lastCategory = licenseCategoryDb;
    return payload;
  }
}

void main() {
  group('StaffStudentQuizStatisticsRepository', () {
    test('RPC params: p_student_id + p_license_category (via DS)', () async {
      final ds = _FakeStaffDs(
        const StaffStudentQuizStatisticsRpcPayload(
          linkedUser: true,
          category: 'A12',
          lessonAttempts: [],
          lessonAnswerCounts: {},
          multiAttempts: [],
          multiAnswerEvents: [],
          examAttempts: [],
          examAnswerEvents: [],
          lessonCatalog: [
            QuizSheetCatalogRow(
              id: 'c1',
              kind: 'lesson',
              licenseCategory: 'A12',
              lessonNumber: 1,
              sheetNumber: 1,
            ),
          ],
        ),
      );
      final repo = StaffStudentQuizStatisticsRepositoryImpl(dataSource: ds);
      final result = await repo.fetchStudentCategoryStatistics(
        studentId: 'stu-001',
        categoryId: LicenseCategoryId.motore,
      );
      expect(ds.calls, 1);
      expect(ds.lastStudentId, 'stu-001');
      expect(ds.lastCategory, 'A12');
      expect(result, isA<StaffStudentQuizStatisticsLoaded>());
    });

    test('linked_user=false → Unlinked (no fake zeros dashboard)', () async {
      final ds = _FakeStaffDs(
        const StaffStudentQuizStatisticsRpcPayload(
          linkedUser: false,
          category: 'A12',
          lessonAttempts: [],
          lessonAnswerCounts: {},
          multiAttempts: [],
          multiAnswerEvents: [],
          examAttempts: [],
          examAnswerEvents: [],
          lessonCatalog: [],
        ),
      );
      final repo = StaffStudentQuizStatisticsRepositoryImpl(dataSource: ds);
      final result = await repo.fetchStudentCategoryStatistics(
        studentId: 'stu-001',
        categoryId: LicenseCategoryId.motore,
      );
      expect(result, isA<StaffStudentQuizStatisticsUnlinked>());
    });

    test('linked_user=true empty history → Loaded empty-capable', () async {
      final ds = _FakeStaffDs(
        const StaffStudentQuizStatisticsRpcPayload(
          linkedUser: true,
          category: 'D1',
          lessonAttempts: [],
          lessonAnswerCounts: {},
          multiAttempts: [],
          multiAnswerEvents: [],
          examAttempts: [],
          examAnswerEvents: [],
          lessonCatalog: [
            QuizSheetCatalogRow(
              id: 'd1-1',
              kind: 'lesson',
              licenseCategory: 'D1',
              lessonNumber: 1,
              sheetNumber: 1,
            ),
          ],
        ),
      );
      final repo = StaffStudentQuizStatisticsRepositoryImpl(dataSource: ds);
      final result = await repo.fetchStudentCategoryStatistics(
        studentId: 'stu-001',
        categoryId: LicenseCategoryId.d1,
      );
      expect(result, isA<StaffStudentQuizStatisticsLoaded>());
      final loaded = result as StaffStudentQuizStatisticsLoaded;
      expect(loaded.statistics.hasAnyActivity, isFalse);
      expect(loaded.statistics.hasCatalog, isTrue);
      expect(ds.lastCategory, 'D1');
    });

    test('unsupported category → no RPC call', () async {
      final ds = _FakeStaffDs(
        const StaffStudentQuizStatisticsRpcPayload(
          linkedUser: true,
          category: 'A12',
          lessonAttempts: [],
          lessonAnswerCounts: {},
          multiAttempts: [],
          multiAnswerEvents: [],
          examAttempts: [],
          examAnswerEvents: [],
          lessonCatalog: [],
        ),
      );
      final repo = StaffStudentQuizStatisticsRepositoryImpl(dataSource: ds);
      final result = await repo.fetchStudentCategoryStatistics(
        studentId: 'stu-001',
        categoryId: LicenseCategoryId.vela,
      );
      expect(result, isA<StaffStudentQuizStatisticsUnsupportedCategory>());
      expect(ds.calls, 0);
    });
  });

  test('SECURITY: self repository API has no arbitrary userId parameter', () {
    // Compile-time contract: fetchCategoryStatistics only takes categoryId.
    const empty = StudentQuizStatisticsRepositoryEmpty();
    expect(
      empty.fetchCategoryStatistics(categoryId: LicenseCategoryId.motore),
      completes,
    );
    // Source-level guard: impl must still resolve auth.currentUser itself.
    // (See StudentQuizStatisticsRepositoryImpl._resolveUserId default.)
  });
}
