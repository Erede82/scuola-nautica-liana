import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/supabase_config.dart';
import 'dto/quiz_attempt_answer_row.dart';
import 'dto/quiz_result_row.dart';
import 'dto/quiz_sheet_catalog_row.dart';
import 'dto/quiz_wrong_answer_history_row.dart';

/// Lettura read-only storico tentativi schede lezione (Supabase).
abstract class QuizAttemptHistoryDataSource {
  Future<List<QuizResultRow>> fetchLessonResultsForCategory({
    required String userId,
    required String licenseCategoryDb,
  });

  Future<Map<String, int>> fetchAnswerCountsByResultIds({
    required String userId,
    required List<String> quizResultIds,
  });

  Future<List<QuizWrongAnswerHistoryRow>> fetchWrongLessonAnswersForUser({
    required String userId,
    required String licenseCategoryDb,
  });

  Future<List<QuizSheetCatalogRow>> fetchLessonSheetCatalog({
    required String licenseCategoryDb,
  });
}

class QuizAttemptHistoryDataSourceSupabase
    implements QuizAttemptHistoryDataSource {
  QuizAttemptHistoryDataSourceSupabase._();

  static final QuizAttemptHistoryDataSourceSupabase instance =
      QuizAttemptHistoryDataSourceSupabase._();

  static const int answerCountInChunkSize = 100;

  SupabaseClient get _client {
    if (!SupabaseConfig.isConfigured) {
      throw StateError('Supabase non inizializzato.');
    }
    return Supabase.instance.client;
  }

  static const _resultSelect =
      'id, quiz_set_id, total_questions, correct_count, wrong_count, '
      'unanswered_count, wrong_question_ids, started_at, completed_at, '
      'duration_seconds, created_at, '
      'quiz_sets!inner(kind, license_category, lesson_number, sheet_number)';

  static const _catalogSelect =
      'id, kind, license_category, lesson_number, sheet_number';

  static const _wrongAnswerSelect =
      'id, quiz_result_id, user_id, question_id, selected_option, '
      'correct_option, is_correct, answered_at, '
      'questions!inner(id, prompt, option_a, option_b, option_c, '
      'correct_option, explanation, image_path, lesson_number, '
      'license_category, exam_topic_code, source_topic_text)';

  @override
  Future<List<QuizResultRow>> fetchLessonResultsForCategory({
    required String userId,
    required String licenseCategoryDb,
  }) async {
    final res = await _client
        .from('quiz_results')
        .select(_resultSelect)
        .eq('user_id', userId)
        .eq('quiz_sets.kind', 'lesson')
        .eq('quiz_sets.license_category', licenseCategoryDb)
        .order('completed_at', ascending: false);

    final rows = <QuizResultRow>[];
    for (final item in res as List<dynamic>) {
      if (item is! Map) continue;
      rows.add(QuizResultRow.fromJson(Map<String, dynamic>.from(item)));
    }
    return rows;
  }

  @override
  Future<Map<String, int>> fetchAnswerCountsByResultIds({
    required String userId,
    required List<String> quizResultIds,
  }) async {
    if (quizResultIds.isEmpty) return const {};

    final counts = <String, int>{};
    for (
      var offset = 0;
      offset < quizResultIds.length;
      offset += answerCountInChunkSize
    ) {
      final end = math.min(
        offset + answerCountInChunkSize,
        quizResultIds.length,
      );
      final chunk = quizResultIds.sublist(offset, end);

      final res = await _client
          .from('quiz_attempt_answers')
          .select('quiz_result_id')
          .eq('user_id', userId)
          .inFilter('quiz_result_id', chunk);

      for (final item in res as List<dynamic>) {
        if (item is! Map) continue;
        final resultId = item['quiz_result_id']?.toString();
        if (resultId == null || resultId.isEmpty) continue;
        counts[resultId] = (counts[resultId] ?? 0) + 1;
      }
    }

    return counts;
  }

  @override
  Future<List<QuizWrongAnswerHistoryRow>> fetchWrongLessonAnswersForUser({
    required String userId,
    required String licenseCategoryDb,
  }) async {
    final results = await fetchLessonResultsForCategory(
      userId: userId,
      licenseCategoryDb: licenseCategoryDb,
    );
    if (results.isEmpty) return const [];

    final resultById = {for (final row in results) row.id: row};
    final resultIds = results.map((row) => row.id).toList();
    final rows = <QuizWrongAnswerHistoryRow>[];

    for (
      var offset = 0;
      offset < resultIds.length;
      offset += answerCountInChunkSize
    ) {
      final end = math.min(offset + answerCountInChunkSize, resultIds.length);
      final chunk = resultIds.sublist(offset, end);

      final res = await _client
          .from('quiz_attempt_answers')
          .select(_wrongAnswerSelect)
          .eq('user_id', userId)
          .eq('is_correct', false)
          .not('selected_option', 'is', null)
          .inFilter('quiz_result_id', chunk);

      for (final item in res as List<dynamic>) {
        if (item is! Map) continue;
        final json = Map<String, dynamic>.from(item);
        final resultId = json['quiz_result_id']?.toString() ?? '';
        final result = resultById[resultId];
        if (result == null) continue;
        rows.add(
          QuizWrongAnswerHistoryRow.fromAnswerJson(json, result: result),
        );
      }
    }

    return rows;
  }

  @override
  Future<List<QuizSheetCatalogRow>> fetchLessonSheetCatalog({
    required String licenseCategoryDb,
  }) async {
    final res = await _client
        .from('quiz_sets')
        .select(_catalogSelect)
        .eq('kind', 'lesson')
        .eq('license_category', licenseCategoryDb)
        .order('lesson_number')
        .order('sheet_number');

    final rows = <QuizSheetCatalogRow>[];
    for (final item in res as List<dynamic>) {
      if (item is! Map) continue;
      rows.add(QuizSheetCatalogRow.fromJson(Map<String, dynamic>.from(item)));
    }
    return rows;
  }
}

