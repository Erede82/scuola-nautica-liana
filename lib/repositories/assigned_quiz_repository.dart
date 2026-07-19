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
    String assignmentId,
    AssignedQuizMetadataPatch patch,
  );

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

  AssignedQuizSummary _withInProgressState(
    AssignedQuizSummary summary, {
    required bool hasInProgressAttempt,
  }) {
    return AssignedQuizSummary(
      id: summary.id,
      publicCode: summary.publicCode,
      studentId: summary.studentId,
      studentUserId: summary.studentUserId,
      licenseCategory: summary.licenseCategory,
      title: summary.title,
      staffNote: summary.staffNote,
      status: summary.status,
      questionCount: summary.questionCount,
      repeatPolicy: summary.repeatPolicy,
      maxAttempts: summary.maxAttempts,
      createdAt: summary.createdAt,
      assignedAt: summary.assignedAt,
      expiresAt: summary.expiresAt,
      archivedAt: summary.archivedAt,
      attemptsCount: summary.attemptsCount,
      submittedAttemptsCount: summary.submittedAttemptsCount,
      latestAttemptAt: summary.latestAttemptAt,
      bestScorePercentage: summary.bestScorePercentage,
      averageScorePercentage: summary.averageScorePercentage,
      hasInProgressAttempt: hasInProgressAttempt,
    );
  }

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
    String assignmentId,
    AssignedQuizMetadataPatch patch,
  ) async {
    final payload = patch.toUpdatePayload();
    try {
      await _client
          .from('assigned_quizzes')
          .update(payload)
          .eq('id', assignmentId);
    } on AssignedQuizException {
      rethrow;
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
      // Student headers come from a server-side safe projection: direct table
      // reads would also expose staff_note because RLS cannot hide columns.
      final res = await _client.rpc('list_my_assigned_quizzes');

      final inProgressRes = await _client
          .from('assigned_quiz_attempts')
          .select('assignment_id')
          .eq('user_id', uid)
          .eq('status', AssignedQuizAttemptStatus.inProgress.dbValue);
      final inProgressAssignmentIds = (inProgressRes as List<dynamic>)
          .map(
            (row) =>
                requireAssignedQuizMap(row)['assignment_id']?.toString() ?? '',
          )
          .where((id) => id.isNotEmpty)
          .toSet();

      return (res as List<dynamic>)
          .map((row) => parseAssignedQuizSummary(requireAssignedQuizMap(row)))
          .where(
            (summary) =>
                summary.status == AssignedQuizStatus.assigned ||
                inProgressAssignmentIds.contains(summary.id),
          )
          .map(
            (summary) => _withInProgressState(
              summary,
              hasInProgressAttempt: inProgressAssignmentIds.contains(
                summary.id,
              ),
            ),
          )
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
    }, requireAssignedQuizSingleJsonb);
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
///
/// Le letture restano vuote; le scritture falliscono esplicitamente.
class AssignedQuizRepositoryEmpty implements AssignedQuizRepository {
  const AssignedQuizRepositoryEmpty();

  static const _unconfigured = AssignedQuizException(
    code: AssignedQuizErrorCode.notAuthenticated,
    message: 'Supabase non configurato.',
  );

  Never _rejectWrite() => throw _unconfigured;

  @override
  Future<AssignedQuizGenerationResult> generateFromErrors(
    AssignedQuizGenerationRequest request,
  ) async {
    request.ensureValid();
    _rejectWrite();
  }

  @override
  Future<List<AssignedQuizSummary>> loadForStudent(String studentId) async =>
      const [];

  @override
  Future<void> archiveAssignment(String assignmentId) async => _rejectWrite();

  @override
  Future<void> updateAssignmentMetadata(
    String assignmentId,
    AssignedQuizMetadataPatch patch,
  ) async {
    patch.toUpdatePayload();
    _rejectWrite();
  }

  @override
  Future<void> deleteDraft(String assignmentId) async => _rejectWrite();

  @override
  Future<List<AssignedQuizSummary>> loadMine() async => const [];

  @override
  Future<AssignedQuizAttemptStartResult> startOrResume(
    String assignmentId,
  ) async => _rejectWrite();

  @override
  Future<List<AssignedQuizQuestion>> loadAttemptQuestions(
    String attemptId,
  ) async => const [];

  @override
  Future<AssignedQuizAnswerSaveResult> saveAnswer({
    required String attemptId,
    required String assignmentItemId,
    required String? selectedOption,
  }) async => _rejectWrite();

  @override
  Future<AssignedQuizSubmitResult> submitAttempt(String attemptId) async =>
      _rejectWrite();

