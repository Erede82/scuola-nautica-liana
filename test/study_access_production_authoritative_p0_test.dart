import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/backoffice/backoffice.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';
import 'package:scuola_nautica_liana/repositories/study_access_repository.dart';

/// APP-READY.P0 — in produzione (Supabase configurato) il DB è authoritative:
/// assenza grant → locked; seed demo solo in locale.
void main() {
  const studentId = 'student-p0-test';
  const category = LicenseCategoryId.motore;
  const lessonNumber = 1;
  const sheetNumber = 1;
  const errorLesson = 3;

  late MutableMockStudyAccessRepository repo;

  setUp(() {
    MutableMockStudyAccessRepository.debugAllowDemoAccessSeedOverride = null;
    repo = studyAccessWritableRepository as MutableMockStudyAccessRepository;
    repo.resetDemoAssignments();
  });

  tearDown(() {
    MutableMockStudyAccessRepository.debugAllowDemoAccessSeedOverride = null;
    repo.resetDemoAssignments();
  });

  void forceProductionMode() {
    MutableMockStudyAccessRepository.debugAllowDemoAccessSeedOverride = false;
  }

  void forceDemoMode() {
    MutableMockStudyAccessRepository.debugAllowDemoAccessSeedOverride = true;
  }

  group('production (Supabase configured / DB authoritative)', () {
    setUp(forceProductionMode);

    test('1. no unlock → lesson locked', () {
      expect(
        repo
            .lessonQuizSheet(
              categoryId: category,
              lessonNumber: lessonNumber,
              sheetNumber: sheetNumber,
            )
            .isUnlocked,
        isFalse,
      );
    });

    test('2. unlock true → lesson unlocked', () {
      repo.applyLessonQuizSheetUnlock(
        categoryId: category,
        lessonNumber: lessonNumber,
        sheetNumber: sheetNumber,
        unlocked: true,
      );
      expect(
        repo
            .lessonQuizSheet(
              categoryId: category,
              lessonNumber: lessonNumber,
              sheetNumber: sheetNumber,
            )
            .isUnlocked,
        isTrue,
      );
    });

    test('3. unlock false → lesson locked', () {
      repo.applyLessonQuizSheetUnlock(
        categoryId: category,
        lessonNumber: lessonNumber,
        sheetNumber: sheetNumber,
        unlocked: false,
      );
      expect(
        repo
            .lessonQuizSheet(
              categoryId: category,
              lessonNumber: lessonNumber,
              sheetNumber: sheetNumber,
            )
            .isUnlocked,
        isFalse,
      );
    });

    test('4. no error-review grant → ripasso locked', () {
      expect(
        repo
            .errorReviewTopic(
              categoryId: category,
              lessonNumber: errorLesson,
            )
            .isUnlocked,
        isFalse,
      );
    });

    test('5. ripasso true → unlocked', () {
      repo.applyErrorReviewTopicUnlock(
        categoryId: category,
        lessonNumber: errorLesson,
        unlocked: true,
      );
      expect(
        repo
            .errorReviewTopic(
              categoryId: category,
              lessonNumber: errorLesson,
            )
            .isUnlocked,
        isTrue,
      );
    });

    test('6. ripasso false → locked', () {
      repo.applyErrorReviewTopicUnlock(
        categoryId: category,
        lessonNumber: errorLesson,
        unlocked: false,
      );
      expect(
        repo
            .errorReviewTopic(
              categoryId: category,
              lessonNumber: errorLesson,
            )
            .isUnlocked,
        isFalse,
      );
    });

    test('7. no exam access → exam locked', () {
      expect(repo.examQuiz(category).isUnlocked, isFalse);
    });

    test('8. revoke (hydrate empty after grant) → locked', () {
      repo.hydrateFromRemoteStudyProgress(
        StudentStudyProgressBundle(
          studentId: studentId,
          assignedLessons: const [],
          sheetUnlocks: [
            LessonQuizSheetUnlock(
              studentId: studentId,
              categoryId: category,
              lessonNumber: lessonNumber,
              sheetNumber: sheetNumber,
              unlocked: true,
            ),
          ],
          examAccessByCategory: [
            ExamQuizAccess(
              studentId: studentId,
              categoryId: category,
              examUnlocked: true,
            ),
          ],
          errorReviewAssignments: [
            ErrorReviewTopicAssignment(
              studentId: studentId,
              categoryId: category,
              lessonNumber: errorLesson,
              topicUnlocked: true,
            ),
          ],
        ),
      );
      expect(
        repo
            .lessonQuizSheet(
              categoryId: category,
              lessonNumber: lessonNumber,
              sheetNumber: sheetNumber,
            )
            .isUnlocked,
        isTrue,
      );
      expect(repo.examQuiz(category).isUnlocked, isTrue);
      expect(
        repo
            .errorReviewTopic(
              categoryId: category,
              lessonNumber: errorLesson,
            )
            .isUnlocked,
        isTrue,
      );

      // Revoke: sync empty DB rows
      repo.hydrateFromRemoteStudyProgress(
        const StudentStudyProgressBundle(
          studentId: studentId,
          assignedLessons: [],
          sheetUnlocks: [],
          examAccessByCategory: [],
          errorReviewAssignments: [],
        ),
      );

      expect(
        repo
            .lessonQuizSheet(
              categoryId: category,
              lessonNumber: lessonNumber,
              sheetNumber: sheetNumber,
            )
            .isUnlocked,
        isFalse,
      );
      expect(repo.examQuiz(category).isUnlocked, isFalse);
      expect(
        repo
            .errorReviewTopic(
              categoryId: category,
              lessonNumber: errorLesson,
            )
            .isUnlocked,
        isFalse,
      );
    });

    test('10. no production fallback lessonNumber != 7 style', () {
      // Without grant, every theory lesson topic stays locked (incl. != 7).
      for (final n in [1, 2, 3, 4, 5, 6, 7, 8]) {
        expect(
          repo
              .errorReviewTopic(categoryId: category, lessonNumber: n)
              .isUnlocked,
          isFalse,
          reason: 'error review L$n must be locked without grant in production',
        );
      }
      // Early catalog lessons must not auto-unlock via ~35% demo seed.
      for (final n in [1, 2, 3, 4]) {
        expect(
          repo
              .lessonQuizSheet(
                categoryId: category,
                lessonNumber: n,
                sheetNumber: 1,
              )
              .isUnlocked,
          isFalse,
          reason: 'lesson L$n must be locked without grant in production',
        );
      }
    });
  });

  group('demo / local (Supabase not configured)', () {
    setUp(forceDemoMode);

    test('9. demo fallback still unlocks early lessons', () {
      expect(
        repo
            .lessonQuizSheet(
              categoryId: category,
              lessonNumber: 1,
              sheetNumber: 1,
            )
            .isUnlocked,
        isTrue,
      );
    });

    test('9b. demo error-review unlocks non-L7 topics', () {
      expect(
        repo
            .errorReviewTopic(categoryId: category, lessonNumber: 3)
            .isUnlocked,
        isTrue,
      );
      expect(
        repo
            .errorReviewTopic(categoryId: category, lessonNumber: 7)
            .isUnlocked,
        isFalse,
      );
    });

    test('9c. demo exam stays locked (kDemoUnlockEntireExamForTheory=false)', () {
      expect(repo.examQuiz(category).isUnlocked, isFalse);
    });
  });
}
