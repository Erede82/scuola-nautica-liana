import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/models/quiz_question.dart';
import 'package:scuola_nautica_liana/repositories/student_quiz_repository.dart';

QuizQuestion _q(int n) => QuizQuestion(
  id: 'q$n',
  prompt: 'Prompt $n',
  optionA: 'A$n',
  optionB: 'B$n',
  optionC: 'C$n',
  correctOption: QuizAnswerOption.a,
  lessonNumber: 1,
  licenseCategory: 'A12',
);

List<String> _ids(List<QuizQuestion> questions) =>
    questions.map((q) => q.id).toList();

void main() {
  group('sliceLessonSheetQuestions', () {
    test('sheet 1 returns first limit questions', () {
      final pool = List.generate(25, (i) => _q(i + 1));
      final slice = sliceLessonSheetQuestions(
        pool: pool,
        sheetNumber: 1,
        limit: 20,
      );
      expect(slice.length, 20);
      expect(_ids(slice), _ids(pool.sublist(0, 20)));
    });

    test('sheet 2 returns offset 20', () {
      final pool = List.generate(25, (i) => _q(i + 1));
      final slice = sliceLessonSheetQuestions(
        pool: pool,
        sheetNumber: 2,
        limit: 20,
      );
      expect(slice.length, 20);
      expect(slice.first.id, 'q21');
      expect(slice[4].id, 'q25');
      expect(slice[5].id, 'q1');
      expect(slice.last.id, 'q15');
    });

    test('sheet beyond pool rotates instead of returning empty', () {
      final pool = List.generate(101, (i) => _q(i + 1));

      final sheet5 = sliceLessonSheetQuestions(
        pool: pool,
        sheetNumber: 5,
        limit: 20,
      );
      expect(sheet5.length, 20);
      expect(sheet5.first.id, 'q81');
      expect(sheet5.last.id, 'q100');

      final sheet6 = sliceLessonSheetQuestions(
        pool: pool,
        sheetNumber: 6,
        limit: 20,
      );
      expect(sheet6.length, 20);
      expect(sheet6.first.id, 'q101');
      expect(sheet6[1].id, 'q1');
      expect(sheet6.last.id, 'q19');

      final sheet7 = sliceLessonSheetQuestions(
        pool: pool,
        sheetNumber: 7,
        limit: 20,
      );
      expect(sheet7.length, 20);
      expect(sheet7.first.id, 'q20');
      expect(sheet7.last.id, 'q39');
    });

    test('empty pool returns empty list', () {
      final slice = sliceLessonSheetQuestions(
        pool: const [],
        sheetNumber: 1,
        limit: 20,
      );
      expect(slice, isEmpty);
    });

    test('pool smaller than limit returns all without crash', () {
      final pool = List.generate(10, (i) => _q(i + 1));
      final slice = sliceLessonSheetQuestions(
        pool: pool,
        sheetNumber: 1,
        limit: 20,
      );
      expect(slice.length, 10);
      expect(_ids(slice), _ids(pool));

      final sheet2 = sliceLessonSheetQuestions(
        pool: pool,
        sheetNumber: 2,
        limit: 20,
      );
      expect(sheet2.length, 10);
      expect(sheet2, isNotEmpty);
    });
  });
}
