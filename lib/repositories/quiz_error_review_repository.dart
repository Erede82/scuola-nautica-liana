import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../data/supabase/mappers/quiz_error_review_mapper.dart';
import '../data/supabase/quiz_attempt_history_data_source.dart';
import '../domain/quiz_license_category.dart';
import '../models/license_models.dart';
import '../models/quiz_error_review_data.dart';

/// Utente non autenticato: ripasso errori non consultabile.
class QuizErrorReviewUnauthenticatedException implements Exception {
  const QuizErrorReviewUnauthenticatedException();

  @override
  String toString() =>
      'QuizErrorReviewUnauthenticatedException: utente non autenticato.';
}

/// Ripasso errori reale (schede lezione) per area studente — read-only.
abstract class QuizErrorReviewRepository {
  Future<QuizErrorReviewData> fetchCurrentUserErrors({
    required LicenseCategoryId categoryId,
    int? lessonNumber,
    QuizErrorReviewSort sort = QuizErrorReviewSort.recent,
    int? limit,
  });
}

class QuizErrorReviewRepositoryImpl implements QuizErrorReviewRepository {
  QuizErrorReviewRepositoryImpl({
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
  Future<QuizErrorReviewData> fetchCurrentUserErrors({
    required LicenseCategoryId categoryId,
    int? lessonNumber,
    QuizErrorReviewSort sort = QuizErrorReviewSort.recent,
    int? limit,
  }) async {
    final dbCategory = dbLicenseCategoryFor(categoryId);
    if (dbCategory == null) {
      return QuizErrorReviewData.empty(categoryId);
    }

    final userId = await _resolveUserId();
    if (userId == null || userId.isEmpty) {
      throw const QuizErrorReviewUnauthenticatedException();
    }

    final rawRows = await _dataSource.fetchWrongLessonAnswersForUser(
      userId: userId,
      licenseCategoryDb: dbCategory,
    );

    return buildQuizErrorReviewData(
      categoryId: categoryId,
      rows: rawRows,
      lessonNumber: lessonNumber,
      sort: sort,
      limit: limit,
    );
  }
}

class QuizErrorReviewRepositoryEmpty implements QuizErrorReviewRepository {
  const QuizErrorReviewRepositoryEmpty();

  @override
  Future<QuizErrorReviewData> fetchCurrentUserErrors({
    required LicenseCategoryId categoryId,
    int? lessonNumber,
    QuizErrorReviewSort sort = QuizErrorReviewSort.recent,
    int? limit,
  }) async {
    return QuizErrorReviewData.empty(categoryId);
  }
}

QuizErrorReviewRepository get quizErrorReviewRepository {
  if (SupabaseConfig.isConfigured) {
    return QuizErrorReviewRepositoryImpl();
  }
  return const QuizErrorReviewRepositoryEmpty();
}
