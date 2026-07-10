import 'dart:math';

import '../models/quiz_question.dart';
import 'exam_quiz_rules.dart';

/// Seleziona [ExamQuizRules.questionCount] domande rispettando le quote per topic.
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

/// Quote topic per categoria esame supportata.
Map<String, int>? examTopicQuotasForCategory(String licenseCategoryDb) {
  switch (licenseCategoryDb) {
    case 'A12':
      return ExamQuizRules.a12TopicQuotas;
    default:
      return null;
  }
}
