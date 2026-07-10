import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../data/quiz_question_mapper.dart';
import '../data/supabase/dto/question_row.dart';
import '../models/lesson_quiz_sheet_content.dart';
import '../models/lesson_sheet_completion_snapshot.dart';
import '../models/license_models.dart';
import '../models/quiz_question.dart';
import '../domain/exam_question_selection.dart';

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

  /// Schede con tentativo completo (`quiz_results` + `quiz_attempt_answers` coerenti).
  Future<LessonSheetCompletionSnapshot> fetchLessonSheetCompletion({
    required LicenseCategoryId categoryId,
    required int lessonNumber,
  });

  /// Domande esame raggruppate per `exam_topic_code` (read-only).
  Future<Map<String, List<QuizQuestion>>> fetchExamQuestionsByTopic({
    required LicenseCategoryId categoryId,
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

  @override
  Future<LessonSheetCompletionSnapshot> fetchLessonSheetCompletion({
    required LicenseCategoryId categoryId,
    required int lessonNumber,
  }) async {
    final dbCategory = _dbLicenseCategory(categoryId);
    if (dbCategory == null) return LessonSheetCompletionSnapshot.empty;

    final setsRes = await _client
        .from('quiz_sets')
        .select('id, sheet_number')
        .eq('kind', 'lesson')
        .eq('license_category', dbCategory)
        .eq('lesson_number', lessonNumber)
        .order('sheet_number', ascending: true);

    final quizSetIdBySheet = <int, String>{};
    for (final row in setsRes as List<dynamic>) {
      final map = Map<String, dynamic>.from(row as Map);
      final sheetNumber = (map['sheet_number'] as num?)?.toInt();
      final quizSetId = map['id']?.toString();
      if (sheetNumber == null || quizSetId == null || quizSetId.isEmpty) {
        continue;
      }
      quizSetIdBySheet[sheetNumber] = quizSetId;
    }

    if (quizSetIdBySheet.isEmpty) {
      return LessonSheetCompletionSnapshot.empty;
    }

    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return buildLessonSheetCompletionSnapshot(
        quizSetIdBySheet: quizSetIdBySheet,
        completedQuizSetIds: const {},
      );
    }

    final resultsRes = await _client
        .from('quiz_results')
        .select('id, quiz_set_id, total_questions')
        .eq('user_id', userId)
        .inFilter('quiz_set_id', quizSetIdBySheet.values.toList());

    final attempts = <LessonQuizResultAttempt>[];
    final resultIds = <String>[];
    for (final row in resultsRes as List<dynamic>) {
      final map = Map<String, dynamic>.from(row as Map);
      final id = map['id']?.toString();
      final quizSetId = map['quiz_set_id']?.toString();
      final totalQuestions = (map['total_questions'] as num?)?.toInt() ?? 0;
      if (id == null || id.isEmpty || quizSetId == null || quizSetId.isEmpty) {
        continue;
      }
      attempts.add(
        LessonQuizResultAttempt(
          id: id,
          quizSetId: quizSetId,
          totalQuestions: totalQuestions,
        ),
      );
      resultIds.add(id);
    }

    final answerCountByResultId = <String, int>{};
    if (resultIds.isNotEmpty) {
      final answersRes = await _client
          .from('quiz_attempt_answers')
          .select('quiz_result_id')
          .inFilter('quiz_result_id', resultIds);

      for (final row in answersRes as List<dynamic>) {
        final map = Map<String, dynamic>.from(row as Map);
        final resultId = map['quiz_result_id']?.toString();
        if (resultId == null || resultId.isEmpty) continue;
        answerCountByResultId[resultId] =
            (answerCountByResultId[resultId] ?? 0) + 1;
      }
    }

    final completedQuizSetIds = completedQuizSetIdsFromAttempts(
      results: attempts,
      answerCountByResultId: answerCountByResultId,
    );

    return buildLessonSheetCompletionSnapshot(
      quizSetIdBySheet: quizSetIdBySheet,
      completedQuizSetIds: completedQuizSetIds,
    );
  }

  @override
  Future<Map<String, List<QuizQuestion>>> fetchExamQuestionsByTopic({
    required LicenseCategoryId categoryId,
  }) async {
    final dbCategory = _dbLicenseCategory(categoryId);
    if (dbCategory == null) return {};

    final quotas = examTopicQuotasForCategory(dbCategory);
    if (quotas == null || quotas.isEmpty) return {};

    final poolByTopic = <String, List<QuizQuestion>>{};
    for (final topic in quotas.keys) {
      final res = await _client
          .from('questions')
          .select(_questionSelectColumns)
          .eq('license_category', dbCategory)
          .eq('exam_topic_code', topic);

      final questions = <QuizQuestion>[];
      for (final row in res as List<dynamic>) {
        try {
          final map = Map<String, dynamic>.from(row as Map);
          final questionRow = QuestionRow.fromJson(map);
          final question = QuizQuestionMapper.fromRow(questionRow);
          if (question != null) questions.add(question);
        } catch (err, st) {
          debugPrint(
            'StudentQuizRepository.fetchExamQuestionsByTopic: skip row: '
            '$err\n$st',
          );
        }
      }
      if (questions.isNotEmpty) {
        poolByTopic[topic] = questions;
      }
    }

    return poolByTopic;
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

StudentQuizRepository get studentQuizRepository {
  if (SupabaseConfig.isConfigured) {
    return StudentQuizRepositorySupabase.instance;
  }
  return const StudentQuizRepositoryEmpty();
}
