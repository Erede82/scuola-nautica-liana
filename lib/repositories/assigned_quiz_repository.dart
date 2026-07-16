import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../data/supabase/mappers/assigned_quiz_mapper.dart';
import '../models/assigned_quiz_models.dart';

/// Contratto data layer Quiz assegnati dalla scuola.
///
/// Separato da schede lezione / Quiz Esame / Statistiche standard.
abstract class AssignedQuizRepository {
  // --- Staff ---

  Future<AssignedQuizGenerationResult> generateFromErrors(
    AssignedQuizGenerationRequest request,
  );

  Future<List<AssignedQuizSummary>> loadForStudent(String studentId);

  Future<void> archiveAssignment(String assignmentId);

  Future<void> updateAssignmentMetadata(
    String assignmentId, {
    String? title,
    String? staffNote,
    DateTime? expiresAt,
  });

  Future<void> deleteDraft(String assignmentId);

  // --- Studente ---

  Future<List<AssignedQuizSummary>> loadMine();

  Future<AssignedQuizAttemptStartResult> startOrResume(String assignmentId);

  Future<List<AssignedQuizQuestion>> loadAttemptQuestions(String attemptId);

  Future<AssignedQuizAnswerSaveResult> saveAnswer({
    required String attemptId,
    required String assignmentItemId,
    required String? selectedOption,
  });

  Future<AssignedQuizSubmitResult> submitAttempt(String attemptId);

  Future<void> abandonAttempt(String attemptId);

  Future<List<AssignedQuizReviewItem>> loadAttemptReview(String attemptId);

  Future<List<AssignedQuizAttemptSummary>> loadAttempts(String assignmentId);
}

