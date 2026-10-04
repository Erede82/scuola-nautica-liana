import '../models/license_models.dart';
import '../models/quiz_question.dart';
import 'multi_topic_question_history_usage.dart';

/// Sessione runtime Multischeda (non persistita preventivamente nel DB).
class MultiTopicQuizSession {
  MultiTopicQuizSession({
    required this.sessionId,
    required this.licenseCategory,
    required this.selectedLessonNumbers,
    required this.totalSheets,
    required this.poolByLesson,
    this.currentSheetIndex = 0,
    Set<String>? usedQuestionIds,
    Set<String>? historicallyUsedQuestionIds,
    Map<String, int>? historicalUsageCounts,
  }) : usedQuestionIds = usedQuestionIds ?? <String>{},
       historicallyUsedQuestionIds = historicallyUsedQuestionIds ?? <String>{},
       historicalUsageCounts = Map<String, int>.unmodifiable(
         historicalUsageCounts ?? const <String, int>{},
       );

  /// Factory da usage storico caricato al setup.
  factory MultiTopicQuizSession.withHistory({
    required String sessionId,
    required LicenseCategoryId licenseCategory,
    required List<int> selectedLessonNumbers,
    required int totalSheets,
    required Map<int, List<QuizQuestion>> poolByLesson,
    required MultiTopicQuestionHistoryUsage questionHistory,
  }) {
    return MultiTopicQuizSession(
      sessionId: sessionId,
      licenseCategory: licenseCategory,
      selectedLessonNumbers: selectedLessonNumbers,
      totalSheets: totalSheets,
      poolByLesson: poolByLesson,
      historicallyUsedQuestionIds: questionHistory.seenQuestionIds,
      historicalUsageCounts: questionHistory.usageCounts,
    );
  }

  final String sessionId;
  final LicenseCategoryId licenseCategory;
  final List<int> selectedLessonNumbers;
  final int totalSheets;
  final Map<int, List<QuizQuestion>> poolByLesson;

  /// Ultima scheda completata (0 = nessuna). La prossima da generare è +1.
  int currentSheetIndex;

  /// Domande usate nella sessione corrente (schede già consumate).
  final Set<String> usedQuestionIds;

  /// Domande già mostrate in Multischede completate (categoria corrente).
  final Set<String> historicallyUsedQuestionIds;

  /// Conteggio storico per ranking reuse (solo DB, immutabile in sessione).
  final Map<String, int> historicalUsageCounts;

  /// Usage incrementato in-sessione (per reuse equo dopo esaurimento).
  final Map<String, int> sessionUsageCounts = <String, int>{};

  /// IDs della scheda immediatamente precedente (anti "stessa scheda").
  Set<String> previousSheetQuestionIds = <String>{};

  bool get hasMoreSheets => currentSheetIndex < totalSheets;

  int get nextSheetIndex => currentSheetIndex + 1;

  /// Unione history ∪ sessione corrente.
  Set<String> get effectiveUsedQuestionIds => {
    ...historicallyUsedQuestionIds,
    ...usedQuestionIds,
  };

  /// Usage combinato per ranking reuse.
  Map<String, int> get combinedUsageCounts {
    if (sessionUsageCounts.isEmpty) {
      return historicalUsageCounts;
    }
    final out = Map<String, int>.from(historicalUsageCounts);
    for (final entry in sessionUsageCounts.entries) {
      out[entry.key] = (out[entry.key] ?? 0) + entry.value;
    }
    return out;
  }

  void markSheetConsumed({
    required int sheetIndex,
    required Iterable<String> questionIds,
  }) {
    currentSheetIndex = sheetIndex;
    final ids = questionIds.toSet();
    usedQuestionIds.addAll(ids);
    previousSheetQuestionIds = ids;
    for (final id in ids) {
      sessionUsageCounts[id] = (sessionUsageCounts[id] ?? 0) + 1;
    }
  }
}
