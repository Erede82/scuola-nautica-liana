import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/exam_question_selection.dart';
import 'package:scuola_nautica_liana/domain/exam_quiz_rules.dart';
import 'package:scuola_nautica_liana/models/quiz_question.dart';

QuizQuestion _q(String id, {String licenseCategory = 'A12'}) => QuizQuestion(
  id: id,
  prompt: 'Prompt $id',
  optionA: 'A',
  optionB: 'B',
  optionC: 'C',
  correctOption: QuizAnswerOption.a,
  lessonNumber: 1,
  licenseCategory: licenseCategory,
);

Map<String, List<QuizQuestion>> _poolForQuotas(
  Map<String, int> quotas, {
  int perTopic = 5,
  String licenseCategory = 'A12',
}) {
  return {
    for (final topic in quotas.keys)
      topic: List.generate(
        perTopic,
        (i) => _q('$topic-$i', licenseCategory: licenseCategory),
      ),
  };
}

void main() {
  group('pickExamQuestions', () {
    test('rispetta quote topic A12', () {
      final pool = _poolForQuotas(ExamQuizRules.a12TopicQuotas);

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

    test('D1 restituisce 15 domande con distribuzione ufficiale', () {
      final pool = _poolForQuotas(
        ExamQuizRules.d1TopicQuotas,
        licenseCategory: 'D1',
      );

      final picked = pickExamQuestions(
        poolByTopic: pool,
        topicQuotas: ExamQuizRules.d1TopicQuotas,
        random: Random(42),
      );

      expect(picked.length, 15);
      expect(picked.map((q) => q.id).toSet(), hasLength(15));

      final byTopic = <String, int>{};
      for (final topic in ExamQuizRules.d1TopicQuotas.keys) {
        byTopic[topic] = picked.where((q) => q.id.startsWith('$topic-')).length;
      }
      expect(byTopic, ExamQuizRules.d1TopicQuotas);
    });

    test('pool insufficiente → meno domande (nessun cross-topic)', () {
      final picked = pickExamQuestions(
        poolByTopic: {
          'SCAFO': [_q('s1')],
        },
        topicQuotas: const {'SCAFO': 3},
        random: Random(0),
      );

      expect(picked.length, 1);
    });

    test('D1 pool insufficiente non riempie da altri topic', () {
      final pool = <String, List<QuizQuestion>>{
        for (final entry in ExamQuizRules.d1TopicQuotas.entries)
          entry.key: List.generate(
            entry.key == 'MOTORE' ? 1 : entry.value + 2,
            (i) => _q('${entry.key}-$i', licenseCategory: 'D1'),
          ),
      };
      final poolSizesBefore = {
        for (final e in pool.entries) e.key: e.value.length,
      };

      final shortfall = findExamTopicPoolShortfall(
        poolByTopic: pool,
        topicQuotas: ExamQuizRules.d1TopicQuotas,
      );
      expect(shortfall?.topic, 'MOTORE');
      expect(shortfall?.required, 2);
      expect(shortfall?.available, 1);

      final picked = pickExamQuestions(
        poolByTopic: pool,
        topicQuotas: ExamQuizRules.d1TopicQuotas,
        random: Random(0),
      );

      expect(picked.length, lessThan(15));
      expect(picked.where((q) => q.id.startsWith('MOTORE-')).length, 1);
      expect(picked.map((q) => q.id).toSet(), hasLength(picked.length));
      for (final entry in pool.entries) {
        expect(entry.value.length, poolSizesBefore[entry.key]);
      }
    });
  });

  group('findExamTopicPoolShortfall', () {
    test('D1 MOTORE=1 con quota 2 → shortfall esplicito', () {
      final pool = _poolForQuotas(
        ExamQuizRules.d1TopicQuotas,
        licenseCategory: 'D1',
      );
      pool['MOTORE'] = [_q('MOTORE-0', licenseCategory: 'D1')];

      final shortfall = findExamTopicPoolShortfall(
        poolByTopic: pool,
        topicQuotas: ExamQuizRules.d1TopicQuotas,
      );

      expect(shortfall, isNotNull);
      expect(shortfall!.topic, 'MOTORE');
      expect(shortfall.required, 2);
      expect(shortfall.available, 1);
    });

    test('D1 tutti i pool sufficienti → null e pick 15 con distribuzione', () {
      final pool = _poolForQuotas(
        ExamQuizRules.d1TopicQuotas,
        perTopic: 5,
        licenseCategory: 'D1',
      );

      expect(
        findExamTopicPoolShortfall(
          poolByTopic: pool,
          topicQuotas: ExamQuizRules.d1TopicQuotas,
        ),
        isNull,
      );

      final picked = pickExamQuestions(
        poolByTopic: pool,
        topicQuotas: ExamQuizRules.d1TopicQuotas,
        random: Random(7),
      );

      expect(picked.length, 15);
      final byTopic = <String, int>{};
      for (final topic in ExamQuizRules.d1TopicQuotas.keys) {
        byTopic[topic] = picked.where((q) => q.id.startsWith('$topic-')).length;
      }
      expect(byTopic, ExamQuizRules.d1TopicQuotas);
    });

    test('A12 pool sufficiente → null', () {
      final pool = _poolForQuotas(ExamQuizRules.a12TopicQuotas);
      expect(
        findExamTopicPoolShortfall(
          poolByTopic: pool,
          topicQuotas: ExamQuizRules.a12TopicQuotas,
        ),
        isNull,
      );
    });
  });

  group('examTopicQuotasForCategory', () {
    test('A12 ha quote invariate', () {
      expect(examTopicQuotasForCategory('A12'), ExamQuizRules.a12TopicQuotas);
    });

    test('D1 ha 8 topic con somma 15', () {
      final quotas = examTopicQuotasForCategory('D1');
      expect(quotas, ExamQuizRules.d1TopicQuotas);
      expect(quotas, hasLength(8));
      expect(quotas!.values.fold<int>(0, (a, b) => a + b), 15);
      expect(quotas.containsKey('SCAFO'), isTrue);
      expect(quotas.containsKey('NORM'), isTrue);
    });

    test('categoria sconosciuta → null', () {
      expect(examTopicQuotasForCategory('XX'), isNull);
    });
  });
}