/// Implementazione Supabase (RPC + query `assigned_quizzes` / `assigned_quiz_attempts`).
class AssignedQuizRepositorySupabase implements AssignedQuizRepository {
  AssignedQuizRepositorySupabase({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _assignmentSelect =
      'id, public_code, student_id, student_user_id, license_category, '
      'title, staff_note, status, question_count, repeat_policy, max_attempts, '
      'created_at, assigned_at, expires_at, archived_at';

  static const _attemptSelect =
      'id, assignment_id, attempt_number, status, started_at, submitted_at, '
      'abandoned_at, correct_count, wrong_count, unanswered_count, '
      'score_percentage, duration_seconds';

  T _mapRpc<T>(T Function() parse) {
    try {
      return parse();
    } on AssignedQuizException {
      rethrow;
    } on FormatException catch (e) {
      throw AssignedQuizException(
        code: AssignedQuizErrorCode.unknown,
        message: e.message,
        cause: e,
      );
    }
  }

  Never _rethrowMapped(Object error) {
    throw assignedQuizExceptionFrom(error);
  }

  Future<T> _rpcJsonb<T>(
    String name,
    Map<String, dynamic> params,
    T Function(Object? raw) parse,
  ) async {
    try {
      final raw = await _client.rpc(name, params: params);
      return _mapRpc(() => parse(raw));
    } on AssignedQuizException {
      rethrow;
    } catch (error) {
      _rethrowMapped(error);
    }
  }

  @override
  Future<AssignedQuizGenerationResult> generateFromErrors(
    AssignedQuizGenerationRequest request,
  ) async {
    final params = assignedQuizGenerateRpcParams(request);
    assert(!params.containsKey('license_category'));
    assert(!params.containsKey('p_license_category'));
    return _rpcJsonb(
      'generate_assigned_quiz_from_errors',
      params,
      parseAssignedQuizGenerationResult,
    );
  }

  @override
  Future<List<AssignedQuizSummary>> loadForStudent(String studentId) async {
    try {
      final res = await _client
          .from('assigned_quizzes')
          .select(_assignmentSelect)
          .eq('student_id', studentId)
          .order('created_at', ascending: false);
      return (res as List<dynamic>)
          .map((row) => parseAssignedQuizSummary(requireAssignedQuizMap(row)))
          .toList(growable: false);
    } catch (error) {
      _rethrowMapped(error);
    }
  }

  @override
  Future<void> archiveAssignment(String assignmentId) async {
    try {
      await _client
          .from('assigned_quizzes')
          .update(<String, dynamic>{
            'status': AssignedQuizStatus.archived.dbValue,
            'archived_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', assignmentId);
    } catch (error) {
      _rethrowMapped(error);
    }
  }

  @override
  Future<void> updateAssignmentMetadata(
    String assignmentId, {
    String? title,
    String? staffNote,
    DateTime? expiresAt,
  }) async {
    final payload = <String, dynamic>{};
    if (title != null) {
      final trimmed = title.trim();
      if (trimmed.isEmpty) {
        throw const AssignedQuizException(
          code: AssignedQuizErrorCode.validationFailed,
          message: 'Il titolo è obbligatorio.',
        );
      }
      payload['title'] = trimmed;
    }
    if (staffNote != null) {
      payload['staff_note'] = staffNote.trim().isEmpty
          ? null
          : staffNote.trim();
    }
    if (expiresAt != null) {
      if (!expiresAt.toUtc().isAfter(DateTime.now().toUtc())) {
        throw const AssignedQuizException(
          code: AssignedQuizErrorCode.validationFailed,
          message: 'La scadenza deve essere nel futuro.',
        );
      }
      payload['expires_at'] = expiresAt.toUtc().toIso8601String();
    }
    if (payload.isEmpty) return;

    try {
      await _client
          .from('assigned_quizzes')
          .update(payload)
          .eq('id', assignmentId);
    } catch (error) {
      _rethrowMapped(error);
    }
  }

  @override
  Future<void> deleteDraft(String assignmentId) async {
    try {
      await _client
          .from('assigned_quizzes')
          .delete()
          .eq('id', assignmentId)
          .eq('status', AssignedQuizStatus.draft.dbValue);
    } catch (error) {
      _rethrowMapped(error);
    }
  }

  @override
  Future<List<AssignedQuizSummary>> loadMine() async {
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null || uid.isEmpty) {
        throw const AssignedQuizException(
          code: AssignedQuizErrorCode.notAuthenticated,
          message: 'Sessione non disponibile. Accedi nuovamente.',
        );
      }
      final res = await _client
          .from('assigned_quizzes')
          .select(_assignmentSelect)
          .eq('student_user_id', uid)
          .eq('status', AssignedQuizStatus.assigned.dbValue)
          .order('assigned_at', ascending: false);
      return (res as List<dynamic>)
          .map((row) => parseAssignedQuizSummary(requireAssignedQuizMap(row)))
          .toList(growable: false);
    } on AssignedQuizException {
      rethrow;
    } catch (error) {
      _rethrowMapped(error);
    }
  }

  @override
  Future<AssignedQuizAttemptStartResult> startOrResume(
    String assignmentId,
  ) async {
    return _rpcJsonb('start_assigned_quiz_attempt', {
      'p_assignment_id': assignmentId,
    }, parseAssignedQuizAttemptStartResult);
  }

  @override
  Future<List<AssignedQuizQuestion>> loadAttemptQuestions(
    String attemptId,
  ) async {
    return _rpcJsonb('get_assigned_quiz_attempt_questions', {
      'p_attempt_id': attemptId,
    }, parseAssignedQuizQuestionList);
  }

  @override
  Future<AssignedQuizAnswerSaveResult> saveAnswer({
    required String attemptId,
    required String assignmentItemId,
    required String? selectedOption,
  }) async {
    final normalized = normalizeAssignedQuizSelectedOption(selectedOption);
    return _rpcJsonb('save_assigned_quiz_attempt_answer', {
      'p_attempt_id': attemptId,
      'p_assignment_item_id': assignmentItemId,
      'p_selected_option': normalized,
    }, parseAssignedQuizAnswerSaveResult);
  }

  @override
  Future<AssignedQuizSubmitResult> submitAttempt(String attemptId) async {
    // Nessun punteggio / risposte nel payload: calcolo server-side.
    return _rpcJsonb('submit_assigned_quiz_attempt', {
      'p_attempt_id': attemptId,
    }, parseAssignedQuizSubmitResult);
  }

  @override
  Future<void> abandonAttempt(String attemptId) async {
    await _rpcJsonb('abandon_assigned_quiz_attempt', {
      'p_attempt_id': attemptId,
    }, requireAssignedQuizMap);
  }

  @override
  Future<List<AssignedQuizReviewItem>> loadAttemptReview(
    String attemptId,
  ) async {
    return _rpcJsonb('get_assigned_quiz_attempt_review', {
      'p_attempt_id': attemptId,
    }, parseAssignedQuizReviewList);
  }

  @override
  Future<List<AssignedQuizAttemptSummary>> loadAttempts(
    String assignmentId,
  ) async {
    try {
      final res = await _client
          .from('assigned_quiz_attempts')
          .select(_attemptSelect)
          .eq('assignment_id', assignmentId)
          .order('attempt_number', ascending: false);
      return (res as List<dynamic>)
          .map(
            (row) =>
                parseAssignedQuizAttemptSummary(requireAssignedQuizMap(row)),
          )
          .toList(growable: false);
    } catch (error) {
      _rethrowMapped(error);
    }
  }
}

/// Stub senza rete (Supabase non configurato).
class AssignedQuizRepositoryEmpty implements AssignedQuizRepository {
  const AssignedQuizRepositoryEmpty();

