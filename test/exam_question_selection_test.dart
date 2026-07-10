import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/exam_question_selection.dart';
import 'package:scuola_nautica_liana/domain/exam_quiz_rules.dart';
import 'package:scuola_nautica_liana/models/quiz_question.dart';

QuizQuestion _q(String id) => QuizQuestion(
  id: id,
  prompt: 'Prompt $id',
  optionA: 'A',
  optionB: 'B',
  optionC: 'C',
  correctOption: QuizAnswerOption.a,
  lessonNumber: 1,
  licenseCategory: 'A12',
);

void main() {
  group('pickExamQuestions', () {
    test('rispetta quote topic A12', () {
      final pool = <String, List<QuizQuestion>>{
        for (final topic in ExamQuizRules.a12TopicQuotas.keys)
          topic: List.generate(5, (i) => _q('$topic-$i')),
      };

      final picked = pickExamQuestions(
        poolByTopic: pool,
        topicQuotas: ExamQuizRules.a12TopicQuotas,
        random: Random(1),
      );

      expect(picked.length, ExamQuizRules.questionCount);

      final byTopic = <String, int>{};
      for (final topic in ExamQuizRules.a12TopicQuotas.keys) {
        byTopic[topic] = picked.where((q) => q.id.startsWith('$topic-')).length;
      }
      expect(byTopic, ExamQuizRules.a12TopicQuotas);
    });

    test('pool insufficiente → meno domande', () {
      final picked = pickExamQuestions(
        poolByTopic: {
          'SCAFO': [_q('s1')],
        },
        topicQuotas: const {'SCAFO': 3},
        random: Random(0),
      );

      expect(picked.length, 1);
    });
  });

  group('examTopicQuotasForCategory', () {
    test('A12 ha quote', () {
      expect(examTopicQuotasForCategory('A12'), ExamQuizRules.a12TopicQuotas);
    });

    test('categoria sconosciuta → null', () {
      expect(examTopicQuotasForCategory('XX'), isNull);
    });
  });
}
