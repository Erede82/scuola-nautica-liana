import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../data/quiz_question_mapper.dart';
import '../data/supabase/dto/question_row.dart';
import '../domain/quiz_sheet_slicing.dart';
import '../models/license_models.dart';
import '../models/quiz_question.dart';

export '../domain/quiz_sheet_slicing.dart';

/// Lettura domande quiz per area studente (tabella `questions`, read-only).
abstract class StudentQuizRepository {
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

  static const _selectColumns =
      'id, prompt, option_a, option_b, option_c, correct_option, '
      'lesson_number, license_category, exam_topic_code, source_topic_text, '
      'image_path, explanation';

  @override
  Future<List<QuizQuestion>> fetchLessonSheetQuestions({
    required LicenseCategoryId categoryId,
    required int lessonNumber,
    required int sheetNumber,
    int limit = 20,
  }) async {
    final dbCategory = _dbLicenseCategory(categoryId);
    if (dbCategory == null) return const [];

    final res = await _client
        .from('questions')
        .select(_selectColumns)
        .eq('license_category', dbCategory)
        .eq('lesson_number', lessonNumber)
        .order('id', ascending: true);

    final rawList = res as List<dynamic>;
    final pool = <QuizQuestion>[];
    for (final e in rawList) {
      try {
        final row = QuestionRow.fromJson(Map<String, dynamic>.from(e as Map));
        final question = QuizQuestionMapper.fromRow(row);
        if (question != null) pool.add(question);
      } catch (err, st) {
        debugPrint(
          'StudentQuizRepository.fetchLessonSheetQuestions: riga non mappabile: '
          '$err\n$st',
        );
      }
    }

    return sliceLessonSheetQuestions(
      pool: pool,
      sheetNumber: sheetNumber,
      limit: limit,
    );
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
