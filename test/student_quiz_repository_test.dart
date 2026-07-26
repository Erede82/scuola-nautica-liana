import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/models/lesson_quiz_sheet_content.dart';
import 'package:scuola_nautica_liana/models/lesson_sheet_completion_snapshot.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';
import 'package:scuola_nautica_liana/models/quiz_question.dart';
import 'package:scuola_nautica_liana/repositories/student_quiz_repository.dart';

QuizQuestion _q(int n, {String licenseCategory = 'A12'}) => QuizQuestion(
  id: 'q$n',
  prompt: 'Prompt $n',
  optionA: 'A$n',
  optionB: 'B$n',
  optionC: 'C$n',
  correctOption: QuizAnswerOption.a,
  lessonNumber: 1,
  licenseCategory: licenseCategory,
);

List<String> _ids(List<QuizQuestion> questions) =>
    questions.map((q) => q.id).toList();

/// Fake che espone content + la stessa logica limit del repository reale.
class _ContentFake implements StudentQuizRepository {
  _ContentFake(this.content);

  final LessonQuizSheetContent? content;

  @override
  Future<LessonQuizSheetContent?> fetchLessonSheetContent({
    required LicenseCategoryId categoryId,
    required int lessonNumber,
    required int sheetNumber,
  }) async => content;

  @override
  Future<List<QuizQuestion>> fetchLessonSheetQuestions({
    required LicenseCategoryId categoryId,
    required int lessonNumber,
    required int sheetNumber,
    int? limit,
  }) async {
    final loaded = content?.questions ?? const <QuizQuestion>[];
    return applyOptionalLessonSheetQuestionLimit(loaded, limit: limit);
  }

  @override
  Future<LessonSheetCompletionSnapshot> fetchLessonSheetCompletion({
    required LicenseCategoryId categoryId,
    required int lessonNumber,
  }) async => LessonSheetCompletionSnapshot.empty;

  @override
  Future<Map<String, List<QuizQuestion>>> fetchExamQuestionsByTopic({
    required LicenseCategoryId categoryId,
  }) async => {};
}

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

    test('A12 limit 20 e D1 limit 15 espliciti, pool non mutato', () {
      final pool = List.generate(40, (i) => _q(i + 1));
      final originalIds = _ids(pool);

      final a12 = sliceLessonSheetQuestionIndices(
        poolLength: pool.length,
        sheetNumber: 1,
        limit: 20,
      );
      final d1 = sliceLessonSheetQuestionIndices(
        poolLength: pool.length,
        sheetNumber: 1,
        limit: 15,
      );

      expect(a12.length, 20);
      expect(d1.length, 15);
      expect(a12.toSet(), hasLength(20));
      expect(d1.toSet(), hasLength(15));
      expect(_ids(pool), originalIds);

      final a12Sheet2 = sliceLessonSheetQuestionIndices(
        poolLength: pool.length,
        sheetNumber: 2,
        limit: 20,
      );
      expect(a12Sheet2.first, 20);

      final d1Sheet2 = sliceLessonSheetQuestionIndices(
        poolLength: pool.length,
        sheetNumber: 2,
        limit: 15,
      );
      expect(d1Sheet2.first, 15);
      expect(d1Sheet2.last, 29);
    });

    test('D1 limit 15 esplicito resta deterministico', () {
      final pool = List.generate(30, (i) => _q(i + 1));
      final slice = sliceLessonSheetQuestions(
        pool: pool,
        sheetNumber: 1,
        limit: 15,
      );
      expect(slice.length, 15);
      expect(_ids(slice), _ids(pool.sublist(0, 15)));
    });
  });

  group('fetchLessonSheetQuestions legacy (no auto-truncate)', () {
    test('senza limit: set D1 remoto 20 item → 20 item', () async {
      final questions = List.generate(
        20,
        (i) => _q(i + 1, licenseCategory: 'D1'),
      );
      final repo = _ContentFake(
        LessonQuizSheetContent(
          quizSetId: 'set-d1-20',
          categoryId: LicenseCategoryId.d1,
          lessonNumber: 1,
          sheetNumber: 1,
          questions: questions,
        ),
      );

      final loaded = await repo.fetchLessonSheetQuestions(
        categoryId: LicenseCategoryId.d1,
        lessonNumber: 1,
        sheetNumber: 1,
      );

      expect(loaded, hasLength(20));
      expect(_ids(loaded), _ids(questions));
    });

    test('limit esplicito 15 → 15 item', () async {
      final questions = List.generate(
        20,
        (i) => _q(i + 1, licenseCategory: 'D1'),
      );
      final repo = _ContentFake(
        LessonQuizSheetContent(
          quizSetId: 'set-d1-20',
          categoryId: LicenseCategoryId.d1,
          lessonNumber: 1,
          sheetNumber: 1,
          questions: questions,
        ),
      );

      final loaded = await repo.fetchLessonSheetQuestions(
        categoryId: LicenseCategoryId.d1,
        lessonNumber: 1,
        sheetNumber: 1,
        limit: 15,
      );

      expect(loaded, hasLength(15));
      expect(_ids(loaded), _ids(questions.take(15).toList()));
    });

    test(
      'fetchLessonSheetContent restituisce tutti gli item del set',
      () async {
        final questions = List.generate(
          20,
          (i) => _q(i + 1, licenseCategory: 'D1'),
        );
        final repo = _ContentFake(
          LessonQuizSheetContent(
            quizSetId: 'set-d1-20',
            categoryId: LicenseCategoryId.d1,
            lessonNumber: 1,
            sheetNumber: 1,
            questions: questions,
          ),
        );

        final content = await repo.fetchLessonSheetContent(
          categoryId: LicenseCategoryId.d1,
          lessonNumber: 1,
          sheetNumber: 1,
        );

        expect(content?.questions, hasLength(20));
      },
    );

    test(
      'applyOptionalLessonSheetQuestionLimit: null → nessuna truncatura',
      () {
        final questions = List.generate(20, (i) => _q(i + 1));
        expect(applyOptionalLessonSheetQuestionLimit(questions), hasLength(20));
        expect(
          applyOptionalLessonSheetQuestionLimit(questions, limit: 15),
          hasLength(15),
        );
      },
    );
  });
}
