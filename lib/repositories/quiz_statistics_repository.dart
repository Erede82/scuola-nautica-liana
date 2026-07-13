import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../data/supabase/mappers/quiz_statistics_mapper.dart';
import '../data/supabase/quiz_attempt_history_data_source.dart';
import '../domain/quiz_license_category.dart';
import '../models/quiz_category_statistics.dart';
import '../models/license_models.dart';

/// Utente non autenticato: statistiche non consultabili.
class QuizStatisticsUnauthenticatedException implements Exception {
  const QuizStatisticsUnauthenticatedException();

  @override
  String toString() =>
      'QuizStatisticsUnauthenticatedException: utente non autenticato.';
}

/// Statistiche quiz reali (schede lezione) per area studente.
abstract class QuizStatisticsRepository {
  Future<QuizCategoryStatistics> fetchCategoryStatistics({
    required LicenseCategoryId categoryId,
  });
}

class QuizStatisticsRepositoryImpl implements QuizStatisticsRepository {
  QuizStatisticsRepositoryImpl({
    QuizAttemptHistoryDataSource? dataSource,
    Future<String?> Function()? resolveUserId,
  }) : _dataSource = dataSource ?? quizAttemptHistoryDataSource,
       _resolveUserId =
           resolveUserId ??
           (() async => SupabaseConfig.isConfigured
               ? Supabase.instance.client.auth.currentUser?.id
               : null);

  final QuizAttemptHistoryDataSource _dataSource;
  final Future<String?> Function() _resolveUserId;

  @override
  Future<QuizCategoryStatistics> fetchCategoryStatistics({
    required LicenseCategoryId categoryId,
  }) async {
    final dbCategory = dbLicenseCategoryFor(categoryId);
    if (dbCategory == null) {
      return QuizCategoryStatistics.empty(categoryId);
    }

    final userId = await _resolveUserId();
    if (userId == null || userId.isEmpty) {
      throw const QuizStatisticsUnauthenticatedException();
    }

    final rawResults = await _dataSource.fetchLessonResultsForCategory(
      userId: userId,
      licenseCategoryDb: dbCategory,
    );

    if (rawResults.isEmpty) {
      return QuizCategoryStatistics.empty(categoryId);
    }

    final answerCounts = await _dataSource.fetchAnswerCountsByResultIds(
      userId: userId,
      quizResultIds: rawResults.map((row) => row.id).toList(),
    );

    final partition = partitionStatisticsAttempts(
      rows: rawResults,
      answerCounts: answerCounts,
    );

    return buildQuizCategoryStatistics(
      categoryId: categoryId,
      results: partition.validResults,
      ignoredIncompleteAttempts: partition.ignoredIncompleteAttempts,
    );
  }
}

class QuizStatisticsRepositoryEmpty implements QuizStatisticsRepository {
  const QuizStatisticsRepositoryEmpty();

  @override
  Future<QuizCategoryStatistics> fetchCategoryStatistics({
    required LicenseCategoryId categoryId,
  }) async {
    return QuizCategoryStatistics.empty(categoryId);
  }
}

QuizStatisticsRepository get quizStatisticsRepository {
  if (SupabaseConfig.isConfigured) {
    return QuizStatisticsRepositoryImpl();
  }
  return const QuizStatisticsRepositoryEmpty();
}
