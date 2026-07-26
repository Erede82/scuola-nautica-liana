import 'dart:math';

import '../models/quiz_question.dart';
import 'exam_quiz_rules.dart';

/// Seleziona domande rispettando le [topicQuotas] per categoria.
///
/// [poolByTopic] mappa `exam_topic_code` → domande disponibili.
/// [random] iniettabile per test deterministici.
List<QuizQuestion> pickExamQuestions({
  required Map<String, List<QuizQuestion>> poolByTopic,
  required Map<String, int> topicQuotas,
  Random? random,
}) {
  final rng = random ?? Random();
  final picked = <QuizQuestion>[];
  final usedIds = <String>{};

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
      picked.add(question);
      usedIds.add(question.id);
      added++;
    }
  }

  picked.shuffle(rng);
  return picked;
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

/// Restituisce il primo topic la cui disponibilità è inferiore alla quota.
ExamTopicPoolShortfall? findExamTopicPoolShortfall({
  required Map<String, List<QuizQuestion>> poolByTopic,
  required Map<String, int> topicQuotas,
}) {
  for (final entry in topicQuotas.entries) {
    final quota = entry.value;
    if (quota <= 0) continue;
    final available = poolByTopic[entry.key]?.length ?? 0;
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
