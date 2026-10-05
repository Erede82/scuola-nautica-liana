import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../data/supabase/mappers/multi_topic_quiz_attempt_mapper.dart';
import '../debug/quiz_flow_debug.dart';
import '../domain/multi_topic_question_history_usage.dart';
import '../domain/multi_topic_quiz_attempt_exception.dart';
import '../domain/multi_topic_quiz_attempt_result.dart';
import '../domain/multi_topic_quiz_attempt_submission.dart';
import '../domain/multi_topic_quiz_history_models.dart';
import '../domain/quiz_license_category.dart';
import '../models/license_models.dart';

const multiTopicQuizAttemptSubmitRpcName = 'submit_multi_topic_quiz_attempt';

/// Tabelle dedicate Multischeda (mai `quiz_results` / `quiz_sets` per lo storico).
const multiTopicQuizAttemptsTable = 'multi_topic_quiz_attempts';
const multiTopicQuizAttemptAnswersTable = 'multi_topic_quiz_attempt_answers';

/// Tabelle lesson history da NON usare per Multischeda.
const multiTopicForbiddenLessonHistoryTables = {
  'quiz_results',
  'quiz_sets',
  'quiz_attempt_answers',
};

const multiTopicQuizAttemptSubmitRpcParamKeys = {
  'p_client_submission_id',
  'p_session_id',
  'p_license_category',
  'p_lesson_numbers',
  'p_sheet_index',
  'p_total_sheets',
  'p_started_at',
  'p_duration_seconds',
  'p_answers',
};

String multiTopicQuizAttemptRpcParamTypeLabel(Object? value) {
  if (value == null) return 'null';
  if (value is String) return 'String';
  if (value is int) return 'int';
  if (value is bool) return 'bool';
  if (value is List) return 'List';
  return value.runtimeType.toString();
}

void validateMultiTopicQuizAttemptSubmitRpcParams(Map<String, dynamic> params) {
  final keys = params.keys.toSet();
  if (keys.length == multiTopicQuizAttemptSubmitRpcParamKeys.length &&
      multiTopicQuizAttemptSubmitRpcParamKeys.every(keys.contains)) {
    return;
  }

  final missing = multiTopicQuizAttemptSubmitRpcParamKeys.difference(keys);
  final unexpected = keys.difference(multiTopicQuizAttemptSubmitRpcParamKeys);
  if (kDebugMode) {
    qfLog(
      'MultiTopicQuizAttempt RPC params mismatch '
      'missing=$missing unexpected=$unexpected',
    );
  }
  throw const MultiTopicQuizAttemptException(
    code: MultiTopicQuizAttemptErrorCode.invalidPayload,
    message: 'Parametri RPC submit Multischeda non validi.',
  );
}

void debugLogMultiTopicQuizAttemptSubmitRpcRequest(
  Map<String, dynamic> params,
) {
  if (!kDebugMode) return;
  final sortedKeys = params.keys.toList()..sort();
  final types = {
    for (final key in sortedKeys)
      key: multiTopicQuizAttemptRpcParamTypeLabel(params[key]),
  };
  qfLog(
    'MultiTopicQuizAttempt RPC request '
    'rpc=$multiTopicQuizAttemptSubmitRpcName '
    'keys=$sortedKeys '
    'types=$types',
  );
}

void debugLogMultiTopicQuizAttemptPostgrestException(PostgrestException error) {
  if (!kDebugMode) return;
  qfLog(
    'MultiTopicQuizAttempt RPC PostgrestException '
    'code=${error.code} '
    'message=${error.message} '
    'details=${error.details} '
    'hint=${error.hint}',
  );
}

/// Persistenza + storico Multischeda — isolata da `quiz_attempt_repository`.
abstract class MultiTopicQuizAttemptRepository {
  Future<MultiTopicQuizAttemptResult> submitAttempt(
    MultiTopicQuizAttemptSubmission submission,
  );

