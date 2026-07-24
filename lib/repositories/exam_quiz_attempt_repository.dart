import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../data/supabase/mappers/exam_quiz_attempt_mapper.dart';
import '../domain/exam_quiz_attempt_exception.dart';
import '../domain/exam_quiz_attempt_models.dart';
import '../domain/exam_quiz_attempt_result.dart';
import '../domain/exam_quiz_attempt_submission.dart';
import '../domain/quiz_license_category.dart';
import '../models/license_models.dart';

/// Contratto data layer Quiz Esame (submit + storico tentativi).
///
/// Separato da schede lezione (`quiz_results`) e Assigned Quiz.
abstract class ExamQuizAttemptRepository {
  /// Invia un tentativo concluso tramite RPC `submit_exam_quiz_attempt`.
  Future<ExamQuizAttemptSubmitResult> submitAttempt(
    ExamQuizAttemptSubmission submission,
  );

  /// Elenco tentativi conclusi dell’utente corrente per [category].
  ///
  /// Non include lo snapshot delle 20 risposte.
  Future<List<ExamQuizAttemptSummary>> fetchCurrentUserAttempts({
    required LicenseCategoryId category,
  });

  /// Dettaglio completo (header + 20 snapshot) per review offline da `questions`.
  Future<ExamQuizAttemptResult> fetchAttemptDetail(String attemptId);
}

