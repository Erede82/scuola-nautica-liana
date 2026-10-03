import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/multi_topic_quiz_history_models.dart';
import 'package:scuola_nautica_liana/domain/multi_topic_remaining_sheets.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';

MultiTopicQuizAttemptSummary _attempt({
  required String id,
  required String sessionId,
  required List<int> lessons,
  required int sheetIndex,
  LicenseCategoryId category = LicenseCategoryId.motore,
}) {
  return MultiTopicQuizAttemptSummary(
    id: id,
    sessionId: sessionId,
    licenseCategory: category,
    lessonNumbers: lessons,
    sheetIndex: sheetIndex,
    totalSheets: 10,
    completedAt: DateTime.utc(2026, 10, 3),
    durationSeconds: 60,
    totalQuestions: 20,
    correctCount: 10,
    wrongCount: 10,
    unansweredCount: 0,
  );
}

void main() {
  group('multi_topic remaining sheets', () {
    test('A. catalog 45 completed 0 → remaining 45', () {
      expect(
        remainingMultiTopicSheets(
          catalogActionableTotal: 45,
          completedRelevantCount: 0,
        ),
        45,
      );
    });

    test('B. catalog 45 completed 3 → remaining 42', () {
      expect(
        remainingMultiTopicSheets(
          catalogActionableTotal: 45,
          completedRelevantCount: 3,
        ),
        42,
      );
    });

    test('C. catalog 50 completed 3 → remaining 47', () {
      expect(
        remainingMultiTopicSheets(
          catalogActionableTotal: 50,
          completedRelevantCount: 3,
        ),
        47,
      );
    });

    test('D. duplicate session/sheet retry counted once', () {
      final attempts = [
        _attempt(
          id: 'a1',
          sessionId: 's1',
          lessons: const [2, 4],
          sheetIndex: 1,
        ),
        _attempt(
          id: 'a1-retry',
          sessionId: 's1',
          lessons: const [2, 4],
          sheetIndex: 1,
        ),
        _attempt(
          id: 'a2',
          sessionId: 's1',
          lessons: const [2, 4],
          sheetIndex: 2,
        ),
      ];
      expect(
        countCompletedRelevantMultiTopicSheets(
          attempts: attempts,
          currentLicenseCategory: LicenseCategoryId.motore,
          selectedLessonNumbers: const [2, 4],
        ),
        2,
      );
    });

    test('E. empty lesson_numbers not counted', () {
      final attempts = [
        _attempt(id: 'empty', sessionId: 's', lessons: const [], sheetIndex: 1),
      ];
      expect(
        countCompletedRelevantMultiTopicSheets(
          attempts: attempts,
          currentLicenseCategory: LicenseCategoryId.motore,
          selectedLessonNumbers: const [2, 4],
        ),
        0,
      );
    });

    test('F. mixed {2,4} relevant to {2,4,6}', () {
      final attempts = [
        _attempt(
          id: 'm1',
          sessionId: 's',
          lessons: const [2, 4],
          sheetIndex: 1,
        ),
        _attempt(
          id: 'm2',
          sessionId: 's',
          lessons: const [2, 4],
          sheetIndex: 2,
        ),
        _attempt(
          id: 'm3',
          sessionId: 's',
          lessons: const [2, 4],
          sheetIndex: 3,
        ),
      ];
      expect(
        countCompletedRelevantMultiTopicSheets(
          attempts: attempts,
          currentLicenseCategory: LicenseCategoryId.motore,
          selectedLessonNumbers: const [2, 4, 6],
        ),
        3,
      );
      expect(
        remainingMultiTopicSheets(
          catalogActionableTotal: 50,
          completedRelevantCount: 3,
        ),
        47,
      );
    });

    test('G. mixed {2,4} NOT relevant to {2} only', () {
      final attempts = [
        _attempt(
          id: 'm1',
          sessionId: 's',
          lessons: const [2, 4],
          sheetIndex: 1,
        ),
      ];
      expect(
        isMultiTopicAttemptRelevantToSelection(
          attemptLicenseCategory: LicenseCategoryId.motore,
          currentLicenseCategory: LicenseCategoryId.motore,
          attemptLessonNumbers: const [2, 4],
          selectedLessonNumbers: const [2],
        ),
        isFalse,
      );
      expect(
        countCompletedRelevantMultiTopicSheets(
          attempts: attempts,
          currentLicenseCategory: LicenseCategoryId.motore,
          selectedLessonNumbers: const [2],
        ),
        0,
      );
    });

    test('H. remaining 0 clamps', () {
      expect(
        remainingMultiTopicSheets(
          catalogActionableTotal: 3,
          completedRelevantCount: 10,
        ),
        0,
      );
    });

    test('I. A12 attempt relevant to A12 selection', () {
      expect(
        isMultiTopicAttemptRelevantToSelection(
          attemptLicenseCategory: LicenseCategoryId.motore,
          currentLicenseCategory: LicenseCategoryId.motore,
          attemptLessonNumbers: const [2, 4],
          selectedLessonNumbers: const [2, 4, 6],
        ),
        isTrue,
      );
    });

    test('J. A12 attempt NOT relevant to D1 selection', () {
      expect(
        isMultiTopicAttemptRelevantToSelection(
          attemptLicenseCategory: LicenseCategoryId.motore,
          currentLicenseCategory: LicenseCategoryId.d1,
          attemptLessonNumbers: const [2, 4],
          selectedLessonNumbers: const [2, 4, 6],
        ),
        isFalse,
      );
      expect(
        countCompletedRelevantMultiTopicSheets(
          attempts: [
            _attempt(
              id: 'a12',
              sessionId: 's',
              lessons: const [2, 4],
              sheetIndex: 1,
              category: LicenseCategoryId.motore,
            ),
          ],
          currentLicenseCategory: LicenseCategoryId.d1,
          selectedLessonNumbers: const [2, 4, 6],
        ),
        0,
      );
    });

    test('K. D1 attempt does not subtract from A12', () {
      final attempts = [
        _attempt(
          id: 'd1',
          sessionId: 's',
          lessons: const [2, 4],
          sheetIndex: 1,
          category: LicenseCategoryId.d1,
        ),
        _attempt(
          id: 'a12',
          sessionId: 's2',
          lessons: const [2, 4],
          sheetIndex: 1,
          category: LicenseCategoryId.motore,
        ),
      ];
      expect(
        countCompletedRelevantMultiTopicSheets(
          attempts: attempts,
          currentLicenseCategory: LicenseCategoryId.motore,
          selectedLessonNumbers: const [2, 4],
        ),
        1,
      );
    });
  });
}
