import 'dart:math';

import '../models/quiz_question.dart';
import 'exam_quiz_rules.dart';

/// Collassa solo spazi ripetuti. Il testo tecnico resta com’è.
String normalizeExamDrawText(String? value) {
  if (value == null) return '';
  return value.replaceAll(RegExp(r'[ \t\r\n\f]+'), ' ').trim();
}

/// Identità del contenuto visto dall’allievo, usata solo nel sorteggio.
///
/// Due righe ufficiali con id diversi restano in banca. In una stessa
/// simulazione ne entra una sola quando prompt, opzioni, risposta e figura
/// coincidono dopo questa normalizzazione.
String examQuestionContentKey(QuizQuestion question) {
  return [
    normalizeExamDrawText(question.prompt),
    normalizeExamDrawText(question.optionA),
    normalizeExamDrawText(question.optionB),
    normalizeExamDrawText(question.optionC),
    question.correctOption.letter,
    normalizeExamDrawText(question.imagePath),
  ].join('\u0001');
}

/// Seleziona domande rispettando le [topicQuotas] per categoria.
///
/// [poolByTopic] mappa `exam_topic_code` → domande disponibili.
/// [random] iniettabile per test deterministici.
///
/// Per ogni topic il pool viene mescolato, poi si scartano gli id già
/// estratti e le ristampe con lo stesso [examQuestionContentKey]. La quota
/// si completa con la domanda successiva dello stesso topic. Se il contenuto
/// unico non basta, il risultato resta più corto e il chiamante usa il
/// percorso di pool insufficiente.
List<QuizQuestion> pickExamQuestions({
  required Map<String, List<QuizQuestion>> poolByTopic,
  required Map<String, int> topicQuotas,
  Random? random,
}) {
  final rng = random ?? Random();
  final picked = <QuizQuestion>[];
  final usedIds = <String>{};
  final usedContentKeys = <String>{};

  for (final entry in topicQuotas.entries) {
    final topic = entry.key;
    final quota = entry.value;
    if (quota <= 0) continue;

    final pool = List<QuizQuestion>.from(poolByTopic[topic] ?? const []);
    pool.shuffle(rng);

    var added = 0;
    for (final question in pool) {
      if (added >= quota) break;
      if (usedIds.contains(question.id)) continue;
      final contentKey = examQuestionContentKey(question);
      if (usedContentKeys.contains(contentKey)) continue;
      picked.add(question);
      usedIds.add(question.id);
      usedContentKeys.add(contentKey);
      added++;
    }
  }

  picked.shuffle(rng);
  return picked;
}

int _uniqueExamCandidates(List<QuizQuestion> pool) {
  final usedIds = <String>{};
  final usedContentKeys = <String>{};
  var count = 0;
  for (final question in pool) {
    if (!usedIds.add(question.id)) continue;
    if (!usedContentKeys.add(examQuestionContentKey(question))) continue;
    count++;
  }
  return count;
}

/// Primo topic con pool insufficiente rispetto alla quota richiesta.
class ExamTopicPoolShortfall {
  const ExamTopicPoolShortfall({
    required this.topic,
    required this.required,
    required this.available,
  });

  final String topic;
  final int required;
  final int available;
}

/// Restituisce il primo topic il cui contenuto unico è inferiore alla quota.
///
/// [ExamTopicPoolShortfall.available] conta le domande distinte per id e per
/// contenuto allievo, non la lunghezza grezza del pool.
ExamTopicPoolShortfall? findExamTopicPoolShortfall({
  required Map<String, List<QuizQuestion>> poolByTopic,
  required Map<String, int> topicQuotas,
}) {
  for (final entry in topicQuotas.entries) {
    final quota = entry.value;
    if (quota <= 0) continue;
    final available = _uniqueExamCandidates(poolByTopic[entry.key] ?? const []);
    if (available < quota) {
      return ExamTopicPoolShortfall(
        topic: entry.key,
        required: quota,
        available: available,
      );
    }
  }
  return null;
}

/// Quote topic per categoria esame supportata.
Map<String, int>? examTopicQuotasForCategory(String licenseCategoryDb) {
  return examQuizRulesForDbCategory(licenseCategoryDb)?.topicQuotas;
}
