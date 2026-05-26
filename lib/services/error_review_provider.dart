import '../constants/extra_content_ids.dart';
import '../data/lesson_quiz_performance_mock.dart';
import '../models/error_review_recommendation.dart';
import '../models/lesson_quiz_performance_snapshot.dart';
import '../models/license_models.dart';
import '../repositories/study_access_repository.dart';

/// Costruisce i suggerimenti “Ripasso errori” a partire dagli snapshot performance.
///
/// Sostituibile in futuro con implementazione che legge quiz reali / Supabase,
/// mantenendo [buildViewData] come entry point della UI.
abstract final class ErrorReviewProvider {
  /// Lezioni “deboli” candidate al ripasso — stessa logica delle raccomandazioni (per UI admin).
  static List<LessonQuizPerformanceSnapshot> weakSnapshotsForCategory(
    LicenseCategoryId categoryId,
  ) {
    final snapshots = LessonQuizPerformanceMock.snapshotsFor(categoryId);
    final withActivity =
        snapshots.where((s) => s.totalAttempts > 0).toList(growable: false);
    if (withActivity.isEmpty) return [];

    final threshold = LessonQuizPerformanceMock.attentionThresholdPercent;
    final weak = withActivity
        .where((s) => s.averageErrorPercentage >= threshold)
        .toList(growable: false);
    weak.sort(
      (a, b) => b.averageErrorPercentage.compareTo(a.averageErrorPercentage),
    );
    return weak;
  }

  static ErrorReviewViewData buildViewData(LicenseCategoryId categoryId) {
    final snapshots = LessonQuizPerformanceMock.snapshotsFor(categoryId);
    final withActivity =
        snapshots.where((s) => s.totalAttempts > 0).toList(growable: false);

    final totalAttempts =
        withActivity.fold<int>(0, (sum, s) => sum + s.totalAttempts);

    if (withActivity.isEmpty) {
      return ErrorReviewViewData(
        categoryId: categoryId,
        totalAttemptsAcrossLessons: 0,
        recommendations: const [],
        emptyKind: ErrorReviewEmptyKind.noQuizData,
      );
    }

    final threshold = LessonQuizPerformanceMock.attentionThresholdPercent;
    final weak = withActivity
        .where((s) => s.averageErrorPercentage >= threshold)
        .toList(growable: false);

    if (weak.isEmpty) {
      return ErrorReviewViewData(
        categoryId: categoryId,
        totalAttemptsAcrossLessons: totalAttempts,
        recommendations: const [],
        emptyKind: ErrorReviewEmptyKind.allClear,
      );
    }

    weak.sort(
      (a, b) => b.averageErrorPercentage.compareTo(a.averageErrorPercentage),
    );

    final items =
        weak.map((s) => _fromSnapshot(s, studyAccessRepository)).toList(growable: false);

    return ErrorReviewViewData(
      categoryId: categoryId,
      totalAttemptsAcrossLessons: totalAttempts,
      recommendations: items,
      emptyKind: null,
    );
  }

  static ErrorReviewRecommendation _fromSnapshot(
    LessonQuizPerformanceSnapshot s,
    StudyAccessRepository access,
  ) {
    final priority = _priorityFor(s.averageErrorPercentage);
    final cta = _ctaFor(priority);
    final school = access.errorReviewTopic(
      categoryId: s.categoryId,
      lessonNumber: s.lessonNumber,
    );

    return ErrorReviewRecommendation(
      lessonNumber: s.lessonNumber,
      lessonTitle: s.lessonTitle,
      averageErrorPercentage: s.averageErrorPercentage,
      recommendationTitle:
          'Ripassa: ${s.lessonTitle.replaceFirst(RegExp(r'^\d+\.\s*'), '')}',
      recommendationMessage: _messageFor(s, priority),
      priority: priority,
      linkedCategory: s.categoryId,
      linkedExtraContentId: ExtraContentIds.ripassoErrori,
      linkedQuizSectionId: 'lesson:${s.lessonNumber}',
      ctaLabel: cta.$1,
      ctaKind: cta.$2,
      isSchoolUnlocked: school.isUnlocked,
      schoolLockMessage: school.lockedMessage ?? '',
    );
  }

  static ErrorReviewPriority _priorityFor(double errorPct) {
    if (errorPct >= 35) return ErrorReviewPriority.high;
    if (errorPct >= 22) return ErrorReviewPriority.medium;
    return ErrorReviewPriority.low;
  }

  static (String, ErrorReviewCtaKind) _ctaFor(ErrorReviewPriority p) {
    switch (p) {
      case ErrorReviewPriority.high:
        return ('Apri lezione', ErrorReviewCtaKind.openLessonSheets);
      case ErrorReviewPriority.medium:
        return ('Vai ai quiz', ErrorReviewCtaKind.openQuizHome);
      case ErrorReviewPriority.low:
        return ('Rivedi argomento', ErrorReviewCtaKind.reviewTopic);
    }
  }

  static String _messageFor(
    LessonQuizPerformanceSnapshot s,
    ErrorReviewPriority priority,
  ) {
    final pct = s.averageErrorPercentage.round();
    switch (priority) {
      case ErrorReviewPriority.high:
        return 'Concentrati sulle schede di questa lezione: circa $pct% di errori '
            'negli ultimi tentativi — un ripasso mirato riduce il rischio prima dell’esame.';
      case ErrorReviewPriority.medium:
        return 'Errori intorno al $pct%: ripeti le domande più ostiche e verifica '
            'i concetti collegati alla teoria in aula.';
      case ErrorReviewPriority.low:
        return 'Leggermente sopra il tuo obiettivo ($pct% errori): una passata '
            'alle schede basta per consolidare.';
    }
  }
}
