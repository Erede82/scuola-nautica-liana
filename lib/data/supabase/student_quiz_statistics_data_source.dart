import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/supabase_config.dart';
import '../../repositories/multi_topic_quiz_attempt_repository.dart'
    show multiTopicQuizAttemptAnswersTable, multiTopicQuizAttemptsTable;
import 'dto/quiz_result_row.dart';
import 'dto/quiz_sheet_catalog_row.dart';
import 'quiz_attempt_history_data_source.dart';
import 'supabase_select_pagination.dart';

/// Riga answer Multischeda per statistiche (snapshot lezione).
class MultiTopicStatsAnswerRow {
  const MultiTopicStatsAnswerRow({
    required this.attemptId,
    required this.lessonNumberSnapshot,
    required this.isCorrect,
    required this.isUnanswered,
  });

  final String attemptId;
  final int? lessonNumberSnapshot;
  final bool isCorrect;
  final bool isUnanswered;
}

/// Riga answer Esame per mapping question → lesson.
class ExamStatsAnswerRow {
  const ExamStatsAnswerRow({
    required this.attemptId,
    required this.questionId,
    required this.isCorrect,
    required this.isUnanswered,
  });

  final String attemptId;
  final String questionId;
  final bool isCorrect;
  final bool isUnanswered;
}

/// Header Multischeda light per stats.
class MultiTopicStatsAttemptRow {
  const MultiTopicStatsAttemptRow({
    required this.id,
    required this.userId,
    required this.licenseCategory,
    required this.sessionId,
    required this.sheetIndex,
    required this.completedAt,
    required this.totalQuestions,
    required this.correctCount,
    required this.wrongCount,
    required this.unansweredCount,
  });

  final String id;
  final String userId;
  final String licenseCategory;
  final String sessionId;
  final int sheetIndex;
  final DateTime completedAt;
  final int totalQuestions;
  final int correctCount;
  final int wrongCount;
  final int unansweredCount;
}

/// Header Esame light per stats.
class ExamStatsAttemptRow {
  const ExamStatsAttemptRow({
    required this.id,
    required this.userId,
    required this.licenseCategory,
    required this.completedAt,
    required this.totalQuestions,
    required this.correctCount,
    required this.wrongCount,
    required this.unansweredCount,
    required this.passed,
  });

  final String id;
  final String userId;
  final String licenseCategory;
  final DateTime completedAt;
  final int totalQuestions;
  final int correctCount;
  final int wrongCount;
  final int unansweredCount;
  final bool passed;
}

/// Letture dedicate STUDENT.STATS.1 (solo SELECT, RLS).
abstract class StudentQuizStatisticsDataSource {
  Future<List<QuizSheetCatalogRow>> fetchLessonSheetCatalog({
    required String licenseCategoryDb,
  });

  Future<List<QuizResultRow>> fetchLessonResultsForCategory({
    required String userId,
    required String licenseCategoryDb,
  });

  Future<Map<String, int>> fetchAnswerCountsByResultIds({
    required String userId,
    required List<String> quizResultIds,
  });

  Future<List<MultiTopicStatsAttemptRow>> fetchMultiTopicAttempts({
    required String userId,
    required String licenseCategoryDb,
  });

  Future<List<MultiTopicStatsAnswerRow>> fetchMultiTopicAnswers({
    required List<String> attemptIds,
  });

  Future<List<ExamStatsAttemptRow>> fetchExamAttempts({
    required String userId,
    required String licenseCategoryDb,
  });

  Future<List<ExamStatsAnswerRow>> fetchExamAnswers({
    required List<String> attemptIds,
  });

  Future<Map<String, int?>> fetchQuestionLessonNumbers({
    required List<String> questionIds,
  });
}

