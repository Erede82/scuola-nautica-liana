import '../../../domain/quiz_license_category.dart';
import '../../license_catalog.dart';
import '../dto/quiz_wrong_answer_history_row.dart';
import '../../../models/license_models.dart';
import '../../../models/quiz_error_review_data.dart';
import '../../../models/quiz_question.dart';
import '../../../models/quiz_wrong_answer_entry.dart';

/// Lezioni catalogo motore/D1 (1–14).
const int kMinLessonNumber = 1;
const int kMaxLessonNumber = 14;

/// Timestamp errore: answered_at, altrimenti completed_at risultato, altrimenti created_at.
DateTime resolveWrongAnswerTimestamp(QuizWrongAnswerHistoryRow row) {
  return row.answeredAt ??
      row.completedAt ??
      row.resultCreatedAt ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

/// Valida riga grezza prima della deduplica.
bool isValidWrongAnswerHistoryRow(
  QuizWrongAnswerHistoryRow row, {
  required LicenseCategoryId expectedCategoryId,
}) {
  if (row.kind != 'lesson') return false;
  if (row.isCorrect) return false;

  final selected = QuizAnswerOptionX.tryParse(row.selectedOption);
  if (selected == null) return false;

  final correct = _resolveCorrectOption(row);
  if (correct == null) return false;

  if (selected == correct) return false;

  if (row.questionId.trim().isEmpty) return false;
  if (row.prompt.trim().isEmpty) return false;

  final lessonNumber = row.lessonNumber;
  if (lessonNumber < kMinLessonNumber || lessonNumber > kMaxLessonNumber) {
    return false;
  }

  final rowCategory = licenseCategoryIdFromDb(row.licenseCategory);
  if (rowCategory == null || rowCategory != expectedCategoryId) return false;

  final questionCategory = licenseCategoryIdFromDb(row.questionLicenseCategory);
  if (questionCategory != null && questionCategory != expectedCategoryId) {
    return false;
  }

  return true;
}

QuizAnswerOption? _resolveCorrectOption(QuizWrongAnswerHistoryRow row) {
  final fromAnswer = QuizAnswerOptionX.tryParse(row.correctOption);
  if (fromAnswer != null) return fromAnswer;
  return QuizAnswerOptionX.tryParse(row.questionCorrectOption);
}

/// Raggruppa righe valide per questionId; righe/gruppi incoerenti incrementano [ignored].
Map<String, List<QuizWrongAnswerHistoryRow>> groupValidRowsByQuestionId({
  required List<QuizWrongAnswerHistoryRow> rows,
  required LicenseCategoryId categoryId,
  required void Function() onIgnored,
}) {
  final groups = <String, List<QuizWrongAnswerHistoryRow>>{};

  for (final row in rows) {
    if (!isValidWrongAnswerHistoryRow(row, expectedCategoryId: categoryId)) {
      onIgnored();
      continue;
    }

    final correct = _resolveCorrectOption(row)!;
    final selected = QuizAnswerOptionX.tryParse(row.selectedOption)!;
    if (selected == correct) {
      onIgnored();
      continue;
    }

    groups.putIfAbsent(row.questionId, () => []).add(row);
  }

  return groups;
}

/// Se lo stesso questionId ha correctOption discordanti, il gruppo è ignorato.
QuizWrongAnswerEntry? buildEntryFromQuestionGroup({
  required String questionId,
  required List<QuizWrongAnswerHistoryRow> rows,
  required LicenseCategoryId categoryId,
}) {
  if (rows.isEmpty) return null;

  final correctOptions = <QuizAnswerOption>{};
  for (final row in rows) {
    final correct = _resolveCorrectOption(row);
    if (correct != null) correctOptions.add(correct);
  }

  if (correctOptions.length != 1) return null;

  final correctOption = correctOptions.first;
  final sorted = List<QuizWrongAnswerHistoryRow>.from(rows)
    ..sort(
      (a, b) => resolveWrongAnswerTimestamp(
        b,
      ).compareTo(resolveWrongAnswerTimestamp(a)),
    );

  final latest = sorted.first;
  final latestSelected = QuizAnswerOptionX.tryParse(latest.selectedOption);
  if (latestSelected == null) return null;

  final timestamps = sorted.map(resolveWrongAnswerTimestamp).toList();
  final sheetNumbers = rows.map((r) => r.sheetNumber).toSet().toList()..sort();

  return QuizWrongAnswerEntry(
    questionId: questionId,
    prompt: latest.prompt.trim(),
    optionA: latest.optionA.trim(),
    optionB: latest.optionB.trim(),
    optionC: latest.optionC.trim(),
    latestSelectedOption: latestSelected,
    correctOption: correctOption,
    explanation: _trimOrNull(latest.explanation),
    imagePath: _trimOrNull(latest.imagePath),
    lessonNumber: latest.lessonNumber,
    sheetNumbers: sheetNumbers,
    licenseCategoryId: categoryId,
    examTopicCode: _trimOrNull(latest.examTopicCode),
    sourceTopicText: _trimOrNull(latest.sourceTopicText),
    errorCount: rows.length,
    firstWrongAt: timestamps.reduce((a, b) => a.isBefore(b) ? a : b),
    lastWrongAt: timestamps.reduce((a, b) => a.isAfter(b) ? a : b),
  );
}

/// Ordine deterministico v1.
int compareWrongAnswerEntries(
  QuizWrongAnswerEntry a,
  QuizWrongAnswerEntry b, {
  required QuizErrorReviewSort sort,
}) {
  switch (sort) {
    case QuizErrorReviewSort.recent:
      final byLast = b.lastWrongAt.compareTo(a.lastWrongAt);
      if (byLast != 0) return byLast;
      final byCount = b.errorCount.compareTo(a.errorCount);
      if (byCount != 0) return byCount;
    case QuizErrorReviewSort.mostFrequent:
      final byFreq = b.errorCount.compareTo(a.errorCount);
      if (byFreq != 0) return byFreq;
      final byLast = b.lastWrongAt.compareTo(a.lastWrongAt);
      if (byLast != 0) return byLast;
  }

  final byLesson = a.lessonNumber.compareTo(b.lessonNumber);
  if (byLesson != 0) return byLesson;

  return a.questionId.compareTo(b.questionId);
}

List<QuizWrongAnswerEntry> sortWrongAnswerEntries(
  List<QuizWrongAnswerEntry> entries, {
  required QuizErrorReviewSort sort,
}) {
  final sorted = List<QuizWrongAnswerEntry>.from(entries)
    ..sort((a, b) => compareWrongAnswerEntries(a, b, sort: sort));
  return sorted;
}

String? lessonTitleFor({
  required LicenseCategoryId categoryId,
  required int lessonNumber,
}) {
  final category = LicenseCatalog.byId(categoryId);
  for (final lesson in category.lessons) {
    if (lesson.number == lessonNumber) return lesson.title;
  }
  return 'Lezione $lessonNumber';
}

/// Costruisce aggregato dominio da righe grezze.
QuizErrorReviewData buildQuizErrorReviewData({
  required LicenseCategoryId categoryId,
  required List<QuizWrongAnswerHistoryRow> rows,
  int? lessonNumber,
  QuizErrorReviewSort sort = QuizErrorReviewSort.recent,
  int? limit,
}) {
  var ignored = 0;
  void onIgnored() => ignored++;

  final groups = groupValidRowsByQuestionId(
    rows: rows,
    categoryId: categoryId,
    onIgnored: onIgnored,
  );

  final entries = <QuizWrongAnswerEntry>[];
  for (final entry in groups.entries) {
    final built = buildEntryFromQuestionGroup(
      questionId: entry.key,
      rows: entry.value,
      categoryId: categoryId,
    );
    if (built == null) {
      ignored += entry.value.length;
      continue;
    }
    entries.add(built);
  }

  var filtered = entries;
  if (lessonNumber != null) {
    filtered = entries
        .where((e) => e.lessonNumber == lessonNumber)
        .toList(growable: false);
  }

  final sorted = sortWrongAnswerEntries(filtered, sort: sort);
  final limited = limit == null || limit <= 0
      ? sorted
      : sorted.take(limit).toList(growable: false);

  final lessonCounts = <int, int>{};
  var totalOccurrences = 0;
  DateTime? lastWrongAt;

  for (final entry in limited) {
    totalOccurrences += entry.errorCount;
    lessonCounts[entry.lessonNumber] =
        (lessonCounts[entry.lessonNumber] ?? 0) + 1;
    if (lastWrongAt == null || entry.lastWrongAt.isAfter(lastWrongAt)) {
      lastWrongAt = entry.lastWrongAt;
    }
  }

  return QuizErrorReviewData(
    categoryId: categoryId,
    entries: limited,
    totalUniqueQuestions: limited.length,
    totalWrongOccurrences: totalOccurrences,
    lessonCounts: lessonCounts,
    lastWrongAt: lastWrongAt,
    ignoredMalformedRows: ignored,
  );
}

String? _trimOrNull(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}