  @override
  Future<AssignedQuizGenerationResult> generateFromErrors(
    AssignedQuizGenerationRequest request,
  ) async {
    request.ensureValid();
    throw const AssignedQuizException(
      code: AssignedQuizErrorCode.notAuthenticated,
      message: 'Supabase non configurato.',
    );
  }

  @override
  Future<List<AssignedQuizSummary>> loadForStudent(String studentId) async =>
      const [];

  @override
  Future<void> archiveAssignment(String assignmentId) async {}

  @override
  Future<void> updateAssignmentMetadata(
    String assignmentId, {
    String? title,
    String? staffNote,
    DateTime? expiresAt,
  }) async {}

  @override
  Future<void> deleteDraft(String assignmentId) async {}

  @override
  Future<List<AssignedQuizSummary>> loadMine() async => const [];

  @override
  Future<AssignedQuizAttemptStartResult> startOrResume(
    String assignmentId,
  ) async {
    throw const AssignedQuizException(
      code: AssignedQuizErrorCode.notAuthenticated,
      message: 'Supabase non configurato.',
    );
  }

  @override
  Future<List<AssignedQuizQuestion>> loadAttemptQuestions(
    String attemptId,
  ) async => const [];

  @override
  Future<AssignedQuizAnswerSaveResult> saveAnswer({
    required String attemptId,
    required String assignmentItemId,
    required String? selectedOption,
  }) async {
    return AssignedQuizAnswerSaveResult(
      assignmentItemId: assignmentItemId,
      selectedOption: selectedOption,
      answeredAt: selectedOption == null ? null : DateTime.now().toUtc(),
    );
  }

  @override
  Future<AssignedQuizSubmitResult> submitAttempt(String attemptId) async {
    throw const AssignedQuizException(
      code: AssignedQuizErrorCode.notAuthenticated,
      message: 'Supabase non configurato.',
    );
  }

  @override
  Future<void> abandonAttempt(String attemptId) async {}

  @override
  Future<List<AssignedQuizReviewItem>> loadAttemptReview(
    String attemptId,
  ) async => const [];

  @override
  Future<List<AssignedQuizAttemptSummary>> loadAttempts(
    String assignmentId,
  ) async => const [];
}

/// Fake in-memory per test (nessuna rete, flussi principali prevedibili).
class AssignedQuizRepositoryFake implements AssignedQuizRepository {
  AssignedQuizRepositoryFake({
    this.generationResult,
    this.summaries = const [],
    this.startResult,
    this.questions = const [],
    this.reviewItems = const [],
    this.attempts = const [],
    this.throwOnGenerate,
  });

  AssignedQuizGenerationResult? generationResult;
  List<AssignedQuizSummary> summaries;
  AssignedQuizAttemptStartResult? startResult;
  List<AssignedQuizQuestion> questions;
  List<AssignedQuizReviewItem> reviewItems;
  List<AssignedQuizAttemptSummary> attempts;
  Object? throwOnGenerate;

  final List<String> rpcCalls = [];
  Map<String, dynamic>? lastGenerateParams;
  Map<String, dynamic>? lastSubmitParams;
  String? lastSavedOption;

  @override
  Future<AssignedQuizGenerationResult> generateFromErrors(
    AssignedQuizGenerationRequest request,
  ) async {
    lastGenerateParams = assignedQuizGenerateRpcParams(request);
    rpcCalls.add('generate_assigned_quiz_from_errors');
    if (throwOnGenerate != null) throw throwOnGenerate!;
    return generationResult ??
        AssignedQuizGenerationResult(
          assignmentId: 'assignment-1',
          publicCode: 'AQZ-2026-00001',
          itemCount: request.questionCount,
          status: request.assignImmediately
              ? AssignedQuizStatus.assigned
              : AssignedQuizStatus.draft,
          licenseCategory: 'A12',
        );
  }

