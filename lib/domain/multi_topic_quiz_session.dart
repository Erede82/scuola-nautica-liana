import '../models/license_models.dart';
import '../models/quiz_question.dart';

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
  }) : usedQuestionIds = usedQuestionIds ?? <String>{};

  final String sessionId;
  final LicenseCategoryId licenseCategory;
  final List<int> selectedLessonNumbers;
  final int totalSheets;
  final Map<int, List<QuizQuestion>> poolByLesson;

  /// Ultima scheda completata (0 = nessuna). La prossima da generare è +1.
  int currentSheetIndex;
  final Set<String> usedQuestionIds;

  bool get hasMoreSheets => currentSheetIndex < totalSheets;

  int get nextSheetIndex => currentSheetIndex + 1;

  void markSheetConsumed({
    required int sheetIndex,
    required Iterable<String> questionIds,
  }) {
    currentSheetIndex = sheetIndex;
    usedQuestionIds.addAll(questionIds);
  }
}
