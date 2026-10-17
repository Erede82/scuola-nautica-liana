/// Cap di default di Supabase/PostgREST (`db-max-rows`).
///
/// Una select senza pagina esplicita entro questo limite scarta il resto
/// senza errore. La continuity Multischeda non può trattare quel resto
/// come «mai vista».
const multiTopicQuestionUsagePageSize = 1000;

/// Risposte scritte per attempt da `submit_multi_topic_quiz_attempt` (A12).
///
/// D1 ne scrive 15. Il chunk di lettura usa il massimo, così una pagina
/// non supera [multiTopicQuestionUsagePageSize].
const multiTopicMaxAnswersPerAttempt = 20;

/// Attempt id per richiesta answers.
///
/// 49 × 20 = 980, sotto il cap. La paginazione `.range` copre comunque
/// un chunk che superasse il limite.
const multiTopicQuestionUsageAttemptChunkSize =
    (multiTopicQuestionUsagePageSize - 1) ~/ multiTopicMaxAnswersPerAttempt;

/// Quante pagine complete si accettano prima di fallire chiuso.
///
/// Oltre questo tetto la history è incompleta: meglio rifiutare l'avvio
/// che generare schede che ripetono domande già viste.
const multiTopicQuestionUsageMaxPages = 8;

/// Finestra inclusiva `.range(from, to)` per la pagina [pageIndex] (0-based).
({int from, int to}) multiTopicUsagePageRange({
  required int pageIndex,
  int pageSize = multiTopicQuestionUsagePageSize,
}) {
  if (pageIndex < 0) {
    throw ArgumentError.value(pageIndex, 'pageIndex');
  }
  if (pageSize < 1) {
    throw ArgumentError.value(pageSize, 'pageSize');
  }
  final from = pageIndex * pageSize;
  return (from: from, to: from + pageSize - 1);
}

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
