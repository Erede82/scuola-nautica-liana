import 'dart:math';

import '../models/quiz_question.dart';

/// Quote bilanciate per una scheda Multischeda.
///
/// `base = N ~/ T`, `remainder = N % T`.
/// Le [remainder] lezioni extra ruotano con [sheetIndex] (1-based).
List<int> multiTopicBalancedQuotas({
  required int questionsPerSheet,
  required int lessonCount,
  required int sheetIndex,
}) {
  if (questionsPerSheet <= 0 || lessonCount <= 0 || sheetIndex < 1) {
    return const [];
  }
  final base = questionsPerSheet ~/ lessonCount;
  final remainder = questionsPerSheet % lessonCount;
  final offset = (sheetIndex - 1) % lessonCount;
  return List<int>.generate(lessonCount, (i) {
    final distance = (i - offset + lessonCount) % lessonCount;
    return base + (distance < remainder ? 1 : 0);
  });
}

/// Esito generazione di una scheda.
class MultiTopicSheetPickResult {
  const MultiTopicSheetPickResult({
    required this.questions,
    required this.usedReuse,
  });

  final List<QuizQuestion> questions;
  final bool usedReuse;

  bool get isComplete => questions.isNotEmpty;
}

/// Shortfall quando non è possibile costruire una scheda completa.
class MultiTopicPoolShortfall {
  const MultiTopicPoolShortfall({
    required this.required,
    required this.availableDistinct,
    this.message =
        'Pool domande insufficiente per generare una scheda completa '
        'con gli argomenti selezionati.',
  });

  final int required;
  final int availableDistinct;
  final String message;
}

/// Conta quante schede complete si possono generare usando solo domande distinte.
int maxDistinctMultiTopicSheets({
  required Map<int, List<QuizQuestion>> poolByLesson,
  required List<int> selectedLessonNumbers,
  required int questionsPerSheet,
}) {
  if (questionsPerSheet <= 0 || selectedLessonNumbers.isEmpty) return 0;

  final remaining = <int, List<QuizQuestion>>{
    for (final lesson in selectedLessonNumbers)
      lesson: List<QuizQuestion>.from(poolByLesson[lesson] ?? const []),
  };

  var sheets = 0;
  while (true) {
    final pick = pickMultiTopicSheetQuestions(
      poolByLesson: remaining,
      selectedLessonNumbers: selectedLessonNumbers,
      questionsPerSheet: questionsPerSheet,
      sheetIndex: sheets + 1,
      usedQuestionIds: const {},
      allowReuse: false,
      consumeFromPools: true,
    );
    if (pick == null || pick.questions.length < questionsPerSheet) break;
    sheets++;
  }
  return sheets;
}

Map<int, List<QuizQuestion>> _dedupedWorkingPools({
  required Map<int, List<QuizQuestion>> poolByLesson,
  required List<int> selectedLessonNumbers,
}) {
  final out = <int, List<QuizQuestion>>{};
  final globalSeen = <String>{};
  for (final lesson in selectedLessonNumbers) {
    final raw = poolByLesson[lesson] ?? const <QuizQuestion>[];
    final list = <QuizQuestion>[];
    for (final question in raw) {
      final id = question.id;
      if (id.isEmpty) continue;
      // Dedup globale: stesso question_id non entra due volte nel pool sessione.
      if (!globalSeen.add(id)) continue;
      list.add(question);
    }
    out[lesson] = list;
  }
  return out;
}

