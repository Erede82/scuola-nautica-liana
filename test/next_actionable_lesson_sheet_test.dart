import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/lesson_sheet_catalog_filter.dart';

void main() {
  const catalog1to6 = [1, 2, 3, 4, 5, 6];

  group('nextActionableLessonSheetNumber', () {
    test('A. catalog 1..6 unlock 1..4 current 4 → no next CTA', () {
      final next = nextActionableLessonSheetNumber(
        catalogSheetNumbers: catalog1to6,
        currentSheetNumber: 4,
        isSheetUnlocked: (sheet) => sheet <= 4,
      );
      expect(next, isNull);
      expect(
        actionableLessonSheetNumbers(
          catalogSheetNumbers: catalog1to6,
          isSheetUnlocked: (sheet) => sheet <= 4,
        ),
        [1, 2, 3, 4],
      );
    });

    test('B. unlock {1,2,4,6} current 2 → next = 4 (not 3)', () {
      final unlocked = {1, 2, 4, 6};
      expect(
        nextActionableLessonSheetNumber(
          catalogSheetNumbers: catalog1to6,
          currentSheetNumber: 2,
          isSheetUnlocked: unlocked.contains,
        ),
        4,
      );
    });

    test('C. unlock {1,2,4,6} current 4 → next = 6', () {
      final unlocked = {1, 2, 4, 6};
      expect(
        nextActionableLessonSheetNumber(
          catalogSheetNumbers: catalog1to6,
          currentSheetNumber: 4,
          isSheetUnlocked: unlocked.contains,
        ),
        6,
      );
    });

    test('D. current last actionable → no next', () {
      final unlocked = {1, 2, 4, 6};
      expect(
        nextActionableLessonSheetNumber(
          catalogSheetNumbers: catalog1to6,
          currentSheetNumber: 6,
          isSheetUnlocked: unlocked.contains,
        ),
        isNull,
      );
    });

    test('E. locked intermediate sheet is skipped', () {
      final unlocked = {1, 2, 4, 6};
      expect(
        nextActionableLessonSheetNumber(
          catalogSheetNumbers: catalog1to6,
          currentSheetNumber: 2,
          isSheetUnlocked: unlocked.contains,
        ),
        4,
      );
      expect(
        nextActionableLessonSheetNumber(
          catalogSheetNumbers: catalog1to6,
          currentSheetNumber: 1,
          isSheetUnlocked: unlocked.contains,
        ),
        2,
      );
    });

    test('F. duplicate sheet catalog has no effect', () {
      final unlocked = {1, 2, 4, 6};
      expect(
        nextActionableLessonSheetNumber(
          catalogSheetNumbers: const [1, 2, 2, 3, 4, 4, 5, 6, 6],
          currentSheetNumber: 2,
          isSheetUnlocked: unlocked.contains,
        ),
        4,
      );
      expect(
        actionableLessonSheetNumbers(
          catalogSheetNumbers: const [1, 2, 2, 3, 4, 4, 5, 6, 6],
          isSheetUnlocked: unlocked.contains,
        ),
        [1, 2, 4, 6],
      );
    });

    test('G. no unlock → no actionable / no next', () {
      expect(
        actionableLessonSheetNumbers(
          catalogSheetNumbers: catalog1to6,
          isSheetUnlocked: (_) => false,
        ),
        isEmpty,
      );
      expect(
        nextActionableLessonSheetNumber(
          catalogSheetNumbers: catalog1to6,
          currentSheetNumber: 1,
          isSheetUnlocked: (_) => false,
        ),
        isNull,
      );
    });

    test('H. fully unlocked sequence → 1→2→3 normal', () {
      bool unlocked(int sheet) => sheet >= 1 && sheet <= 6;
      expect(
        nextActionableLessonSheetNumber(
          catalogSheetNumbers: catalog1to6,
          currentSheetNumber: 1,
          isSheetUnlocked: unlocked,
        ),
        2,
      );
      expect(
        nextActionableLessonSheetNumber(
          catalogSheetNumbers: catalog1to6,
          currentSheetNumber: 2,
          isSheetUnlocked: unlocked,
        ),
        3,
      );
      expect(
        nextActionableLessonSheetNumber(
          catalogSheetNumbers: catalog1to6,
          currentSheetNumber: 5,
          isSheetUnlocked: unlocked,
        ),
        6,
      );
      expect(
        nextActionableLessonSheetNumber(
          catalogSheetNumbers: catalog1to6,
          currentSheetNumber: 6,
          isSheetUnlocked: unlocked,
        ),
        isNull,
      );
    });
  });
}
