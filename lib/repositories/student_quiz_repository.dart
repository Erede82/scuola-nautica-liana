import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../data/quiz_question_mapper.dart';
import '../data/supabase/dto/question_row.dart';
import '../models/lesson_quiz_sheet_content.dart';
import '../models/license_models.dart';
import '../models/quiz_question.dart';

export '../domain/quiz_sheet_slicing.dart';

/// Lettura domande quiz per area studente (`quiz_sets` + `quiz_set_items`).
abstract class StudentQuizRepository {
  Future<LessonQuizSheetContent?> fetchLessonSheetContent({
    required LicenseCategoryId categoryId,
    required int lessonNumber,
    required int sheetNumber,
  });

  Future<List<QuizQuestion>> fetchLessonSheetQuestions({
    required LicenseCategoryId categoryId,
    required int lessonNumber,
    required int sheetNumber,
    int limit = 20,
  });
}

class StudentQuizRepositorySupabase implements StudentQuizRepository {
  StudentQuizRepositorySupabase._();

  static final StudentQuizRepositorySupabase instance =
      StudentQuizRepositorySupabase._();

  SupabaseClient get _client {
    if (!SupabaseConfig.isConfigured) {
      throw StateError('Supabase non inizializzato.');
    }
    return Supabase.instance.client;
  }

  static const _questionSelectColumns =
      'id, prompt, option_a, option_b, option_c, correct_option, '
      'lesson_number, license_category, exam_topic_code, source_topic_text, '
      'image_path, explanation';

  static const _sheetSelect =
      'id, license_category, lesson_number, sheet_number, '
      'quiz_set_items(position, questions($_questionSelectColumns))';

  @override
  Future<LessonQuizSheetContent?> fetchLessonSheetContent({
    required LicenseCategoryId categoryId,
    required int lessonNumber,
    required int sheetNumber,
  }) async {
    final dbCategory = _dbLicenseCategory(categoryId);
    if (dbCategory == null) return null;

    final res = await _client
        .from('quiz_sets')
        .select(_sheetSelect)
        .eq('kind', 'lesson')
        .eq('license_category', dbCategory)
        .eq('lesson_number', lessonNumber)
        .eq('sheet_number', sheetNumber)
        .maybeSingle();

    if (res == null) return null;

    final map = Map<String, dynamic>.from(res as Map);
    final quizSetId = map['id']?.toString();
    if (quizSetId == null || quizSetId.isEmpty) return null;

    final rawItems = map['quiz_set_items'];
    if (rawItems is! List || rawItems.isEmpty) {
      return LessonQuizSheetContent(
        quizSetId: quizSetId,
        categoryId: categoryId,
        lessonNumber: lessonNumber,
        sheetNumber: sheetNumber,
        questions: const [],
      );
    }

    final sortedItems =
        List<Map<String, dynamic>>.from(
          rawItems.map((e) => Map<String, dynamic>.from(e as Map)),
        )..sort(
          (a, b) => ((a['position'] as num?)?.toInt() ?? 0).compareTo(
            (b['position'] as num?)?.toInt() ?? 0,
          ),
        );

    final questions = <QuizQuestion>[];
    for (final item in sortedItems) {
      final questionJson = item['questions'];
      if (questionJson is! Map) continue;
      try {
        final row = QuestionRow.fromJson(
          Map<String, dynamic>.from(questionJson),
        );
        final question = QuizQuestionMapper.fromRow(row);
        if (question != null) questions.add(question);
      } catch (err, st) {
        debugPrint(
          'StudentQuizRepository.fetchLessonSheetContent: domanda non mappabile: '
          '$err\n$st',
        );
      }
    }

    return LessonQuizSheetContent(
      quizSetId: quizSetId,
      categoryId: categoryId,
      lessonNumber: lessonNumber,
      sheetNumber: sheetNumber,
      questions: questions,
    );
  }

  @override
  Future<List<QuizQuestion>> fetchLessonSheetQuestions({
    required LicenseCategoryId categoryId,
    required int lessonNumber,
    required int sheetNumber,
    int limit = 20,
  }) async {
    final content = await fetchLessonSheetContent(
      categoryId: categoryId,
      lessonNumber: lessonNumber,
      sheetNumber: sheetNumber,
    );
    return content?.questions ?? const [];
  }
}

String? _dbLicenseCategory(LicenseCategoryId categoryId) {
  switch (categoryId) {
    case LicenseCategoryId.motore:
      return 'A12';
    case LicenseCategoryId.d1:
      return 'D1';
    case LicenseCategoryId.vela:
      return null;
  }
}

class StudentQuizRepositoryEmpty implements StudentQuizRepository {
  const StudentQuizRepositoryEmpty();

  @override
  Future<LessonQuizSheetContent?> fetchLessonSheetContent({
    required LicenseCategoryId categoryId,
    required int lessonNumber,
    required int sheetNumber,
  }) async => null;

  @override
  Future<List<QuizQuestion>> fetchLessonSheetQuestions({
    required LicenseCategoryId categoryId,
    required int lessonNumber,
    required int sheetNumber,
    int limit = 20,
  }) async => const [];
}

StudentQuizRepository get studentQuizRepository {
  if (SupabaseConfig.isConfigured) {
    return StudentQuizRepositorySupabase.instance;
  }
  return const StudentQuizRepositoryEmpty();
}
