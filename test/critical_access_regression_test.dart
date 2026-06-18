import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/constants/extra_content_ids.dart';
import 'package:scuola_nautica_liana/domain/backoffice/backoffice.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';
import 'package:scuola_nautica_liana/repositories/backoffice/management_repository_mock.dart';
import 'package:scuola_nautica_liana/repositories/study_access_repository.dart';

void main() {
  group('Extra video access grants', () {
    test('revoking bundle also revokes included courses', () async {
      final repo = ManagementRepositoryMock();

      await repo.grantStudentExtraProductAccess(
        studentId: 'student-1',
        productId: ExtraContentIds.extraPacchetto,
      );

      expect(
        await repo.listPurchasedExtraProductIds('student-1'),
        containsAll(<String>{
          ExtraContentIds.extraPacchetto,
          ExtraContentIds.extraTeoria,
          ExtraContentIds.extraCarteggio,
          ExtraContentIds.extraGuida,
        }),
      );

      await repo.revokeStudentExtraProductAccess(
        studentId: 'student-1',
        productId: ExtraContentIds.extraPacchetto,
      );

      expect(await repo.listPurchasedExtraProductIds('student-1'), isEmpty);
    });
  });

  group('Study access hydration', () {
    test('empty remote state disables local demo unlocks', () {
      final repo = MutableMockStudyAccessRepository();

      expect(
        repo
            .lessonQuizSheet(
              categoryId: LicenseCategoryId.motore,
              lessonNumber: 1,
              sheetNumber: 1,
            )
            .isUnlocked,
        isTrue,
      );

      repo.hydrateFromRemoteStudyProgress(
        const StudentStudyProgressBundle(
          studentId: 'student-1',
          assignedLessons: [],
          sheetUnlocks: [],
          examAccessByCategory: [],
          errorReviewAssignments: [],
        ),
      );

      expect(
        repo
            .lessonQuizSheet(
              categoryId: LicenseCategoryId.motore,
              lessonNumber: 1,
              sheetNumber: 1,
            )
            .isUnlocked,
        isFalse,
      );
      expect(
        repo
            .errorReviewTopic(
              categoryId: LicenseCategoryId.motore,
              lessonNumber: 1,
            )
            .isUnlocked,
        isFalse,
      );
    });

    test('remote unlock rows still grant access', () {
      final repo = MutableMockStudyAccessRepository();

      repo.hydrateFromRemoteStudyProgress(
        const StudentStudyProgressBundle(
          studentId: 'student-1',
          assignedLessons: [],
          sheetUnlocks: [
            LessonQuizSheetUnlock(
              studentId: 'student-1',
              categoryId: LicenseCategoryId.motore,
              lessonNumber: 1,
              sheetNumber: 1,
              unlocked: true,
            ),
          ],
          examAccessByCategory: [],
          errorReviewAssignments: [
            ErrorReviewTopicAssignment(
              studentId: 'student-1',
              categoryId: LicenseCategoryId.motore,
              lessonNumber: 1,
              topicUnlocked: true,
            ),
          ],
        ),
      );

      expect(
        repo
            .lessonQuizSheet(
              categoryId: LicenseCategoryId.motore,
              lessonNumber: 1,
              sheetNumber: 1,
            )
            .isUnlocked,
        isTrue,
      );
      expect(
        repo
            .errorReviewTopic(
              categoryId: LicenseCategoryId.motore,
              lessonNumber: 1,
            )
            .isUnlocked,
        isTrue,
      );
    });
  });
}
