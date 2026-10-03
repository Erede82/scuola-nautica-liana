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

/// Genera le domande di una scheda Multischeda.
///
/// - Solo lesson in [selectedLessonNumbers].
/// - Zero duplicati intra-scheda.
/// - Preferisce domande non in [usedQuestionIds].
/// - [allowReuse] solo dopo esaurimento (o se forzato dal caller).
/// - Domande con `lesson_number` assente non entrano (filtrate dai pool per lesson).
MultiTopicSheetPickResult? pickMultiTopicSheetQuestions({
  required Map<int, List<QuizQuestion>> poolByLesson,
  required List<int> selectedLessonNumbers,
  required int questionsPerSheet,
  required int sheetIndex,
  required Set<String> usedQuestionIds,
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

  final picked = <QuizQuestion>[];
  final pickedIds = <String>{};
  var usedReuse = false;

  QuizQuestion? takeOne({
    required int lessonNumber,
    required bool preferUnused,
  }) {
    final pool = poolByLesson[lessonNumber];
    if (pool == null || pool.isEmpty) return null;

    final candidates = <QuizQuestion>[
      for (final q in pool)
        if (!pickedIds.contains(q.id) &&
            (!preferUnused || !usedQuestionIds.contains(q.id)))
          q,
    ];
    if (candidates.isEmpty) return null;
    candidates.shuffle(rng);
    final chosen = candidates.first;
    if (consumeFromPools) {
      pool.removeWhere((q) => q.id == chosen.id);
    }
    return chosen;
  }

  void assignQuota(int lessonIndex, int quota) {
    for (var n = 0; n < quota; n++) {
      var q = takeOne(lessonNumber: lessons[lessonIndex], preferUnused: true);
      if (q == null && allowReuse) {
        q = takeOne(lessonNumber: lessons[lessonIndex], preferUnused: false);
        if (q != null) usedReuse = true;
      }
      if (q == null) return;
      picked.add(q);
      pickedIds.add(q.id);
    }
  }

  for (var i = 0; i < lessons.length; i++) {
    assignQuota(i, quotas[i]);
  }

  // Redistribuisci slot mancanti su altre lesson selezionate.
  while (picked.length < questionsPerSheet) {
    QuizQuestion? q;
    for (final lesson in lessons) {
      q = takeOne(lessonNumber: lesson, preferUnused: true);
      if (q != null) break;
    }
    if (q == null && allowReuse) {
      for (final lesson in lessons) {
        q = takeOne(lessonNumber: lesson, preferUnused: false);
        if (q != null) {
          usedReuse = true;
          break;
        }
      }
    }
    if (q == null) break;
    picked.add(q);
    pickedIds.add(q.id);
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