  @override
  Future<List<AssignedQuizSummary>> loadForStudent(String studentId) async {
    return summaries
        .where((s) => s.studentId == studentId)
        .toList(growable: false);
  }

  @override
  Future<void> archiveAssignment(String assignmentId) async {
    summaries = summaries
        .map(
          (s) => s.id == assignmentId
              ? AssignedQuizSummary(
                  id: s.id,
                  publicCode: s.publicCode,
                  studentId: s.studentId,
                  studentUserId: s.studentUserId,
                  licenseCategory: s.licenseCategory,
                  title: s.title,
                  staffNote: s.staffNote,
                  status: AssignedQuizStatus.archived,
                  questionCount: s.questionCount,
                  repeatPolicy: s.repeatPolicy,
                  maxAttempts: s.maxAttempts,
                  createdAt: s.createdAt,
                  assignedAt: s.assignedAt,
                  expiresAt: s.expiresAt,
                  archivedAt: DateTime.now().toUtc(),
                )
              : s,
        )
        .toList(growable: false);
  }

  @override
  Future<void> updateAssignmentMetadata(
    String assignmentId, {
    String? title,
    String? staffNote,
    DateTime? expiresAt,
  }) async {}

  @override
  Future<void> deleteDraft(String assignmentId) async {
    summaries = summaries
        .where(
          (s) =>
              !(s.id == assignmentId && s.status == AssignedQuizStatus.draft),
        )
        .toList(growable: false);
  }

  @override
  Future<List<AssignedQuizSummary>> loadMine() async {
    return summaries
        .where((s) => s.status == AssignedQuizStatus.assigned)
        .toList(growable: false);
  }

  @override
  Future<AssignedQuizAttemptStartResult> startOrResume(
    String assignmentId,
  ) async {
    rpcCalls.add('start_assigned_quiz_attempt');
    return startResult ??
        AssignedQuizAttemptStartResult(
          attemptId: 'attempt-1',
          attemptNumber: 1,
          resumed: false,
          questionCount: questions.length,
          attemptsUsed: 1,
        );
  }

  @override
  Future<List<AssignedQuizQuestion>> loadAttemptQuestions(
    String attemptId,
  ) async {
    rpcCalls.add('get_assigned_quiz_attempt_questions');
    return questions;
  }

  @override
  Future<AssignedQuizAnswerSaveResult> saveAnswer({
    required String attemptId,
    required String assignmentItemId,
    required String? selectedOption,
  }) async {
    rpcCalls.add('save_assigned_quiz_attempt_answer');
    lastSavedOption = normalizeAssignedQuizSelectedOption(selectedOption);
    return AssignedQuizAnswerSaveResult(
      assignmentItemId: assignmentItemId,
      selectedOption: lastSavedOption,
      answeredAt: lastSavedOption == null ? null : DateTime.now().toUtc(),
    );
  }

  @override
  Future<AssignedQuizSubmitResult> submitAttempt(String attemptId) async {
    rpcCalls.add('submit_assigned_quiz_attempt');
    lastSubmitParams = {'p_attempt_id': attemptId};
    return AssignedQuizSubmitResult(
      attemptId: attemptId,
      attemptNumber: 1,
      correctCount: 1,
      wrongCount: 0,
      unansweredCount: 0,
      scorePercentage: 100,
      submittedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<void> abandonAttempt(String attemptId) async {
    rpcCalls.add('abandon_assigned_quiz_attempt');
  }

  @override
  Future<List<AssignedQuizReviewItem>> loadAttemptReview(
    String attemptId,
  ) async {
    rpcCalls.add('get_assigned_quiz_attempt_review');
    return reviewItems;
  }

  @override
  Future<List<AssignedQuizAttemptSummary>> loadAttempts(
    String assignmentId,
  ) async {
    return attempts
        .where((a) => a.assignmentId == assignmentId)
        .toList(growable: false);
  }
}

AssignedQuizRepository get assignedQuizRepository {
  if (SupabaseConfig.isConfigured) {
    return AssignedQuizRepositorySupabase();
  }
  return const AssignedQuizRepositoryEmpty();
}
