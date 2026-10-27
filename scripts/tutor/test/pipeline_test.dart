import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:tutor_liana_generator/tutor_generator.dart';

import 'support.dart';

void main() {
  final fixedNow = DateTime.utc(2026, 10, 24, 12);

  TutorPipeline pipeline({
    required TutorCatalog catalog,
    required TutorGenerationProvider provider,
    required TutorExplanationStore store,
    TutorImageSource? images,
  }) {
    return TutorPipeline(
      catalog: catalog,
      store: store,
      provider: provider,
      images: images ?? UnavailableImageSource(),
      clock: () => fixedNow,
    );
  }

  TutorRunRequest request({
    bool generate = false,
    bool write = false,
    bool regenerate = false,
    bool forceApproved = false,
    bool showOutput = false,
  }) {
    return TutorRunRequest(
      selection: const TutorSelection(limit: 1),
      generate: generate,
      write: write,
      regenerate: regenerate,
      forceApproved: forceApproved,
      showOutput: showOutput,
    );
  }

  test('dry run makes no provider call and no write', () async {
    final provider = ScriptedProvider([StateError('must not be called')]);
    final store = ThrowingStore();
    final catalog = FixedCatalog([catalogItem(sampleQuestion())]);
    final summary = await pipeline(
      catalog: catalog,
      provider: provider,
      store: store,
    ).run(request());
    expect(provider.calls, 0);
    expect(summary.providerCalls, 0);
    expect(summary.dbWrites, 0);
    expect(summary.generated, 0);
    expect(summary.items.single.action, 'GENERATE');
    expect(summary.items.single.outcome, 'planned');
    expect(summary.inputTokens, 0);
    expect(summary.inputTokensComplete, isTrue);
    expect(summary.outputTokensComplete, isTrue);
  });

  test('--generate without a live adapter fails before any call', () async {
    final catalog = FixedCatalog([catalogItem(sampleQuestion())]);
    final run = pipeline(
      catalog: catalog,
      provider: RefusingTutorProvider(),
      store: ThrowingStore(),
    ).run(request(generate: true));
    await expectLater(run, throwsA(isA<TutorProviderUnavailable>()));
    expect(catalog.loads, 0);
  });

  test('a new write is review_required and leaves approval empty', () async {
    final store = MemoryTutorStore();
    final summary = await pipeline(
      catalog: FixedCatalog([catalogItem(sampleQuestion())]),
      provider: ScriptedProvider([validModelJson()]),
      store: store,
    ).run(request(generate: true, write: true));
    expect(summary.dbWrites, 1);
    expect(summary.reviewRequired, 1);
    expect(store.inserts, hasLength(1));
    expect(store.updates, isEmpty);
    expect(store.inserts.single.status, 'review_required');
    expect(store.inserts.single.approvedAt, isNull);
    expect(store.inserts.single.reviewedAt, isNull);
    expect(store.inserts.single.copyeditVersion, isNull);
    expect(store.inserts.single.promptVersion, tutorLianaPromptVersion);
    expect(store.inserts.single.model, 'test-model');
    expect(store.inserts.single.generatedAt, fixedNow);
    expect(summary.inputTokens, 10);
    expect(summary.outputTokens, 4);
  });

  test('an approved current row is not overwritten or regenerated', () async {
    final question = sampleQuestion();
    final hash = tutorSourceHash(question);
    final provider = ScriptedProvider([validModelJson()]);
    final store = MemoryTutorStore();
    final summary = await pipeline(
      catalog: FixedCatalog([
        catalogItem(
          question,
          sourceHash: hash,
          existing: TutorExistingRow(
            questionId: question.id,
            sourceHash: hash,
            status: 'approved',
          ),
        ),
      ]),
      provider: provider,
      store: store,
    ).run(request(generate: true, write: true, regenerate: true));
    expect(provider.calls, 0);
    expect(store.inserts, isEmpty);
    expect(store.updates, isEmpty);
    expect(summary.items.single.action, 'SKIP_APPROVED_CURRENT');
  });

  test('force-approved rewrites the row back to review_required', () async {
    final question = sampleQuestion();
    final hash = tutorSourceHash(question);
    final store = MemoryTutorStore();
    await pipeline(
      catalog: FixedCatalog([
        catalogItem(
          question,
          existing: TutorExistingRow(
            questionId: question.id,
            sourceHash: hash,
            status: 'approved',
          ),
        ),
      ]),
      provider: ScriptedProvider([validModelJson()]),
      store: store,
    ).run(request(generate: true, write: true, forceApproved: true));
    expect(store.updates, hasLength(1));
    expect(store.updates.single.payload.status, 'review_required');
    expect(store.updates.single.payload.approvedAt, isNull);
    expect(
      store.updates.single.filter,
      forcedUpdateFilter(questionId: question.id),
    );
  });

  test('an approved stale row is regenerated as review_required', () async {
    final question = sampleQuestion();
    final store = MemoryTutorStore();
    final current = tutorSourceHash(question);
    await pipeline(
      catalog: FixedCatalog([
        catalogItem(
          question,
          sourceHash: current,
          existing: TutorExistingRow(
            questionId: question.id,
            sourceHash: 'c' * 64,
            status: 'approved',
          ),
        ),
      ]),
      provider: ScriptedProvider([validModelJson()]),
      store: store,
    ).run(request(generate: true, write: true));
    expect(store.updates.single.payload.status, 'review_required');
    expect(store.updates.single.payload.sourceHash, current);
    expect(store.updates.single.payload.approvedAt, isNull);
    expect(
      store.updates.single.filter,
      protectedUpdateFilter(questionId: question.id, currentHash: current),
    );
  });

  test('a missing image does not call the provider or write', () async {
    final provider = ScriptedProvider([validModelJson()]);
    final store = MemoryTutorStore();
    final summary = await pipeline(
      catalog: FixedCatalog([
        catalogItem(sampleQuestion(imagePath: 'figures/figura_9.png')),
      ]),
      provider: provider,
      store: store,
      images: _BrokenImages(),
    ).run(request(generate: true, write: true));
    expect(provider.calls, 0);
    expect(summary.dbWrites, 0);
    expect(summary.items.single.rejections, contains('image_unreadable'));
  });

  test(
    'pricing stays unset when the catalog has no price for the model',
    () async {
      final summary = await pipeline(
        catalog: FixedCatalog([catalogItem(sampleQuestion())]),
        provider: ScriptedProvider([validModelJson()]),
        store: MemoryTutorStore(),
      ).run(request(generate: true));
      expect(summary.estimatedCostUsd, isNull);
      expect(summary.dbWrites, 0);
      expect(summary.inputTokensComplete, isTrue);
    },
  );

  test('unknown token usage is not counted as zero', () async {
    final summary =
        await pipeline(
          catalog: FixedCatalog([catalogItem(sampleQuestion())]),
          provider: ScriptedProvider([
            validModelJson(),
          ], usage: const TutorUsage()),
          store: MemoryTutorStore(),
        ).run(
          TutorRunRequest(
            selection: const TutorSelection(limit: 1),
            generate: true,
            write: false,
            regenerate: false,
            forceApproved: false,
            pricing: PricingCatalog({
              'test-model': const ModelPrice(
                inputUsdPerMillion: 1,
                outputUsdPerMillion: 1,
              ),
            }),
          ),
        );
    expect(summary.providerCalls, 1);
    expect(summary.inputTokens, isNull);
    expect(summary.outputTokens, isNull);
    expect(summary.inputTokensComplete, isFalse);
    expect(summary.outputTokensComplete, isFalse);
    expect(summary.estimatedCostUsd, isNull);
    expect(summary.dbWrites, 0);
  });

  test('needs_review true persists the trimmed review reason', () async {
    final json = validModelJson()
      ..['needs_review'] = true
      ..['review_reason'] = ' Motivo di verifica ';
    final store = MemoryTutorStore();
    final summary = await pipeline(
      catalog: FixedCatalog([catalogItem(sampleQuestion())]),
      provider: ScriptedProvider([json]),
      store: store,
    ).run(request(generate: true, write: true));
    final payload = store.inserts.single;
    expect(payload.status, 'review_required');
    expect(payload.approvedAt, isNull);
    expect(payload.reviewedAt, isNull);
    expect(payload.generationReviewReason, 'Motivo di verifica');
    expect(payload.toJson()['generation_review_reason'], 'Motivo di verifica');
    expect(summary.items.single.needsReview, isTrue);
    expect(summary.items.single.generationReviewReason, 'Motivo di verifica');
    expect(summary.items.single.toJson()['needs_review'], isTrue);
  });

  test(
    'needs_review false clears a previous generation review reason',
    () async {
      final question = sampleQuestion();
      final hash = tutorSourceHash(question);
      final store = MemoryTutorStore();
      await pipeline(
        catalog: FixedCatalog([
          catalogItem(
            question,
            sourceHash: hash,
            existing: TutorExistingRow(
              questionId: question.id,
              sourceHash: hash,
              status: 'review_required',
            ),
          ),
        ]),
        provider: ScriptedProvider([validModelJson()]),
        store: store,
      ).run(request(generate: true, write: true, regenerate: true));
      final payload = store.updates.single.payload;
      expect(payload.toJson().containsKey('generation_review_reason'), isTrue);
      expect(payload.generationReviewReason, isNull);
      expect(payload.status, 'review_required');
      expect(payload.approvedAt, isNull);
      expect(payload.reviewedAt, isNull);
    },
  );

  test('a blank review reason is not written', () async {
    final json = validModelJson()
      ..['needs_review'] = true
      ..['review_reason'] = '   ';
    final store = MemoryTutorStore();
    final summary = await pipeline(
      catalog: FixedCatalog([catalogItem(sampleQuestion())]),
      provider: ScriptedProvider([json]),
      store: store,
    ).run(request(generate: true, write: true));
    expect(summary.items.single.flags, contains('missing_review_reason'));
    expect(store.inserts.single.generationReviewReason, isNull);
    expect(store.inserts.single.toJson()['generation_review_reason'], isNull);
    expect(summary.dbWrites, 1);
  });

  test('needs_review false drops a leftover review reason', () async {
    final json = validModelJson()..['review_reason'] = 'unnecessary';
    final store = MemoryTutorStore();
    final summary = await pipeline(
      catalog: FixedCatalog([catalogItem(sampleQuestion())]),
      provider: ScriptedProvider([json]),
      store: store,
    ).run(request(generate: true, write: true));
    expect(summary.items.single.flags, contains('ignored_review_reason'));
    expect(store.inserts.single.generationReviewReason, isNull);
    expect(summary.items.single.generationReviewReason, isNull);
    expect(summary.items.single.needsReview, isFalse);
  });

  test('a generated current row is skipped and is not written', () async {
    final question = sampleQuestion();
    final hash = tutorSourceHash(question);
    final provider = ScriptedProvider([validModelJson()]);
    final store = MemoryTutorStore();
    final summary = await pipeline(
      catalog: FixedCatalog([
        catalogItem(
          question,
          sourceHash: hash,
          existing: TutorExistingRow(
            questionId: question.id,
            sourceHash: hash,
            status: 'generated',
          ),
        ),
      ]),
      provider: provider,
      store: store,
    ).run(request(generate: true, write: true));
    expect(provider.calls, 0);
    expect(summary.dbWrites, 0);
    expect(store.inserts, isEmpty);
    expect(store.updates, isEmpty);
    expect(summary.items.single.action, 'SKIP_REVIEW_CURRENT');
  });

  test('a same-hash stale row is eligible without --regenerate', () async {
    final question = sampleQuestion();
    final hash = tutorSourceHash(question);
    final provider = ScriptedProvider([validModelJson()]);
    final planned = await pipeline(
      catalog: FixedCatalog([
        catalogItem(
          question,
          sourceHash: hash,
          existing: TutorExistingRow(
            questionId: question.id,
            sourceHash: hash,
            status: 'stale',
          ),
        ),
      ]),
      provider: provider,
      store: ThrowingStore(),
    ).run(request());
    expect(provider.calls, 0);
    expect(planned.dbWrites, 0);
    expect(planned.items.single.action, 'REGENERATE_MARKED_STALE');
    expect(planned.items.single.outcome, 'planned');
  });

  test('a validated png is passed to the provider', () async {
    final png = Uint8List.fromList([
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
      0x00,
    ]);
    final provider = ScriptedProvider([validModelJson()]);
    await pipeline(
      catalog: FixedCatalog([
        catalogItem(sampleQuestion(imagePath: 'figures/figura_10.png')),
      ]),
      provider: provider,
      store: MemoryTutorStore(),
      images: _RawImage(bytes: png, mediaType: 'image/png'),
    ).run(request(generate: true, write: true));
    expect(provider.calls, 1);
    expect(provider.lastRequest!.imageMediaType, 'image/png');
    expect(identical(provider.lastRequest!.imageBytes, png), isTrue);
  });

  test('html served as a png is not sent to the provider', () async {
    final provider = ScriptedProvider([validModelJson()]);
    final store = MemoryTutorStore();
    final summary = await pipeline(
      catalog: FixedCatalog([
        catalogItem(sampleQuestion(imagePath: 'figures/figure.png')),
      ]),
      provider: provider,
      store: store,
      images: _RawImage(
        bytes: Uint8List.fromList(utf8.encode('<html>not an image</html>')),
        mediaType: 'text/html',
      ),
    ).run(request(generate: true, write: true));
    expect(provider.calls, 0);
    expect(summary.dbWrites, 0);
    expect(store.inserts, isEmpty);
    expect(summary.items.single.rejections, contains('image_unreadable'));
  });

  test('a png content type with a non-png body is rejected', () async {
    final provider = ScriptedProvider([validModelJson()]);
    final store = MemoryTutorStore();
    final summary = await pipeline(
      catalog: FixedCatalog([
        catalogItem(sampleQuestion(imagePath: 'figures/figura_10.png')),
      ]),
      provider: provider,
      store: store,
      images: _RawImage(
        bytes: Uint8List.fromList(utf8.encode('<html>not an image</html>')),
        mediaType: 'image/png',
      ),
    ).run(request(generate: true, write: true));
    expect(provider.calls, 0);
    expect(summary.dbWrites, 0);
    expect(store.inserts, isEmpty);
    expect(summary.items.single.rejections, contains('image_unreadable'));
  });

  test('a png path with a jpeg body is rejected', () async {
    final provider = ScriptedProvider([validModelJson()]);
    final store = MemoryTutorStore();
    final summary = await pipeline(
      catalog: FixedCatalog([
        catalogItem(sampleQuestion(imagePath: 'figures/figura_10.png')),
      ]),
      provider: provider,
      store: store,
      images: _RawImage(
        bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]),
        mediaType: 'image/jpeg',
      ),
    ).run(request(generate: true, write: true));
    expect(provider.calls, 0);
    expect(summary.dbWrites, 0);
    expect(store.inserts, isEmpty);
    expect(summary.items.single.rejections, contains('image_unreadable'));
  });

  test('default generation does not expose Tutor texts', () async {
    final events = <Map<String, Object?>>[];
    final summary = await TutorPipeline(
      catalog: FixedCatalog([catalogItem(sampleQuestion())]),
      store: ThrowingStore(),
      provider: ScriptedProvider([validModelJson()]),
      images: UnavailableImageSource(),
      clock: () => fixedNow,
      log: events.add,
    ).run(request(generate: true));
    final item = summary.items.single.toJson();
    expect(item.keys.toSet(), _defaultItemKeys);
    expect(item.containsKey('explanation'), isFalse);
    expect(item.containsKey('simple_explanation'), isFalse);
    expect(item.containsKey('memory_example'), isFalse);
    expect(events.single.keys.toSet(), _defaultItemKeys);
    expect(jsonEncode(events.single), isNot(contains('La risposta ufficiale')));
    expect(summary.toJson().containsKey('explanation'), isFalse);
    expect(summary.dbWrites, 0);
  });

  test('--show-output exposes only the validated Tutor texts', () async {
    final model = validModelJson();
    final explanation = model['explanation']! as String;
    final simple = model['simple_explanation']! as String;
    final memory = model['memory_example']! as String;
    model['explanation'] = '  $explanation  ';
    model['simple_explanation'] = '  $simple  ';
    model['memory_example'] = '  $memory  ';
    final events = <Map<String, Object?>>[];
    final summary = await TutorPipeline(
      catalog: FixedCatalog([catalogItem(sampleQuestion())]),
      store: ThrowingStore(),
      provider: ScriptedProvider([model]),
      images: UnavailableImageSource(),
      clock: () => fixedNow,
      log: events.add,
    ).run(request(generate: true, showOutput: true));
    final item = events.single;
    expect(item.keys.toSet(), {..._defaultItemKeys, ..._outputKeys});
    expect(item['explanation'], explanation);
    expect(item['simple_explanation'], simple);
    expect(item['memory_example'], memory);
    expect(item['needs_review'], isFalse);
    expect(item['generation_review_reason'], isNull);
    expect(item['db_writes'], 0);
    expect(summary.dbWrites, 0);
    expect(summary.items.single.outcome, 'review_required');
    final encoded = jsonEncode(item);
    expect(encoded, isNot(contains('  $explanation')));
    expect(encoded, isNot(contains('Authorization')));
    expect(encoded, isNot(contains('OPENAI_API_KEY')));
    expect(summary.toJson().containsKey('explanation'), isFalse);
  });

  test('--show-output does not enable a database write', () async {
    final summary = await pipeline(
      catalog: FixedCatalog([catalogItem(sampleQuestion())]),
      provider: ScriptedProvider([validModelJson()]),
      store: ThrowingStore(),
    ).run(request(generate: true, showOutput: true));
    expect(summary.dbWrites, 0);
    expect(summary.items.single.dbWrites, 0);
    expect(summary.items.single.explanation, isNotNull);
  });

  test('--show-output hides malformed and refused provider content', () async {
    const marker = 'RAW_PROVIDER_BODY_MARKER_9f3a';
    final malformed = await TutorPipeline(
      catalog: FixedCatalog([catalogItem(sampleQuestion())]),
      store: ThrowingStore(),
      provider: ScriptedProvider([
        {'explanation': marker, 'unexpected': true},
      ]),
      images: UnavailableImageSource(),
      clock: () => fixedNow,
      log: (event) {
        final encoded = jsonEncode(event);
        expect(encoded, isNot(contains(marker)));
        expect(event.containsKey('explanation'), isFalse);
        expect(event['rejections'], contains('malformed_output'));
      },
    ).run(request(generate: true, showOutput: true));
    expect(malformed.dbWrites, 0);
    expect(malformed.items.single.explanation, isNull);

    final refused = await TutorPipeline(
      catalog: FixedCatalog([catalogItem(sampleQuestion())]),
      store: ThrowingStore(),
      provider: ScriptedProvider([
        OpenAITutorException('model refusal', transient: false, refusal: true),
      ]),
      images: UnavailableImageSource(),
      clock: () => fixedNow,
      log: (event) {
        expect(jsonEncode(event), isNot(contains(marker)));
        expect(event.containsKey('explanation'), isFalse);
        expect(event['rejections'], contains('provider_refusal'));
        expect(event['flags'], ['model refusal']);
      },
    ).run(request(generate: true, showOutput: true));
    expect(refused.dbWrites, 0);

    final rejected = validModelJson()
      ..['explanation'] = 'La risposta corretta è b. $marker';
    final invalid = await TutorPipeline(
      catalog: FixedCatalog([catalogItem(sampleQuestion())]),
      store: ThrowingStore(),
      provider: ScriptedProvider([rejected]),
      images: UnavailableImageSource(),
      clock: () => fixedNow,
      log: (event) {
        expect(jsonEncode(event), isNot(contains(marker)));
        expect(event.containsKey('explanation'), isFalse);
        expect(event['rejections'], contains('contradicts_official_answer'));
      },
    ).run(request(generate: true, write: true, showOutput: true));
    expect(invalid.dbWrites, 0);
    expect(invalid.items.single.explanation, isNull);
  });

  test('glued number words fail once and stay hidden', () async {
    const marker = 'Se navighi a 5nodi per un’ora.';
    final provider = ScriptedProvider([
      validModelJson()
        ..['explanation'] = marker
        ..['simple_explanation'] = 'Percorri 10metri.'
        ..['memory_example'] = 'Per 20minuti.',
    ]);
    final events = <Map<String, Object?>>[];
    final summary = await TutorPipeline(
      catalog: FixedCatalog([catalogItem(sampleQuestion())]),
      store: ThrowingStore(),
      provider: provider,
      images: UnavailableImageSource(),
      clock: () => fixedNow,
      log: events.add,
    ).run(request(generate: true, write: true, showOutput: true));
    expect(provider.calls, 1);
    expect(summary.providerCalls, 1);
    expect(summary.dbWrites, 0);
    expect(summary.items.single.outcome, 'failed');
    expect(summary.items.single.explanation, isNull);
    expect(
      summary.items.single.rejections,
      contains('concatenated_number_word'),
    );
    final encoded = jsonEncode(events.single);
    expect(encoded, isNot(contains(marker)));
    expect(encoded, isNot(contains('10metri')));
    expect(encoded, isNot(contains('20minuti')));
    expect(events.single.containsKey('explanation'), isFalse);
  });

  test('--show-output does not open the provider gate', () async {
    final catalog = FixedCatalog([catalogItem(sampleQuestion())]);
    final run = pipeline(
      catalog: catalog,
      provider: RefusingTutorProvider(),
      store: ThrowingStore(),
    ).run(request(generate: true, showOutput: true));
    await expectLater(run, throwsA(isA<TutorProviderUnavailable>()));
    expect(catalog.loads, 0);
    expect(
      buildTutorProvider(providerName: 'openai', generate: false),
      isA<RefusingTutorProvider>(),
    );
    expect(
      buildTutorProvider(providerName: null, generate: true),
      isA<RefusingTutorProvider>(),
    );
  });

  test(
    'CLI --show-output is display-only and keeps the provider gate',
    () async {
      final help = await Process.run('dart', [
        'run',
        'bin/tutor_generate.dart',
        '--help',
      ]);
      expect(help.exitCode, 0);
      expect(help.stdout, contains('--show-output'));
      expect(help.stdout, contains('does not write'));

      final catalog = await _catalogFile();
      addTearDown(() => catalog.parent.delete(recursive: true));
      final shown = await Process.run('dart', [
        'run',
        'bin/tutor_generate.dart',
        '--catalog',
        catalog.path,
        '--question-id',
        _cliQuestionId,
        '--show-output',
      ]);
      expect(shown.exitCode, 0, reason: '${shown.stdout}\n${shown.stderr}');
      final lines = (shown.stdout as String)
          .trim()
          .split('\n')
          .map((line) => jsonDecode(line) as Map<String, Object?>)
          .toList();
      expect(lines.first.containsKey('explanation'), isFalse);
      expect(lines.first['outcome'], 'planned');
      expect(lines.last['db_writes'], 0);
      expect(shown.stdout, isNot(contains('OPENAI_API_KEY')));

      final writeOnly = await Process.run('dart', [
        'run',
        'bin/tutor_generate.dart',
        '--catalog',
        catalog.path,
        '--question-id',
        _cliQuestionId,
        '--show-output',
        '--write',
      ]);
      expect(writeOnly.exitCode, 2);
      expect(writeOnly.stderr, contains('--write requires --generate'));

      final gated = await Process.run('dart', [
        'run',
        'bin/tutor_generate.dart',
        '--catalog',
        catalog.path,
        '--question-id',
        _cliQuestionId,
        '--generate',
        '--show-output',
      ]);
      expect(gated.exitCode, 2);
      expect(gated.stderr, contains('Refusing --generate'));
      expect(gated.stdout, isNot(contains('explanation')));
    },
  );
}

