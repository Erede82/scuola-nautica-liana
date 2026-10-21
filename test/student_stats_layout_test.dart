import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/student_stats_layout.dart';

void main() {
  group('studentStatsReviewVisibleLimitForWidth', () {
    test('E. <1366 → max 3', () {
      expect(studentStatsReviewVisibleLimitForWidth(390), 3);
      expect(studentStatsReviewVisibleLimitForWidth(1024), 3);
      expect(studentStatsReviewVisibleLimitForWidth(1365), 3);
    });

    test('F. >=1366 → max 5', () {
      expect(studentStatsReviewVisibleLimitForWidth(1366), 5);
      expect(studentStatsReviewVisibleLimitForWidth(1440), 5);
      expect(studentStatsReviewVisibleLimitForWidth(1920), 5);
    });
  });

  group('splitStudentStatsTopicsForTwoColumns', () {
    test('14 → 7 + 7', () {
      final items = List.generate(14, (i) => i + 1);
      final split = splitStudentStatsTopicsForTwoColumns(items);
      expect(split.left, [1, 2, 3, 4, 5, 6, 7]);
      expect(split.right, [8, 9, 10, 11, 12, 13, 14]);
    });

    test('10 → 5 + 5', () {
      final items = List.generate(10, (i) => i + 1);
      final split = splitStudentStatsTopicsForTwoColumns(items);
      expect(split.left, [1, 2, 3, 4, 5]);
      expect(split.right, [6, 7, 8, 9, 10]);
    });

    test('9 → 5 + 4', () {
      final items = List.generate(9, (i) => i + 1);
      final split = splitStudentStatsTopicsForTwoColumns(items);
      expect(split.left, [1, 2, 3, 4, 5]);
      expect(split.right, [6, 7, 8, 9]);
    });

    test('3 → 2 + 1', () {
      final split = splitStudentStatsTopicsForTwoColumns([1, 2, 3]);
      expect(split.left, [1, 2]);
      expect(split.right, [3]);
    });

    test('1 → 1 + 0', () {
      final split = splitStudentStatsTopicsForTwoColumns([1]);
      expect(split.left, [1]);
      expect(split.right, isEmpty);
    });

    test('0 → empty', () {
      final split = splitStudentStatsTopicsForTwoColumns(<int>[]);
      expect(split.left, isEmpty);
      expect(split.right, isEmpty);
    });

    test('preserves natural order', () {
      final items = [1, 3, 5, 7, 9, 11, 13, 2, 4, 6];
      final split = splitStudentStatsTopicsForTwoColumns(items);
      expect([...split.left, ...split.right], items);
    });
  });
}
