import 'package:test/test.dart';
import 'package:tutor_liana_generator/tutor_generator.dart';

import 'support.dart';

void main() {
  const clean = 'Il nodo misura la velocità, non la distanza.';

  test('a missing space after a comma, semicolon, or colon is inserted', () {
    expect(normalizeTutorTypographyText('velocità,non'), 'velocità, non');
    expect(
      normalizeTutorTypographyText(
        'Se navighi a velocità costante di 5 nodi,in un’ora.',
      ),
      'Se navighi a velocità costante di 5 nodi, in un’ora.',
    );
    expect(normalizeTutorTypographyText('vero;quindi'), 'vero; quindi');
    expect(
      normalizeTutorTypographyText('attenzione:questa'),
      'attenzione: questa',
    );
  });

  test('numbers, times, URLs, and technical notation stay unchanged', () {
    const unchanged = [
      '1,5',
      '10,25',
      '12:30',
      '4:6',
      'https://example.com',
      'http://example.com/a',
      'VHF/FM',
      'MF/HF',
      '10kW',
      '6NM',
      '12V',
      '30°',
      "60'",
      '5nodi',
      '-5',
      '6 NM',
      '12 V',
      'Rotta N',
      'Rotta NE',
    ];
    for (final text in unchanged) {
      expect(normalizeTutorTypographyText(text), text, reason: text);
    }
  });

  test('correct spacing is unchanged and the normalizer is idempotent', () {
    expect(normalizeTutorTypographyText(clean), clean);
    final once = normalizeTutorTypographyText('velocità,non;quindi:questa');
    expect(normalizeTutorTypographyText(once), once);
    expect(once, 'velocità, non; quindi: questa');
  });

  test('all three Tutor fields are normalized', () {
    final output = normalizeTutorTypographyOutput(
      const TutorParsedOutput(
        explanation: 'velocità,non',
        simpleExplanation: 'vero;quindi',
        memoryExample: 'attenzione:questa',
        needsReview: false,
        reviewReason: null,
      ),
    );
    expect(output.explanation, 'velocità, non');
    expect(output.simpleExplanation, 'vero; quindi');
    expect(output.memoryExample, 'attenzione: questa');
    expect(output.needsReview, isFalse);
  });

  test('5nodi is still rejected and is not repaired', () {
    expect(
      normalizeTutorTypographyText('Se navighi a 5nodi.'),
      'Se navighi a 5nodi.',
    );
    final report = validateTutorOutput(
      normalizeTutorTypographyOutput(
        const TutorParsedOutput(
          explanation: 'Se navighi a 5nodi.',
          simpleExplanation: 'Il ritmo resta quello.',
          memoryExample: 'Pensala come una boa.',
          needsReview: false,
          reviewReason: null,
        ),
      ),
      correctOption: 'A',
    );
    expect(report.acceptForReview, isFalse);
    expect(report.rejections, contains('concatenated_number_word'));
  });

  test('semantic and technical copyedit guards stay in place', () {
    expect(
      verifyTutorCopyedit(
        beforeExplanation: 'La prua della barca resta visibile.',
        beforeSimple: 'Il vento arriva da nord.',
        beforeMemory: 'Rotta N.',
        afterExplanation: 'La poppa della barca resta visibile.',
        afterSimple: 'Il vento arriva da sud.',
        afterMemory: 'Rotta S.',
      ).rejections,
      containsAll(['copyedit_rewrite', 'copyedit_technical_token_changed']),
    );
    expect(
      verifyTutorCopyedit(
        beforeExplanation: 'La correzione è -5 gradi.',
        beforeSimple: 'Il limite è 6 NM.',
        beforeMemory: 'La batteria è da 12 V e l angolo è 30° sul canale VHF.',
        afterExplanation: 'La correzione è 5 gradi.',
        afterSimple: 'Il limite è 6 M.',
        afterMemory:
            'La batteria è da 12 A e l angolo è 30\' sul canale MF/HF.',
      ).rejections,
      containsAll([
        'copyedit_number_changed',
        'copyedit_technical_token_changed',
      ]),
    );
  });

  test(
    'a live-style copyedit echo is spaced locally and not marked as a model change',
    () async {
      const simple = 'Il nodo misura la velocità,non la distanza.';
      const memory =
          'Se navighi a velocità costante di 5 nodi,in un’ora percorri 5 miglia marine.';
      final generated = validModelJson()
        ..['simple_explanation'] = simple
        ..['memory_example'] = memory;
      final provider = ScriptedProvider(
        [generated],
        copyedits: [
          {
            'explanation': generated['explanation'],
            'simple_explanation': simple,
            'memory_example': memory,
            'changed': false,
            'review_reason': null,
          },
        ],
      );
      final summary =
          await TutorPipeline(
            catalog: FixedCatalog([catalogItem(sampleQuestion())]),
            store: ThrowingStore(),
            provider: provider,
            images: UnavailableImageSource(),
            clock: () => DateTime.utc(2026, 10, 27),
          ).run(
            const TutorRunRequest(
              selection: TutorSelection(limit: 1),
              generate: true,
              write: false,
              regenerate: false,
              forceApproved: false,
              showOutput: true,
              copyedit: true,
            ),
          );
      final item = summary.items.single;
      expect(summary.dbWrites, 0);
      expect(provider.copyeditCalls, 1);
      expect(item.outcome, 'review_required');
      expect(item.copyeditChanged, isFalse);
      expect(item.typographyNormalized, isTrue);
      expect(
        item.simpleExplanation,
        'Il nodo misura la velocità, non la distanza.',
      );
      expect(
        item.memoryExample,
        'Se navighi a velocità costante di 5 nodi, in un’ora percorri 5 miglia marine.',
      );
      expect(item.simpleExplanation, isNot(contains(',non')));
      expect(item.memoryExample, isNot(contains(',in')));
      expect(provider.lastCopyedit?.simpleExplanation, contains(', non'));
    },
  );
}
