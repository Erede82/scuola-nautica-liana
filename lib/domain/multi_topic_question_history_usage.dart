/// Usage storico domande Multischeda (da attempt answers completati).
///
/// Derivato da `multi_topic_quiz_attempt_answers` join attempts della categoria.
/// Una domanda è "già vista" se compare almeno una volta, indipendentemente
/// da corretta / errata / non risposta.
class MultiTopicQuestionHistoryUsage {
  const MultiTopicQuestionHistoryUsage({
    required this.seenQuestionIds,
    required this.usageCounts,
    required this.lastSeenAt,
  });

  static const empty = MultiTopicQuestionHistoryUsage(
    seenQuestionIds: <String>{},
    usageCounts: <String, int>{},
    lastSeenAt: <String, DateTime>{},
  );

  final Set<String> seenQuestionIds;
  final Map<String, int> usageCounts;
  final Map<String, DateTime> lastSeenAt;

  bool get isEmpty => seenQuestionIds.isEmpty;

  /// Aggrega righe answers (question_id + created_at) in usage.
  static MultiTopicQuestionHistoryUsage fromAnswerRows(
    Iterable<({String questionId, DateTime? createdAt})> rows,
  ) {
    final counts = <String, int>{};
    final lastSeen = <String, DateTime>{};
    for (final row in rows) {
      final id = row.questionId.trim();
      if (id.isEmpty) continue;
      counts[id] = (counts[id] ?? 0) + 1;
      final at = row.createdAt;
      if (at != null) {
        final prev = lastSeen[id];
        if (prev == null || at.isAfter(prev)) {
          lastSeen[id] = at;
        }
      }
    }
    return MultiTopicQuestionHistoryUsage(
      seenQuestionIds: Set<String>.unmodifiable(counts.keys),
      usageCounts: Map<String, int>.unmodifiable(counts),
      lastSeenAt: Map<String, DateTime>.unmodifiable(lastSeen),
    );
  }
}
