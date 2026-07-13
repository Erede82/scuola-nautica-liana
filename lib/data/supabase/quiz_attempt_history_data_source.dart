import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/supabase_config.dart';
import 'dto/quiz_attempt_answer_row.dart';
import 'dto/quiz_result_row.dart';

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
}

/// Data source in-memory per test e ambienti senza Supabase.
class QuizAttemptHistoryDataSourceInMemory
    implements QuizAttemptHistoryDataSource {
  QuizAttemptHistoryDataSourceInMemory({
    List<QuizResultRow> results = const [],
    Map<String, int> answerCountsByResultId = const {},
    this.throwOnFetch = false,
  }) : _results = List<QuizResultRow>.from(results),
       _answerCountsByResultId = Map<String, int>.from(answerCountsByResultId);

  final List<QuizResultRow> _results;
  final Map<String, int> _answerCountsByResultId;
  final bool throwOnFetch;

  String? lastUserIdForResults;
  String? lastUserIdForAnswerCounts;
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
