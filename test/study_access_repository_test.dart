import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';
import 'package:scuola_nautica_liana/repositories/study_access_repository.dart';

void main() {
  group('MutableMockStudyAccessRepository', () {
    test('keeps demo lesson seed available for unconfigured local builds', () {
      final repo = MutableMockStudyAccessRepository(allowDemoSeedAccess: true);

      final access = repo.lessonQuizSheet(
        categoryId: LicenseCategoryId.motore,
        lessonNumber: 1,
        sheetNumber: 1,
      );

      expect(access.isUnlocked, isTrue);
    });

    test('locks lessons without explicit school grants in remote builds', () {
      final repo = MutableMockStudyAccessRepository(allowDemoSeedAccess: false);

      final access = repo.lessonQuizSheet(
        categoryId: LicenseCategoryId.motore,
        lessonNumber: 1,
        sheetNumber: 1,
      );

      expect(access.isUnlocked, isFalse);

      repo.applyLessonQuizSheetUnlock(
        categoryId: LicenseCategoryId.motore,
        lessonNumber: 1,
        sheetNumber: 1,
        unlocked: true,
      );

      final grantedAccess = repo.lessonQuizSheet(
        categoryId: LicenseCategoryId.motore,
        lessonNumber: 1,
        sheetNumber: 1,
      );

      expect(grantedAccess.isUnlocked, isTrue);
    });

    test('locks error-review topics without explicit school grants remotely', () {
      final repo = MutableMockStudyAccessRepository(allowDemoSeedAccess: false);

      final access = repo.errorReviewTopic(
        categoryId: LicenseCategoryId.motore,
        lessonNumber: 1,
      );

      expect(access.isUnlocked, isFalse);

      repo.applyErrorReviewTopicUnlock(
        categoryId: LicenseCategoryId.motore,
        lessonNumber: 1,
        unlocked: true,
      );

      final grantedAccess = repo.errorReviewTopic(
        categoryId: LicenseCategoryId.motore,
        lessonNumber: 1,
      );

      expect(grantedAccess.isUnlocked, isTrue);
    });
  });
}