/// Data source in-memory per test e ambienti senza Supabase.
class QuizAttemptHistoryDataSourceInMemory
    implements QuizAttemptHistoryDataSource {
  QuizAttemptHistoryDataSourceInMemory({
    List<QuizResultRow> results = const [],
    Map<String, int> answerCountsByResultId = const {},
    List<QuizWrongAnswerHistoryRow> wrongAnswers = const [],
    List<QuizSheetCatalogRow> catalog = const [],
    this.throwOnFetch = false,
    this.throwOnWrongAnswersFetch = false,
    this.throwOnCatalogFetch = false,
  }) : _results = List<QuizResultRow>.from(results),
       _answerCountsByResultId = Map<String, int>.from(answerCountsByResultId),
       _wrongAnswers = List<QuizWrongAnswerHistoryRow>.from(wrongAnswers),
       _catalog = List<QuizSheetCatalogRow>.from(catalog);

  final List<QuizResultRow> _results;
  final Map<String, int> _answerCountsByResultId;
  final List<QuizWrongAnswerHistoryRow> _wrongAnswers;
  final List<QuizSheetCatalogRow> _catalog;
  final bool throwOnFetch;
  final bool throwOnWrongAnswersFetch;
  final bool throwOnCatalogFetch;

  String? lastUserIdForResults;
  String? lastUserIdForAnswerCounts;
  String? lastUserIdForWrongAnswers;
  String? lastLicenseCategoryForWrongAnswers;
  List<String> lastAnswerCountResultIds = const [];

  @override
  Future<List<QuizResultRow>> fetchLessonResultsForCategory({
    required String userId,
    required String licenseCategoryDb,
  }) async {
    lastUserIdForResults = userId;
    if (throwOnFetch) {
      throw StateError('fetchLessonResultsForCategory failed');
    }

    return _results
        .where(
          (row) =>
              row.kind == 'lesson' && row.licenseCategory == licenseCategoryDb,
        )
        .toList(growable: false);
  }

  @override
  Future<Map<String, int>> fetchAnswerCountsByResultIds({
    required String userId,
    required List<String> quizResultIds,
  }) async {
    lastUserIdForAnswerCounts = userId;
    lastAnswerCountResultIds = List<String>.from(quizResultIds);
    if (throwOnFetch) {
      throw StateError('fetchAnswerCountsByResultIds failed');
    }

    final counts = <String, int>{};
    for (final id in quizResultIds) {
      final count = _answerCountsByResultId[id];
      if (count != null) counts[id] = count;
    }
    return counts;
  }

  @override
  Future<List<QuizWrongAnswerHistoryRow>> fetchWrongLessonAnswersForUser({
    required String userId,
    required String licenseCategoryDb,
  }) async {
    lastUserIdForWrongAnswers = userId;
    lastLicenseCategoryForWrongAnswers = licenseCategoryDb;
    if (throwOnWrongAnswersFetch) {
      throw StateError('fetchWrongLessonAnswersForUser failed');
    }

    return _wrongAnswers
        .where(
          (row) =>
              row.userId == userId &&
              row.kind == 'lesson' &&
              row.licenseCategory == licenseCategoryDb &&
              row.isCorrect == false &&
              row.selectedOption != null &&
              row.selectedOption!.trim().isNotEmpty,
        )
        .toList(growable: false);
  }

  @override
  Future<List<QuizSheetCatalogRow>> fetchLessonSheetCatalog({
    required String licenseCategoryDb,
  }) async {
    if (throwOnCatalogFetch) {
      throw StateError('fetchLessonSheetCatalog failed');
    }

    return _catalog
        .where(
          (row) =>
              row.kind == 'lesson' && row.licenseCategory == licenseCategoryDb,
        )
        .toList(growable: false);
  }
}

QuizAttemptHistoryDataSource get quizAttemptHistoryDataSource {
  if (SupabaseConfig.isConfigured) {
    return QuizAttemptHistoryDataSourceSupabase.instance;
  }
  return QuizAttemptHistoryDataSourceInMemory();
}

/// Parse riga risposta (esposto per eventuale uso Ripasso errori in fase C).
QuizAttemptAnswerRow parseQuizAttemptAnswerRow(Map<String, dynamic> json) =>
    QuizAttemptAnswerRow.fromJson(json);