/// Implementazione Supabase (RPC submit + SELECT RLS).
class ExamQuizAttemptRepositorySupabase implements ExamQuizAttemptRepository {
  ExamQuizAttemptRepositorySupabase({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _attemptSelect =
      'id, license_category, completed_at, duration_seconds, time_expired, '
      'total_questions, correct_count, wrong_count, unanswered_count, passed';

  static const _answerSelect =
      'position, question_id, prompt_snapshot, option_a_snapshot, '
      'option_b_snapshot, option_c_snapshot, image_path_snapshot, '
      'selected_option, correct_option, is_correct';

  T _mapParse<T>(T Function() parse) {
    try {
      return parse();
    } on ExamQuizAttemptException {
      rethrow;
    } on FormatException catch (e) {
      throw ExamQuizAttemptException(
        code: ExamQuizAttemptErrorCode.invalidPayload,
        message: e.message,
        cause: e,
      );
    }
  }

  Never _rethrowMapped(Object error) {
    throw examQuizAttemptExceptionFrom(error);
  }

  String _requireUid() {
    final uid = _client.auth.currentUser?.id;
    if (uid == null || uid.isEmpty) {
      throw const ExamQuizAttemptException(
        code: ExamQuizAttemptErrorCode.notAuthenticated,
        message: 'Sessione non disponibile. Accedi nuovamente.',
      );
    }
    return uid;
  }

  @override
  Future<ExamQuizAttemptSubmitResult> submitAttempt(
    ExamQuizAttemptSubmission submission,
  ) async {
    _requireUid();
    try {
      // Esclusivamente i parametri dichiarabili dal client.
      final params = submission.toRpcParams();
      final raw = await _client.rpc('submit_exam_quiz_attempt', params: params);
      return _mapParse(() => parseExamQuizAttemptSubmitResult(raw));
    } on ExamQuizAttemptException {
      rethrow;
    } catch (error) {
      _rethrowMapped(error);
    }
  }

  @override
  Future<List<ExamQuizAttemptSummary>> fetchCurrentUserAttempts({
    required LicenseCategoryId category,
  }) async {
    _requireUid();
    final dbCategory = dbLicenseCategoryFor(category);
    if (dbCategory == null) {
      throw const ExamQuizAttemptException(
        code: ExamQuizAttemptErrorCode.invalidLicenseCategory,
        message: 'Categoria patente non valida per l’esame.',
      );
    }
    try {
      final res = await _client
          .from('exam_quiz_attempts')
          .select(_attemptSelect)
          .eq('license_category', dbCategory)
          .order('completed_at', ascending: false);
      return _mapParse(() {
        return (res as List<dynamic>)
            .map((row) => parseExamQuizAttemptSummary(requireExamQuizMap(row)))
            .toList(growable: false);
      });
    } on ExamQuizAttemptException {
      rethrow;
    } catch (error) {
      _rethrowMapped(error);
    }
  }

  @override
  Future<ExamQuizAttemptResult> fetchAttemptDetail(String attemptId) async {
    _requireUid();
    final id = attemptId.trim();
    if (id.isEmpty) {
      throw const ExamQuizAttemptException(
        code: ExamQuizAttemptErrorCode.invalidPayload,
        message: 'Campo attemptId vuoto.',
      );
    }
    try {
      final attemptRes = await _client
          .from('exam_quiz_attempts')
          .select(_attemptSelect)
          .eq('id', id)
          .maybeSingle();
      if (attemptRes == null) {
        throw const ExamQuizAttemptException(
          code: ExamQuizAttemptErrorCode.attemptNotFound,
          message: 'Tentativo esame non trovato.',
        );
      }

      final answersRes = await _client
          .from('exam_quiz_attempt_answers')
          .select(_answerSelect)
          .eq('attempt_id', id)
          .order('position', ascending: true);

      return _mapParse(() {
        final answerRows = (answersRes as List<dynamic>)
            .map(requireExamQuizMap)
            .toList(growable: false);
        return parseExamQuizAttemptResult(
          attemptJson: requireExamQuizMap(attemptRes),
          answerRows: answerRows,
        );
      });
    } on ExamQuizAttemptException {
      rethrow;
    } catch (error) {
      _rethrowMapped(error);
    }
  }
}

/// Stub senza rete (Supabase non configurato).
///
/// Le letture lista restano vuote; submit e dettaglio falliscono esplicitamente.
class ExamQuizAttemptRepositoryEmpty implements ExamQuizAttemptRepository {
  const ExamQuizAttemptRepositoryEmpty();

  static const _unavailable = ExamQuizAttemptException(
    code: ExamQuizAttemptErrorCode.repositoryUnavailable,
    message: 'Repository Quiz Esame non disponibile.',
  );

  @override
  Future<ExamQuizAttemptSubmitResult> submitAttempt(
    ExamQuizAttemptSubmission submission,
  ) async {
    throw _unavailable;
  }

  @override
  Future<List<ExamQuizAttemptSummary>> fetchCurrentUserAttempts({
    required LicenseCategoryId category,
  }) async => const [];

  @override
  Future<ExamQuizAttemptResult> fetchAttemptDetail(String attemptId) async {
    throw const ExamQuizAttemptException(
      code: ExamQuizAttemptErrorCode.attemptNotFound,
      message: 'Tentativo esame non trovato.',
    );
  }
}

/// Fake in-memory per test UI/repository senza rete.
class ExamQuizAttemptRepositoryFake implements ExamQuizAttemptRepository {
  ExamQuizAttemptRepositoryFake({
    this.submitResult,
    this.summaries = const [],
    this.details = const {},
    this.throwOnSubmit,
    this.throwOnList,
    this.throwOnDetail,
  });

  ExamQuizAttemptSubmitResult? submitResult;
  List<ExamQuizAttemptSummary> summaries;
  Map<String, ExamQuizAttemptResult> details;
  Object? throwOnSubmit;
  Object? throwOnList;
  Object? throwOnDetail;

  int submitCalls = 0;
  int listCalls = 0;
  int detailCalls = 0;
  ExamQuizAttemptSubmission? lastSubmission;
  LicenseCategoryId? lastListCategory;
  String? lastDetailId;
  final List<Map<String, dynamic>> submitRpcParamsLog = [];

  @override
  Future<ExamQuizAttemptSubmitResult> submitAttempt(
    ExamQuizAttemptSubmission submission,
  ) async {
    submitCalls += 1;
    lastSubmission = submission;
    // Specchio del repository reale: solo toRpcParams(), nessun campo autorevole.
    submitRpcParamsLog.add(Map<String, dynamic>.from(submission.toRpcParams()));
    if (throwOnSubmit != null) throw throwOnSubmit!;
    final result = submitResult;
    if (result == null) {
      throw const ExamQuizAttemptException(
        code: ExamQuizAttemptErrorCode.repositoryUnavailable,
        message: 'Fake senza submitResult configurato.',
      );
    }
    return result;
  }

  @override
  Future<List<ExamQuizAttemptSummary>> fetchCurrentUserAttempts({
    required LicenseCategoryId category,
  }) async {
    listCalls += 1;
    lastListCategory = category;
    if (throwOnList != null) throw throwOnList!;
    final db = dbLicenseCategoryFor(category);
    if (db == null) {
      throw const ExamQuizAttemptException(
        code: ExamQuizAttemptErrorCode.invalidLicenseCategory,
        message: 'Categoria patente non valida per l’esame.',
      );
    }
    final filtered =
        summaries
            .where((s) => dbLicenseCategoryFor(s.licenseCategory) == db)
            .toList(growable: false)
          ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return filtered;
  }

  @override
  Future<ExamQuizAttemptResult> fetchAttemptDetail(String attemptId) async {
    detailCalls += 1;
    lastDetailId = attemptId;
    if (throwOnDetail != null) throw throwOnDetail!;
    final detail = details[attemptId];
    if (detail == null) {
      throw const ExamQuizAttemptException(
        code: ExamQuizAttemptErrorCode.attemptNotFound,
        message: 'Tentativo esame non trovato.',
      );
    }
    return detail;
  }
}

ExamQuizAttemptRepository get examQuizAttemptRepository {
  if (SupabaseConfig.isConfigured) {
    return ExamQuizAttemptRepositorySupabase();
  }
  return const ExamQuizAttemptRepositoryEmpty();
}