class StudentQuizStatisticsDataSourceSupabase
    implements StudentQuizStatisticsDataSource {
  StudentQuizStatisticsDataSourceSupabase({
    QuizAttemptHistoryDataSource? lessonHistory,
    SupabaseClient? client,
  }) : _lessonHistory = lessonHistory ?? quizAttemptHistoryDataSource,
       _clientOverride = client;

  final QuizAttemptHistoryDataSource _lessonHistory;
  final SupabaseClient? _clientOverride;

  /// Quanti id per clausola IN.
  ///
  /// Le righe di ogni chunk vanno comunque paginate: 100 schede × 20 risposte
  /// (A12) superano il tetto silenzioso PostgREST (1000). Senza `.range()` il
  /// repository scarta le schede complete perché il conteggio risposte non
  /// torna con `total_questions`.
  static const int _chunkSize = 100;

  SupabaseClient get _client {
    final override = _clientOverride;
    if (override != null) return override;
    if (!SupabaseConfig.isConfigured) {
      throw StateError('Supabase non inizializzato.');
    }
    return Supabase.instance.client;
  }

  @override
  Future<List<QuizSheetCatalogRow>> fetchLessonSheetCatalog({
    required String licenseCategoryDb,
  }) {
    return _lessonHistory.fetchLessonSheetCatalog(
      licenseCategoryDb: licenseCategoryDb,
    );
  }

  @override
  Future<List<QuizResultRow>> fetchLessonResultsForCategory({
    required String userId,
    required String licenseCategoryDb,
  }) {
    return _lessonHistory.fetchLessonResultsForCategory(
      userId: userId,
      licenseCategoryDb: licenseCategoryDb,
    );
  }

  @override
  Future<Map<String, int>> fetchAnswerCountsByResultIds({
    required String userId,
    required List<String> quizResultIds,
  }) async {
    if (quizResultIds.isEmpty) return const {};

    // Non delegare alla history non paginata: 100 result id × ~20 risposte
    // vengono troncate a 1000 e le schede complete risultano incomplete.
    final counts = <String, int>{};
    for (var offset = 0; offset < quizResultIds.length; offset += _chunkSize) {
      final end = math.min(offset + _chunkSize, quizResultIds.length);
      final chunk = quizResultIds.sublist(offset, end);
      final res = await fetchAllSupabasePages((from, to) {
        return _client
            .from('quiz_attempt_answers')
            .select('id, quiz_result_id')
            .eq('user_id', userId)
            .inFilter('quiz_result_id', chunk)
            .order('id')
            .range(from, to);
      });
      for (final item in res) {
        if (item is! Map) continue;
        final resultId = item['quiz_result_id']?.toString();
        if (resultId == null || resultId.isEmpty) continue;
        counts[resultId] = (counts[resultId] ?? 0) + 1;
      }
    }
    return counts;
  }

  @override
  Future<List<MultiTopicStatsAttemptRow>> fetchMultiTopicAttempts({
    required String userId,
    required String licenseCategoryDb,
  }) async {
    final res = await fetchAllSupabasePages((from, to) {
      return _client
          .from(multiTopicQuizAttemptsTable)
          .select(
            'id, user_id, license_category, session_id, sheet_index, '
            'completed_at, total_questions, correct_count, wrong_count, '
            'unanswered_count',
          )
          .eq('user_id', userId)
          .eq('license_category', licenseCategoryDb)
          .order('completed_at', ascending: false)
          .order('id', ascending: false)
          .range(from, to);
    });

    final rows = <MultiTopicStatsAttemptRow>[];
    for (final item in res) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final id = map['id']?.toString().trim() ?? '';
      final rowUserId = map['user_id']?.toString().trim() ?? '';
      final category = map['license_category']?.toString().trim() ?? '';
      final sessionId = map['session_id']?.toString().trim() ?? '';
      final completedAt = _parseTs(map['completed_at']);
      if (id.isEmpty ||
          rowUserId.isEmpty ||
          sessionId.isEmpty ||
          completedAt == null) {
        continue;
      }
      rows.add(
        MultiTopicStatsAttemptRow(
          id: id,
          userId: rowUserId,
          licenseCategory: category,
          sessionId: sessionId,
          sheetIndex: (map['sheet_index'] as num?)?.toInt() ?? 0,
          completedAt: completedAt,
          totalQuestions: (map['total_questions'] as num?)?.toInt() ?? 0,
          correctCount: (map['correct_count'] as num?)?.toInt() ?? 0,
          wrongCount: (map['wrong_count'] as num?)?.toInt() ?? 0,
          unansweredCount: (map['unanswered_count'] as num?)?.toInt() ?? 0,
        ),
      );
    }
    return rows;
  }

  @override
  Future<List<MultiTopicStatsAnswerRow>> fetchMultiTopicAnswers({
    required List<String> attemptIds,
  }) async {
    if (attemptIds.isEmpty) return const [];
    final out = <MultiTopicStatsAnswerRow>[];
    for (var offset = 0; offset < attemptIds.length; offset += _chunkSize) {
      final end = math.min(offset + _chunkSize, attemptIds.length);
      final chunk = attemptIds.sublist(offset, end);
      final res = await fetchAllSupabasePages((from, to) {
        return _client
            .from(multiTopicQuizAttemptAnswersTable)
            .select(
              'id, attempt_id, lesson_number_snapshot, is_correct, '
              'selected_option',
            )
            .inFilter('attempt_id', chunk)
            .order('id')
            .range(from, to);
      });
      for (final item in res) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final attemptId = map['attempt_id']?.toString().trim() ?? '';
        if (attemptId.isEmpty) continue;
        final selected = map['selected_option'];
        final isUnanswered = selected == null ||
            (selected is String && selected.trim().isEmpty);
        final lessonRaw = map['lesson_number_snapshot'];
        final lesson = lessonRaw == null ? null : (lessonRaw as num?)?.toInt();
        out.add(
          MultiTopicStatsAnswerRow(
            attemptId: attemptId,
            lessonNumberSnapshot: (lesson != null && lesson > 0) ? lesson : null,
            isCorrect: map['is_correct'] == true,
            isUnanswered: isUnanswered,
          ),
        );
      }
    }
    return out;
  }

  @override
  Future<List<ExamStatsAttemptRow>> fetchExamAttempts({
    required String userId,
    required String licenseCategoryDb,
  }) async {
    final res = await fetchAllSupabasePages((from, to) {
      return _client
          .from('exam_quiz_attempts')
          .select(
            'id, user_id, license_category, completed_at, total_questions, '
            'correct_count, wrong_count, unanswered_count, passed',
          )
          .eq('user_id', userId)
          .eq('license_category', licenseCategoryDb)
          .order('completed_at', ascending: false)
          .order('id', ascending: false)
          .range(from, to);
    });

    final rows = <ExamStatsAttemptRow>[];
    for (final item in res) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final id = map['id']?.toString().trim() ?? '';
      final rowUserId = map['user_id']?.toString().trim() ?? '';
      final category = map['license_category']?.toString().trim() ?? '';
      final completedAt = _parseTs(map['completed_at']);
      if (id.isEmpty || rowUserId.isEmpty || completedAt == null) continue;
      rows.add(
        ExamStatsAttemptRow(
          id: id,
          userId: rowUserId,
          licenseCategory: category,
          completedAt: completedAt,
          totalQuestions: (map['total_questions'] as num?)?.toInt() ?? 0,
          correctCount: (map['correct_count'] as num?)?.toInt() ?? 0,
          wrongCount: (map['wrong_count'] as num?)?.toInt() ?? 0,
          unansweredCount: (map['unanswered_count'] as num?)?.toInt() ?? 0,
          passed: map['passed'] == true,
        ),
      );
    }
    return rows;
  }

  @override
  Future<List<ExamStatsAnswerRow>> fetchExamAnswers({
    required List<String> attemptIds,
  }) async {
    if (attemptIds.isEmpty) return const [];
    final out = <ExamStatsAnswerRow>[];
    for (var offset = 0; offset < attemptIds.length; offset += _chunkSize) {
      final end = math.min(offset + _chunkSize, attemptIds.length);
      final chunk = attemptIds.sublist(offset, end);
      final res = await fetchAllSupabasePages((from, to) {
        return _client
            .from('exam_quiz_attempt_answers')
            .select(
              'id, attempt_id, question_id, is_correct, selected_option',
            )
            .inFilter('attempt_id', chunk)
            .order('id')
            .range(from, to);
      });
      for (final item in res) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final attemptId = map['attempt_id']?.toString().trim() ?? '';
        final questionId = map['question_id']?.toString().trim() ?? '';
        if (attemptId.isEmpty || questionId.isEmpty) continue;
        final selected = map['selected_option'];
        final isUnanswered = selected == null ||
            (selected is String && selected.trim().isEmpty);
        out.add(
          ExamStatsAnswerRow(
            attemptId: attemptId,
            questionId: questionId,
            isCorrect: map['is_correct'] == true,
            isUnanswered: isUnanswered,
          ),
        );
      }
    }
    return out;
  }

  @override
  Future<Map<String, int?>> fetchQuestionLessonNumbers({
    required List<String> questionIds,
  }) async {
    if (questionIds.isEmpty) return const {};
    final out = <String, int?>{};
    for (var offset = 0; offset < questionIds.length; offset += _chunkSize) {
      final end = math.min(offset + _chunkSize, questionIds.length);
      final chunk = questionIds.sublist(offset, end);
      final res = await _client
          .from('questions')
          .select('id, lesson_number')
          .inFilter('id', chunk);
      for (final item in res as List<dynamic>) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final id = map['id']?.toString().trim() ?? '';
        if (id.isEmpty) continue;
        final raw = map['lesson_number'];
        if (raw == null) {
          out[id] = null;
        } else {
          final n = (raw as num?)?.toInt();
          out[id] = (n != null && n > 0) ? n : null;
        }
      }
    }
    return out;
  }
}