/// Genera le domande di una scheda Multischeda.
///
/// Ordine vincoli:
/// 1. unused effective (history ∪ sessione) — priorità assoluta
/// 2. redistribuzione shortfall su altri topic unused
/// 3. reuse solo se unused globali insufficienti, con ranking:
///    meno usate storicamente → evita scheda precedente → random
/// 4. zero duplicati intra-scheda
/// 5. randomizzazione dopo la selezione
///
/// [usedQuestionIds] deve essere l'unione history ∪ sessione corrente
/// (`effectiveUsed`). Non sacrificare domande nuove per quote topic.
MultiTopicSheetPickResult? pickMultiTopicSheetQuestions({
  required Map<int, List<QuizQuestion>> poolByLesson,
  required List<int> selectedLessonNumbers,
  required int questionsPerSheet,
  required int sheetIndex,
  required Set<String> usedQuestionIds,
  Map<String, int> usageCounts = const {},
  Set<String> avoidQuestionIds = const {},
  bool allowReuse = true,
  bool consumeFromPools = false,
  Random? random,
}) {
  if (questionsPerSheet <= 0 || selectedLessonNumbers.isEmpty) return null;

  final rng = random ?? Random();
  final lessons = List<int>.from(selectedLessonNumbers);
  final quotas = multiTopicBalancedQuotas(
    questionsPerSheet: questionsPerSheet,
    lessonCount: lessons.length,
    sheetIndex: sheetIndex,
  );
  if (quotas.isEmpty) return null;

  final working = _dedupedWorkingPools(
    poolByLesson: poolByLesson,
    selectedLessonNumbers: lessons,
  );

  final picked = <QuizQuestion>[];
  final pickedIds = <String>{};
  var usedReuse = false;

  QuizQuestion? takeUnused({required int lessonNumber}) {
    final pool = working[lessonNumber];
    if (pool == null || pool.isEmpty) return null;

    final candidates = <QuizQuestion>[
      for (final q in pool)
        if (!pickedIds.contains(q.id) && !usedQuestionIds.contains(q.id)) q,
    ];
    if (candidates.isEmpty) return null;
    candidates.shuffle(rng);
    final chosen = candidates.first;
    if (consumeFromPools) {
      pool.removeWhere((q) => q.id == chosen.id);
      final source = poolByLesson[lessonNumber];
      source?.removeWhere((q) => q.id == chosen.id);
    }
    return chosen;
  }

  // Fase A/B/C: quote topic SOLO con unused effective. Nessun reuse qui.
  for (var i = 0; i < lessons.length; i++) {
    final quota = quotas[i];
    for (var n = 0; n < quota; n++) {
      final q = takeUnused(lessonNumber: lessons[i]);
      if (q == null) break;
      picked.add(q);
      pickedIds.add(q.id);
    }
  }

  // Fase D/E: shortfall → altri topic con unused rimanenti.
  // Non sacrificare una domanda nuova per una quota topic perfetta.
  while (picked.length < questionsPerSheet) {
    QuizQuestion? q;
    for (final lesson in lessons) {
      q = takeUnused(lessonNumber: lesson);
      if (q != null) break;
    }
    if (q == null) break;
    picked.add(q);
    pickedIds.add(q.id);
  }

  // Fase F: reuse solo dopo esaurimento unused effective.
  // Ranking: usageCount ASC → evita previous sheet → random tra equivalenti.
  if (picked.length < questionsPerSheet && allowReuse) {
    while (picked.length < questionsPerSheet) {
      final candidates = <QuizQuestion>[
        for (final lesson in lessons)
          for (final q in working[lesson] ?? const <QuizQuestion>[])
            if (!pickedIds.contains(q.id)) q,
      ];
      if (candidates.isEmpty) break;

      candidates.sort((a, b) {
        final ua = usageCounts[a.id] ?? 0;
        final ub = usageCounts[b.id] ?? 0;
        final usageCmp = ua.compareTo(ub);
        if (usageCmp != 0) return usageCmp;
        final aAvoid = avoidQuestionIds.contains(a.id);
        final bAvoid = avoidQuestionIds.contains(b.id);
        if (aAvoid != bAvoid) return aAvoid ? 1 : -1;
        return 0;
      });

      final bestUsage = usageCounts[candidates.first.id] ?? 0;
      final bestAvoid = avoidQuestionIds.contains(candidates.first.id);
      final top = <QuizQuestion>[
        for (final q in candidates)
          if ((usageCounts[q.id] ?? 0) == bestUsage &&
              avoidQuestionIds.contains(q.id) == bestAvoid)
            q,
      ];
      top.shuffle(rng);
      final chosen = top.first;
      usedReuse = true;
      picked.add(chosen);
      pickedIds.add(chosen.id);
      if (consumeFromPools) {
        for (final lesson in lessons) {
          working[lesson]?.removeWhere((q) => q.id == chosen.id);
          poolByLesson[lesson]?.removeWhere((q) => q.id == chosen.id);
        }
      }
    }
  }

  if (picked.length < questionsPerSheet) return null;

  picked.shuffle(rng);
  return MultiTopicSheetPickResult(
    questions: List.unmodifiable(picked),
    usedReuse: usedReuse,
  );
}

/// Verifica se la combinazione può produrre almeno [sheetCount] schede
/// (usando riuso dopo esaurimento delle distinte).
///
/// Con riuso abilitato nel player, se almeno 1 scheda completa è costruibile
/// allora anche N schede lo sono (totale da catalogo `quiz_sets` ∩ unlock).
MultiTopicPoolShortfall? findMultiTopicPoolShortfall({
  required Map<int, List<QuizQuestion>> poolByLesson,
  required List<int> selectedLessonNumbers,
  required int questionsPerSheet,
  required int sheetCount,
}) {
  if (sheetCount < 1) {
    return const MultiTopicPoolShortfall(
      required: 1,
      availableDistinct: 0,
      message: 'Seleziona almeno una scheda da svolgere.',
    );
  }

  final distinctMax = maxDistinctMultiTopicSheets(
    poolByLesson: poolByLesson,
    selectedLessonNumbers: selectedLessonNumbers,
    questionsPerSheet: questionsPerSheet,
  );

  // Una scheda completa richiede abbastanza domande distinte intra-scheda.
  // Se distinctMax == 0 → impossibile anche con riuso.
  if (distinctMax < 1) {
    final available = selectedLessonNumbers.fold<int>(
      0,
      (sum, lesson) => sum + (poolByLesson[lesson]?.length ?? 0),
    );
    return MultiTopicPoolShortfall(
      required: questionsPerSheet,
      availableDistinct: available,
    );
  }

  return null;
}