const _defaultItemKeys = {
  'question_id',
  'category',
  'lesson',
  'topic',
  'image',
  'source_hash',
  'existing_status',
  'action',
  'outcome',
  'needs_review',
  'generation_review_reason',
  'openai_request_id',
  'openai_response_id',
  'provider_calls',
  'generation_provider_calls',
  'copyedit_provider_calls',
  'db_writes',
  'model',
  'input_tokens',
  'output_tokens',
  'generation_input_tokens',
  'generation_output_tokens',
  'copyedit_input_tokens',
  'copyedit_output_tokens',
  'copyedit_model',
  'copyedit_duration_ms',
  'copyedit_changed',
  'copyedit_version',
  'copyedit_openai_request_id',
  'copyedit_openai_response_id',
  'duration_ms',
  'rejections',
  'flags',
};

const _outputKeys = {'explanation', 'simple_explanation', 'memory_example'};

const _cliQuestionId = '11111111-1111-4111-8111-111111111111';

Future<File> _catalogFile() async {
  final directory = await Directory.systemTemp.createTemp('tutor-show-output-');
  final file = File('${directory.path}/catalog.json');
  await file.writeAsString(
    jsonEncode([
      {
        'id': _cliQuestionId,
        'license_category': 'A12',
        'lesson_number': 4,
        'exam_topic_code': 'SCAFO',
        'source_topic_text': 'Lo scafo',
        'prompt': 'Domanda di prova',
        'option_a': 'Uno',
        'option_b': 'Due',
        'option_c': 'Tre',
        'correct_option': 'A',
      },
    ]),
  );
  return file;
}

class _BrokenImages implements TutorImageSource {
  @override
  Future<TutorImageAsset> fetch(String imagePath) {
    throw TutorImageException('unreadable $imagePath');
  }
}

class _RawImage implements TutorImageSource {
  _RawImage({required this.bytes, required this.mediaType});

  final Uint8List bytes;
  final String mediaType;

  @override
  Future<TutorImageAsset> fetch(String imagePath) async {
    return TutorImageAsset(path: imagePath, bytes: bytes, mediaType: mediaType);
  }
}