DateTime? _parseTs(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

/// Fake in-memory per test repository senza rete.
class StudentQuizStatisticsDataSourceFake
    implements StudentQuizStatisticsDataSource {
  StudentQuizStatisticsDataSourceFake({
    this.catalog = const [],
    this.lessonResults = const [],
    this.answerCounts = const {},
    this.multiAttempts = const [],
    this.multiAnswers = const [],
    this.examAttempts = const [],
    this.examAnswers = const [],
    this.questionLessonNumbers = const {},
    this.multiFetchError,
    this.examFetchError,
  });

  List<QuizSheetCatalogRow> catalog;
  List<QuizResultRow> lessonResults;
  Map<String, int> answerCounts;
  List<MultiTopicStatsAttemptRow> multiAttempts;
  List<MultiTopicStatsAnswerRow> multiAnswers;
  List<ExamStatsAttemptRow> examAttempts;
  List<ExamStatsAnswerRow> examAnswers;
  Map<String, int?> questionLessonNumbers;

  /// Ultimi argomenti ricevuti (per assert propagazione repository → DS).
  String? lastMultiUserId;
  String? lastMultiLicenseCategoryDb;
  String? lastExamUserId;
  String? lastExamLicenseCategoryDb;

  Object? multiFetchError;
  Object? examFetchError;

  @override
  Future<List<QuizSheetCatalogRow>> fetchLessonSheetCatalog({
    required String licenseCategoryDb,
  }) async =>
      catalog
          .where((r) => r.licenseCategory == licenseCategoryDb)
          .toList(growable: false);

  @override
  Future<List<QuizResultRow>> fetchLessonResultsForCategory({
    required String userId,
    required String licenseCategoryDb,
  }) async =>
      lessonResults
          .where((r) => r.licenseCategory == licenseCategoryDb)
          .toList(growable: false);

  @override
  Future<Map<String, int>> fetchAnswerCountsByResultIds({
    required String userId,
    required List<String> quizResultIds,
  }) async {
    final out = <String, int>{};
    for (final id in quizResultIds) {
      final c = answerCounts[id];
      if (c != null) out[id] = c;
    }
    return out;
  }

  @override
  Future<List<MultiTopicStatsAttemptRow>> fetchMultiTopicAttempts({
    required String userId,
    required String licenseCategoryDb,
  }) async {
    lastMultiUserId = userId;
    lastMultiLicenseCategoryDb = licenseCategoryDb;
    if (multiFetchError != null) throw multiFetchError!;
    return multiAttempts
        .where(
          (a) =>
              a.userId == userId && a.licenseCategory == licenseCategoryDb,
        )
        .toList(growable: false);
  }

  @override
  Future<List<MultiTopicStatsAnswerRow>> fetchMultiTopicAnswers({
    required List<String> attemptIds,
  }) async {
    final ids = attemptIds.toSet();
    return multiAnswers
        .where((a) => ids.contains(a.attemptId))
        .toList(growable: false);
  }

  @override
  Future<List<ExamStatsAttemptRow>> fetchExamAttempts({
    required String userId,
    required String licenseCategoryDb,
  }) async {
    lastExamUserId = userId;
    lastExamLicenseCategoryDb = licenseCategoryDb;
    if (examFetchError != null) throw examFetchError!;
    return examAttempts
        .where(
          (a) =>
              a.userId == userId && a.licenseCategory == licenseCategoryDb,
        )
        .toList(growable: false);
  }

  @override
  Future<List<ExamStatsAnswerRow>> fetchExamAnswers({
    required List<String> attemptIds,
  }) async {
    final ids = attemptIds.toSet();
    return examAnswers
        .where((a) => ids.contains(a.attemptId))
        .toList(growable: false);
  }

  @override
  Future<Map<String, int?>> fetchQuestionLessonNumbers({
    required List<String> questionIds,
  }) async {
    final out = <String, int?>{};
    for (final id in questionIds) {
      if (questionLessonNumbers.containsKey(id)) {
        out[id] = questionLessonNumbers[id];
      }
    }
    return out;
  }
}
