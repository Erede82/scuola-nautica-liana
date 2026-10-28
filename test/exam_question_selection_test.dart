import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/exam_question_selection.dart';
import 'package:scuola_nautica_liana/domain/exam_quiz_rules.dart';
import 'package:scuola_nautica_liana/models/quiz_question.dart';

/// `List.shuffle` scambia con l’ultimo indice, quindi l’ordine resta.
class _StableOrderRandom implements Random {
  @override
  int nextInt(int max) => max - 1;

  @override
  double nextDouble() => 0;

  @override
  bool nextBool() => false;
}

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

QuizQuestion _contentQuestion({
  required String id,
  required String prompt,
  String optionA = 'Distanza',
  String optionB = 'Velocità',
  String optionC = 'Tempo',
  QuizAnswerOption correctOption = QuizAnswerOption.b,
  String? imagePath = 'figures/nav.png',
  String licenseCategory = 'A12',
}) {
  return QuizQuestion(
    id: id,
    prompt: prompt,
    optionA: optionA,
    optionB: optionB,
    optionC: optionC,
    correctOption: correctOption,
    imagePath: imagePath,
    lessonNumber: 1,
    licenseCategory: licenseCategory,
  );
}

QuizQuestion _officialReprint(String id, {String? prompt}) {
  return _contentQuestion(
    id: id,
    prompt: prompt ?? 'Il nodo misura la velocità, non la distanza.',
  );
}

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

  group('content duplicate draw guard', () {
    test('whitespace-only differences share one content key', () {
      final spaced = _officialReprint(
        'A12-1213',
        prompt: '  Il nodo misura   la velocità,\nnon la distanza.  ',
      );
      final canonical = _officialReprint(
        '9a6a5a70-e9ce-4324-9dd7-f5f2abcc4be9',
      );

      expect(examQuestionContentKey(spaced), examQuestionContentKey(canonical));
      expect(
        normalizeExamDrawText(spaced.prompt),
        'Il nodo misura la velocità, non la distanza.',
      );
    });

    test('identical reprint appears once and A12 quotas stay exact', () {
      final pool = _poolForQuotas(ExamQuizRules.a12TopicQuotas, perTopic: 6);
      pool['NAV'] = [
        _officialReprint('9a6a5a70-e9ce-4324-9dd7-f5f2abcc4be9'),
        _officialReprint(
          'A12-1213',
          prompt: 'Il nodo misura   la velocità, non la distanza.',
        ),
        _q('NAV-2'),
        _q('NAV-3'),
        _q('NAV-4'),
      ];

      expect(
        findExamTopicPoolShortfall(
          poolByTopic: pool,
          topicQuotas: ExamQuizRules.a12TopicQuotas,
        ),
        isNull,
      );

      final picked = pickExamQuestions(
        poolByTopic: pool,
        topicQuotas: ExamQuizRules.a12TopicQuotas,
        random: _StableOrderRandom(),
      );

      final reprintIds = picked
          .map((q) => q.id)
          .where(
            (id) =>
                id == '9a6a5a70-e9ce-4324-9dd7-f5f2abcc4be9' ||
                id == 'A12-1213',
          )
          .toList();
      expect(reprintIds, ['9a6a5a70-e9ce-4324-9dd7-f5f2abcc4be9']);
      expect(picked.map((q) => q.id).toSet(), hasLength(20));
      expect(picked.length, 20);
      final navCount = picked
          .where(
            (q) =>
                q.id.startsWith('NAV-') ||
                q.id == '9a6a5a70-e9ce-4324-9dd7-f5f2abcc4be9' ||
                q.id == 'A12-1213',
          )
          .length;
      expect(navCount, 4);

      final byTopic = <String, int>{};
      for (final topic in ExamQuizRules.a12TopicQuotas.keys) {
        if (topic == 'NAV') {
          byTopic[topic] = navCount;
        } else {
          byTopic[topic] = picked
              .where((q) => q.id.startsWith('$topic-'))
              .length;
        }
      }
      expect(byTopic, ExamQuizRules.a12TopicQuotas);
      expect(ExamQuizRules.a12TopicQuotas['NAV'], 4);
      expect(
        ExamQuizRules.a12TopicQuotas.values.fold<int>(0, (a, b) => a + b),
        20,
      );
    });

    test('same prompt with a different figure stays eligible', () {
      final first = _contentQuestion(
        id: 'figure-a',
        prompt: 'Quale fanale è mostrato?',
        imagePath: 'figures/fanale-a.png',
      );
      final second = _contentQuestion(
        id: 'figure-b',
        prompt: 'Quale fanale è mostrato?',
        imagePath: 'figures/fanale-b.png',
      );
      expect(
        examQuestionContentKey(first),
        isNot(examQuestionContentKey(second)),
      );

      final picked = pickExamQuestions(
        poolByTopic: {
          'NAV': [first, second],
        },
        topicQuotas: const {'NAV': 2},
        random: _StableOrderRandom(),
      );

      expect(picked.map((q) => q.id).toList(), ['figure-a', 'figure-b']);
    });

    test('same wording with a different official answer stays eligible', () {
      final answerB = _contentQuestion(
        id: 'answer-b',
        prompt: 'La prua indica:',
        correctOption: QuizAnswerOption.b,
      );
      final answerC = _contentQuestion(
        id: 'answer-c',
        prompt: 'La prua indica:',
        correctOption: QuizAnswerOption.c,
      );
      expect(
        examQuestionContentKey(answerB),
        isNot(examQuestionContentKey(answerC)),
      );

      final picked = pickExamQuestions(
        poolByTopic: {
          'NAV': [answerB, answerC],
        },
        topicQuotas: const {'NAV': 2},
        random: _StableOrderRandom(),
      );

      expect(picked.map((q) => q.id).toSet(), {'answer-b', 'answer-c'});
    });

    test('the same question id is still drawn once', () {
      final repeated = _q('NAV-same');
      final other = _q('NAV-other');

      final shortfall = findExamTopicPoolShortfall(
        poolByTopic: {
          'NAV': [repeated, repeated, other],
        },
        topicQuotas: const {'NAV': 2},
      );
      expect(shortfall, isNull);

      final picked = pickExamQuestions(
        poolByTopic: {
          'NAV': [repeated, repeated, other],
        },
        topicQuotas: const {'NAV': 2},
        random: _StableOrderRandom(),
      );

      expect(picked.map((q) => q.id).toList(), ['NAV-same', 'NAV-other']);
    });

    test('too little unique content fails without borrowing another topic', () {
      final pool = _poolForQuotas(ExamQuizRules.a12TopicQuotas, perTopic: 6);
      pool['NAV'] = [
        _officialReprint('nav-reprint-a'),
        _officialReprint('nav-reprint-b'),
        _contentQuestion(id: 'nav-pair-a', prompt: 'Seconda domanda NAV.'),
        _contentQuestion(id: 'nav-pair-b', prompt: 'Seconda domanda NAV.'),
      ];

      final shortfall = findExamTopicPoolShortfall(
        poolByTopic: pool,
        topicQuotas: ExamQuizRules.a12TopicQuotas,
      );
      expect(shortfall?.topic, 'NAV');
      expect(shortfall?.required, 4);
      expect(shortfall?.available, 2);

      final picked = pickExamQuestions(
        poolByTopic: pool,
        topicQuotas: ExamQuizRules.a12TopicQuotas,
        random: _StableOrderRandom(),
      );

      expect(picked.length, lessThan(20));
      expect(picked.where((q) => q.id.startsWith('nav-')).length, 2);
      expect(picked.where((q) => q.id.startsWith('SCAFO-')).length, 1);
      expect(picked.where((q) => q.id.startsWith('MOTORE-')).length, 1);
    });

    test('D1 skips a content reprint and keeps the official quotas', () {
      final pool = _poolForQuotas(
        ExamQuizRules.d1TopicQuotas,
        perTopic: 5,
        licenseCategory: 'D1',
      );
      pool['MOTORE'] = [
        _contentQuestion(
          id: 'MOTORE-reprint-a',
          prompt: 'Il motore è in folle.',
          licenseCategory: 'D1',
        ),
        _contentQuestion(
          id: 'MOTORE-reprint-b',
          prompt: 'Il motore è in folle.',
          licenseCategory: 'D1',
        ),
        _q('MOTORE-unique', licenseCategory: 'D1'),
      ];

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
        random: _StableOrderRandom(),
      );

      expect(picked.length, 15);
      expect(
        picked.map((q) => q.id).where((id) => id.startsWith('MOTORE-reprint')),
        ['MOTORE-reprint-a'],
      );
      expect(picked.where((q) => q.id.startsWith('MOTORE-')).length, 2);
      expect(examTopicQuotasForCategory('D1'), ExamQuizRules.d1TopicQuotas);
      expect(
        ExamQuizRules.d1TopicQuotas.values.fold<int>(0, (a, b) => a + b),
        15,
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