  @override
  Future<void> abandonAttempt(String attemptId) async => _rejectWrite();

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
    this.throwOnStart,
    this.throwOnSave,
    this.throwOnSubmit,
    this.throwOnAbandon,
    this.throwOnReview,
    this.throwOnLoadMine,
    this.loadDelay = Duration.zero,
    this.saveDelay = Duration.zero,
    this.saveDelays = const [],
    this.submitResult,
  });

  AssignedQuizGenerationResult? generationResult;
  List<AssignedQuizSummary> summaries;
  AssignedQuizAttemptStartResult? startResult;
  List<AssignedQuizQuestion> questions;
  List<AssignedQuizReviewItem> reviewItems;
  List<AssignedQuizAttemptSummary> attempts;
  Object? throwOnGenerate;
  Object? throwOnStart;
  Object? throwOnSave;
  Object? throwOnSubmit;
  Object? throwOnAbandon;
  Object? throwOnReview;
  Object? throwOnLoadMine;
  Duration loadDelay;
  Duration saveDelay;
  List<Duration> saveDelays;
  AssignedQuizSubmitResult? submitResult;
  int _saveInvocationCount = 0;

  final List<String> rpcCalls = [];
  Map<String, dynamic>? lastGenerateParams;
  Map<String, dynamic>? lastSubmitParams;
  String? lastSavedOption;
  AssignedQuizMetadataPatch? lastMetadataPatch;
  int loadForStudentCalls = 0;
  int loadMineCalls = 0;
  int startOrResumeCalls = 0;
  int submitCalls = 0;
  int abandonCalls = 0;
  final List<String> loadAttemptsCalls = [];
  final List<Map<String, dynamic>> saveCalls = [];
  String? lastStartAssignmentId;

  @override
  Future<AssignedQuizGenerationResult> generateFromErrors(
    AssignedQuizGenerationRequest request,
  ) async {
    lastGenerateParams = assignedQuizGenerateRpcParams(request);
    rpcCalls.add('generate_assigned_quiz_from_errors');
    if (throwOnGenerate != null) throw throwOnGenerate!;
    final result =
        generationResult ??
        AssignedQuizGenerationResult(
          assignmentId: 'assignment-${summaries.length + 1}',
          publicCode:
              'AQZ-2026-${(summaries.length + 1).toString().padLeft(5, '0')}',
          itemCount: request.questionCount,
          status: request.assignImmediately
              ? AssignedQuizStatus.assigned
              : AssignedQuizStatus.draft,
          licenseCategory: 'A12',
        );
    final now = DateTime.now().toUtc();
    summaries = [
      AssignedQuizSummary(
        id: result.assignmentId,
        publicCode: result.publicCode,
        studentId: request.studentId,
        studentUserId: 'user-1',
        licenseCategory: result.licenseCategory,
        title: request.title.trim(),
        staffNote: request.staffNote,
        status: result.status,
        questionCount: result.itemCount,
        repeatPolicy: request.repeatPolicy,
        maxAttempts: request.maxAttempts,
        createdAt: now,
        assignedAt: result.status == AssignedQuizStatus.assigned ? now : null,
        expiresAt: request.expiresAt,
      ),
      ...summaries,
    ];
    return result;
  }

  @override
  Future<List<AssignedQuizSummary>> loadForStudent(String studentId) async {
    loadForStudentCalls += 1;
    if (loadDelay > Duration.zero) {
      await Future<void>.delayed(loadDelay);
    }
    return summaries
        .where((s) => s.studentId == studentId)
        .toList(growable: false);
  }

  @override
  Future<void> archiveAssignment(String assignmentId) async {
    rpcCalls.add('archive');
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
    String assignmentId,
    AssignedQuizMetadataPatch patch,
  ) async {
    lastMetadataPatch = patch;
    final payload = patch.toUpdatePayload();
    rpcCalls.add('update_metadata');
    summaries = summaries
        .map((s) {
          if (s.id != assignmentId) return s;
          return AssignedQuizSummary(
            id: s.id,
            publicCode: s.publicCode,
            studentId: s.studentId,
            studentUserId: s.studentUserId,
            licenseCategory: s.licenseCategory,
            title: payload.containsKey('title')
                ? payload['title'] as String
                : s.title,
            staffNote: payload.containsKey('staff_note')
                ? payload['staff_note'] as String?
                : s.staffNote,
            status: s.status,
            questionCount: s.questionCount,
            repeatPolicy: s.repeatPolicy,
            maxAttempts: s.maxAttempts,
            createdAt: s.createdAt,
            assignedAt: s.assignedAt,
            expiresAt: payload.containsKey('expires_at')
                ? parseAssignedQuizDateTime(payload['expires_at'])
                : s.expiresAt,
            archivedAt: s.archivedAt,
            attemptsCount: s.attemptsCount,
            submittedAttemptsCount: s.submittedAttemptsCount,
            latestAttemptAt: s.latestAttemptAt,
            bestScorePercentage: s.bestScorePercentage,
            averageScorePercentage: s.averageScorePercentage,
            hasInProgressAttempt: s.hasInProgressAttempt,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<void> deleteDraft(String assignmentId) async {
    rpcCalls.add('delete_draft');
    final before = summaries.length;
    summaries = summaries
        .where(
          (s) =>
              !(s.id == assignmentId && s.status == AssignedQuizStatus.draft),
        )
        .toList(growable: false);
    if (summaries.length == before) {
      throw AssignedQuizException(
        code: AssignedQuizErrorCode.assignedQuizDeleteNotAllowed,
        message: assignedQuizErrorMessageIt(
          AssignedQuizErrorCode.assignedQuizDeleteNotAllowed,
        ),
      );
    }
  }

  @override
  Future<List<AssignedQuizSummary>> loadMine() async {
    loadMineCalls += 1;
    if (loadDelay > Duration.zero) {
      await Future<void>.delayed(loadDelay);
    }
    if (throwOnLoadMine != null) throw throwOnLoadMine!;
    return summaries
        .where(
          (s) =>
              s.status == AssignedQuizStatus.assigned ||
              (s.status == AssignedQuizStatus.archived &&
                  s.hasInProgressAttempt == true),
        )
        .toList(growable: false);
  }

  @override
  Future<AssignedQuizAttemptStartResult> startOrResume(
    String assignmentId,
  ) async {
    startOrResumeCalls += 1;
    lastStartAssignmentId = assignmentId;
    rpcCalls.add('start_assigned_quiz_attempt');
    if (throwOnStart != null) throw throwOnStart!;
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
    final invocation = _saveInvocationCount++;
    final delay = invocation < saveDelays.length
        ? saveDelays[invocation]
        : saveDelay;
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    if (throwOnSave != null) throw throwOnSave!;
    lastSavedOption = normalizeAssignedQuizSelectedOption(selectedOption);
    saveCalls.add({
      'attemptId': attemptId,
      'assignmentItemId': assignmentItemId,
      'selectedOption': lastSavedOption,
    });
    questions = questions
        .map(
          (q) => q.assignmentItemId == assignmentItemId
              ? AssignedQuizQuestion(
                  assignmentItemId: q.assignmentItemId,
                  position: q.position,
                  prompt: q.prompt,
                  optionA: q.optionA,
                  optionB: q.optionB,
                  optionC: q.optionC,
                  imagePath: q.imagePath,
                  lessonNumber: q.lessonNumber,
                  selectedOption: lastSavedOption,
                )
              : q,
        )
        .toList(growable: false);
    return AssignedQuizAnswerSaveResult(
      assignmentItemId: assignmentItemId,
      selectedOption: lastSavedOption,
      answeredAt: lastSavedOption == null ? null : DateTime.now().toUtc(),
    );
  }

  @override
  Future<AssignedQuizSubmitResult> submitAttempt(String attemptId) async {
    submitCalls += 1;
    rpcCalls.add('submit_assigned_quiz_attempt');
    lastSubmitParams = {'p_attempt_id': attemptId};
    if (throwOnSubmit != null) throw throwOnSubmit!;
    return submitResult ??
        AssignedQuizSubmitResult(
          attemptId: attemptId,
          attemptNumber: startResult?.attemptNumber ?? 1,
          correctCount: 1,
          wrongCount: 0,
          unansweredCount: 0,
          scorePercentage: 100,
          submittedAt: DateTime.now().toUtc(),
        );
  }

  @override
  Future<void> abandonAttempt(String attemptId) async {
    abandonCalls += 1;
    rpcCalls.add('abandon_assigned_quiz_attempt');
    if (throwOnAbandon != null) throw throwOnAbandon!;
  }

  @override
  Future<List<AssignedQuizReviewItem>> loadAttemptReview(
    String attemptId,
  ) async {
    rpcCalls.add('get_assigned_quiz_attempt_review');
    if (throwOnReview != null) throw throwOnReview!;
    return reviewItems;
  }

  @override
  Future<List<AssignedQuizAttemptSummary>> loadAttempts(
    String assignmentId,
  ) async {
    loadAttemptsCalls.add(assignmentId);
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
