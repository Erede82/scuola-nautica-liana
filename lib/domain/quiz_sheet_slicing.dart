import 'dart:math' as math;

import '../models/quiz_question.dart';

/// Seleziona domande per scheda con **rotazione deterministica** sul pool lezione.
///
/// 1. `startIndex = ((sheetNumber - 1) * limit) % pool.length`
/// 2. Si raccolgono fino a [limit] domande partendo da [startIndex]
/// 3. Se si raggiunge la fine del pool, si riparte dall'inizio (ciclo)
///
/// Se `pool.length >= limit`: nessun duplicato nella stessa scheda.
/// Se `pool.length < limit`: restituisce tutte le domande del pool (meno di
/// [limit]), senza duplicati — caso raro/edge.
List<QuizQuestion> sliceLessonSheetQuestions({
  required List<QuizQuestion> pool,
  required int sheetNumber,
  int limit = 20,
}) {
  if (pool.isEmpty || sheetNumber < 1 || limit < 1) return const [];

  final poolLen = pool.length;
  final startIndex = ((sheetNumber - 1) * limit) % poolLen;
  final count = math.min(limit, poolLen);

  return List<QuizQuestion>.generate(
    count,
    (i) => pool[(startIndex + i) % poolLen],
  );
}

/// Indici 0-based nel pool ordinato per [questionIds] (stesso algoritmo di
/// [sliceLessonSheetQuestions], senza dipendere da [QuizQuestion]).
List<int> sliceLessonSheetQuestionIndices({
  required int poolLength,
  required int sheetNumber,
  int limit = 20,
}) {
  if (poolLength < 1 || sheetNumber < 1 || limit < 1) return const [];

  final startIndex = ((sheetNumber - 1) * limit) % poolLength;
  final count = math.min(limit, poolLength);

  return List<int>.generate(
    count,
    (i) => (startIndex + i) % poolLength,
  );
}