  /// Storico tentativi conclusi (read-only, tabelle dedicate).
  Future<List<MultiTopicQuizAttemptSummary>> fetchCurrentUserAttempts({
    required LicenseCategoryId category,
  });

  /// Question IDs già mostrati in Multischede completate (categoria corrente).
  ///
  /// Una sola operazione logica: attempt IDs categoria → answers question_id.
  /// Include anche unanswered (selected_option NULL): la domanda è stata vista.
  Future<MultiTopicQuestionHistoryUsage> fetchCurrentUserQuestionUsage({
    required LicenseCategoryId category,
  });

  /// Dettaglio con snapshot risposte (nessuna rilettura di `questions`).
  Future<MultiTopicQuizAttemptDetail> fetchAttemptDetail(String attemptId);
}

class MultiTopicQuizAttemptRepositorySupabase
    implements MultiTopicQuizAttemptRepository {
  MultiTopicQuizAttemptRepositorySupabase({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _attemptSelect =
      'id, session_id, license_category, lesson_numbers, sheet_index, '
      'total_sheets, completed_at, duration_seconds, total_questions, '
      'correct_count, wrong_count, unanswered_count';

  static const _answerSelect =
      'position, question_id, prompt_snapshot, option_a_snapshot, '
      'option_b_snapshot, option_c_snapshot, image_path_snapshot, '
      'explanation_snapshot, lesson_number_snapshot, selected_option, '
      'correct_option, is_correct';

  T _mapParse<T>(T Function() parse) {
    try {
      return parse();
    } on MultiTopicQuizAttemptException {
      rethrow;
    } on FormatException catch (e) {
      throw MultiTopicQuizAttemptException(
        code: MultiTopicQuizAttemptErrorCode.invalidPayload,
        message: e.message,
        cause: e,
      );
    }
  }

  Never _rethrowMapped(Object error) {
    throw multiTopicQuizAttemptExceptionFrom(error);
  }

  String _requireUid() {
    final uid = _client.auth.currentUser?.id;
    if (uid == null || uid.isEmpty) {
      throw const MultiTopicQuizAttemptException(
        code: MultiTopicQuizAttemptErrorCode.notAuthenticated,
        message: 'Sessione non disponibile. Accedi nuovamente.',
      );
    }
    return uid;
  }

  /// Pagine PostgREST ordinate per `id`.
  /// Una pagina piena richiede la successiva.
  ///
  /// Se si raggiunge [multiTopicQuestionUsageMaxPages] senza una pagina corta,
  /// fallisce: una history troncata farebbe ripetere domande già viste.
  Future<List<dynamic>> _fetchUsagePages(
    Future<dynamic> Function(int from, int to) fetchPage,
  ) async {
    final rows = <dynamic>[];
    for (
      var pageIndex = 0;
      pageIndex < multiTopicQuestionUsageMaxPages;
      pageIndex++
    ) {
      final window = multiTopicUsagePageRange(pageIndex: pageIndex);
      final raw = await fetchPage(window.from, window.to);
      final pageRows = raw as List<dynamic>;
      rows.addAll(pageRows);
      if (pageRows.length < multiTopicQuestionUsagePageSize) {
        return rows;
      }
    }
    throw const MultiTopicQuizAttemptException(
      code: MultiTopicQuizAttemptErrorCode.unknown,
      message: 'Operazione non riuscita. Riprova più tardi.',
    );
  }

  @override
  Future<MultiTopicQuizAttemptResult> submitAttempt(
    MultiTopicQuizAttemptSubmission submission,
  ) async {
    _requireUid();
    if (dbLicenseCategoryFor(submission.licenseCategory) == null) {
      throw const MultiTopicQuizAttemptException(
        code: MultiTopicQuizAttemptErrorCode.invalidLicenseCategory,
        message: 'Categoria patente non valida per la Multischeda.',
      );
    }
    try {
      final params = submission.toRpcParams();
      validateMultiTopicQuizAttemptSubmitRpcParams(params);
      debugLogMultiTopicQuizAttemptSubmitRpcRequest(params);
      final raw = await _client.rpc(
        multiTopicQuizAttemptSubmitRpcName,
        params: params,
      );
      return _mapParse(() => parseMultiTopicQuizAttemptSubmitResult(raw));
    } on MultiTopicQuizAttemptException {
      rethrow;
    } on PostgrestException catch (error) {
      debugLogMultiTopicQuizAttemptPostgrestException(error);
      _rethrowMapped(error);
    } catch (error) {
      _rethrowMapped(error);
    }
  }

  @override
  Future<List<MultiTopicQuizAttemptSummary>> fetchCurrentUserAttempts({
    required LicenseCategoryId category,
  }) async {
    _requireUid();
    final dbCategory = dbLicenseCategoryFor(category);
    if (dbCategory == null) {
      throw const MultiTopicQuizAttemptException(
        code: MultiTopicQuizAttemptErrorCode.invalidLicenseCategory,
        message: 'Categoria patente non valida per la Multischeda.',
      );
    }
    try {
      final res = await _client
          .from(multiTopicQuizAttemptsTable)
          .select(_attemptSelect)
          .eq('license_category', dbCategory)
          .order('completed_at', ascending: false);
      return _mapParse(() {
        return (res as List<dynamic>)
            .map(
              (row) =>
                  parseMultiTopicQuizAttemptSummary(requireMultiTopicMap(row)),
            )
            .toList(growable: false);
      });
    } on MultiTopicQuizAttemptException {
      rethrow;
    } on PostgrestException catch (error) {
      debugLogMultiTopicQuizAttemptPostgrestException(error);
      _rethrowMapped(error);
    } catch (error) {
      _rethrowMapped(error);
    }
  }

  @override
  Future<MultiTopicQuestionHistoryUsage> fetchCurrentUserQuestionUsage({
    required LicenseCategoryId category,
  }) async {
    _requireUid();
    final dbCategory = dbLicenseCategoryFor(category);
    if (dbCategory == null) {
      throw const MultiTopicQuizAttemptException(
        code: MultiTopicQuizAttemptErrorCode.invalidLicenseCategory,
        message: 'Categoria patente non valida per la Multischeda.',
      );
    }
    try {
      final attemptRows = await _fetchUsagePages((from, to) {
        return _client
            .from(multiTopicQuizAttemptsTable)
            .select('id')
            .eq('license_category', dbCategory)
            .order('id')
            .range(from, to);
      });
      final attemptIds = <String>[
        for (final row in attemptRows)
          if (row is Map && (row['id']?.toString() ?? '').trim().isNotEmpty)
            row['id'].toString().trim(),
      ];
      if (attemptIds.isEmpty) {
        return MultiTopicQuestionHistoryUsage.empty;
      }

      final rows = <({String questionId, DateTime? createdAt})>[];
      for (
        var offset = 0;
        offset < attemptIds.length;
        offset += multiTopicQuestionUsageAttemptChunkSize
      ) {
        final end = math.min(
          offset + multiTopicQuestionUsageAttemptChunkSize,
          attemptIds.length,
        );
        final chunk = attemptIds.sublist(offset, end);
        final answersRes = await _fetchUsagePages((from, to) {
          return _client
              .from(multiTopicQuizAttemptAnswersTable)
              .select('question_id, created_at')
              .inFilter('attempt_id', chunk)
              .order('id')
              .range(from, to);
        });
        for (final item in answersRes) {
          if (item is! Map) continue;
          final questionId = item['question_id']?.toString().trim() ?? '';
          if (questionId.isEmpty) continue;
          DateTime? createdAt;
          final rawCreated = item['created_at']?.toString();
          if (rawCreated != null && rawCreated.isNotEmpty) {
            createdAt = DateTime.tryParse(rawCreated);
          }
          rows.add((questionId: questionId, createdAt: createdAt));
        }
      }
      return MultiTopicQuestionHistoryUsage.fromAnswerRows(rows);
    } on MultiTopicQuizAttemptException {
      rethrow;
    } on PostgrestException catch (error) {
      debugLogMultiTopicQuizAttemptPostgrestException(error);
      _rethrowMapped(error);
    } catch (error) {
      _rethrowMapped(error);
    }
  }

  @override
  Future<MultiTopicQuizAttemptDetail> fetchAttemptDetail(
    String attemptId,
  ) async {
    _requireUid();
    if (attemptId.trim().isEmpty) {
      throw const MultiTopicQuizAttemptException(
        code: MultiTopicQuizAttemptErrorCode.invalidPayload,
        message: 'Identificativo tentativo non valido.',
      );
    }
    try {
      final attemptRes = await _client
          .from(multiTopicQuizAttemptsTable)
          .select(_attemptSelect)
          .eq('id', attemptId)
          .maybeSingle();
      if (attemptRes == null) {
        throw const MultiTopicQuizAttemptException(
          code: MultiTopicQuizAttemptErrorCode.invalidPayload,
          message: 'Tentativo Multischeda non trovato.',
        );
      }
      final answersRes = await _client
          .from(multiTopicQuizAttemptAnswersTable)
          .select(_answerSelect)
          .eq('attempt_id', attemptId)
          .order('position', ascending: true);
      return _mapParse(() {
        return parseMultiTopicQuizAttemptDetail(
          attemptRow: requireMultiTopicMap(attemptRes),
          answerRows: answersRes as List<dynamic>,
        );
      });
    } on MultiTopicQuizAttemptException {
      rethrow;
    } on PostgrestException catch (error) {
      debugLogMultiTopicQuizAttemptPostgrestException(error);
      _rethrowMapped(error);
    } catch (error) {
      _rethrowMapped(error);
    }
  }
}

class MultiTopicQuizAttemptRepositoryEmpty
    implements MultiTopicQuizAttemptRepository {
  const MultiTopicQuizAttemptRepositoryEmpty();

  @override
  Future<MultiTopicQuizAttemptResult> submitAttempt(
    MultiTopicQuizAttemptSubmission submission,
  ) async {
    throw const MultiTopicQuizAttemptException(
      code: MultiTopicQuizAttemptErrorCode.repositoryUnavailable,
      message: 'Repository Multischeda non disponibile.',
    );
  }

  @override
  Future<List<MultiTopicQuizAttemptSummary>> fetchCurrentUserAttempts({
    required LicenseCategoryId category,
  }) async => const [];

  @override
  Future<MultiTopicQuestionHistoryUsage> fetchCurrentUserQuestionUsage({
    required LicenseCategoryId category,
  }) async => MultiTopicQuestionHistoryUsage.empty;

  @override
  Future<MultiTopicQuizAttemptDetail> fetchAttemptDetail(
    String attemptId,
  ) async {
    throw const MultiTopicQuizAttemptException(
      code: MultiTopicQuizAttemptErrorCode.repositoryUnavailable,
      message: 'Repository Multischeda non disponibile.',
    );
  }
}

/// Fake testabile: memorizza chiamate e riusa lo stesso oggetto submission.
class MultiTopicQuizAttemptRepositoryFake
    implements MultiTopicQuizAttemptRepository {
  MultiTopicQuizAttemptRepositoryFake({
    this.submitResult,
    this.throwOnSubmit,
    List<MultiTopicQuizAttemptSummary>? history,
    this.throwOnHistoryFetch,
    MultiTopicQuestionHistoryUsage? questionUsage,
    this.throwOnQuestionUsageFetch,
    this.detailById,
    this.throwOnDetailFetch,
  }) : history = history ?? <MultiTopicQuizAttemptSummary>[],
       questionUsage = questionUsage ?? MultiTopicQuestionHistoryUsage.empty;

  MultiTopicQuizAttemptResult? submitResult;
  Object? throwOnSubmit;
  final List<MultiTopicQuizAttemptSubmission> submitCalls = [];
  final List<Map<String, dynamic>> submitRpcParamsLog = [];
  List<MultiTopicQuizAttemptSummary> history;
  Object? throwOnHistoryFetch;
  MultiTopicQuestionHistoryUsage questionUsage;
  Object? throwOnQuestionUsageFetch;
  Map<String, MultiTopicQuizAttemptDetail>? detailById;
  Object? throwOnDetailFetch;

  /// Tabelle toccate dalle letture storico (contract isolation).
  final List<String> historyStorageTouches = [];

  @override
  Future<MultiTopicQuizAttemptResult> submitAttempt(
    MultiTopicQuizAttemptSubmission submission,
  ) async {
    submitCalls.add(submission);
    submitRpcParamsLog.add(submission.toRpcParams());
    if (throwOnSubmit != null) {
      final err = throwOnSubmit!;
      throwOnSubmit = null;
      if (err is MultiTopicQuizAttemptException) throw err;
      throw multiTopicQuizAttemptExceptionFrom(err);
    }
    final result = submitResult;
    if (result == null) {
      throw const MultiTopicQuizAttemptException(
        code: MultiTopicQuizAttemptErrorCode.repositoryUnavailable,
        message: 'Fake senza risultato configurato.',
      );
    }
    return result;
  }

  @override
  Future<List<MultiTopicQuizAttemptSummary>> fetchCurrentUserAttempts({
    required LicenseCategoryId category,
  }) async {
    historyStorageTouches.add(multiTopicQuizAttemptsTable);
    if (throwOnHistoryFetch != null) {
      final err = throwOnHistoryFetch!;
      if (err is MultiTopicQuizAttemptException) throw err;
      throw multiTopicQuizAttemptExceptionFrom(err);
    }
    return history
        .where((a) => a.licenseCategory == category)
        .toList(growable: false);
  }

  @override
  Future<MultiTopicQuestionHistoryUsage> fetchCurrentUserQuestionUsage({
    required LicenseCategoryId category,
  }) async {
    historyStorageTouches.add(multiTopicQuizAttemptsTable);
    historyStorageTouches.add(multiTopicQuizAttemptAnswersTable);
    if (throwOnQuestionUsageFetch != null) {
      final err = throwOnQuestionUsageFetch!;
      if (err is MultiTopicQuizAttemptException) throw err;
      throw multiTopicQuizAttemptExceptionFrom(err);
    }
    // Fake non filtra per categoria: i test impostano usage già scoped.
    return questionUsage;
  }

  @override
  Future<MultiTopicQuizAttemptDetail> fetchAttemptDetail(
    String attemptId,
  ) async {
    historyStorageTouches.add(multiTopicQuizAttemptsTable);
    historyStorageTouches.add(multiTopicQuizAttemptAnswersTable);
    if (throwOnDetailFetch != null) {
      final err = throwOnDetailFetch!;
      if (err is MultiTopicQuizAttemptException) throw err;
      throw multiTopicQuizAttemptExceptionFrom(err);
    }
    final detail = detailById?[attemptId];
    if (detail == null) {
      throw const MultiTopicQuizAttemptException(
        code: MultiTopicQuizAttemptErrorCode.invalidPayload,
        message: 'Tentativo Multischeda non trovato.',
      );
    }
    return detail;
  }
}

MultiTopicQuizAttemptRepository get multiTopicQuizAttemptRepository {
  if (SupabaseConfig.isConfigured) {
    return MultiTopicQuizAttemptRepositorySupabase();
  }
  return const MultiTopicQuizAttemptRepositoryEmpty();
}
