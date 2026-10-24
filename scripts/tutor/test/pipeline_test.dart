import 'dart:convert';
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
  }) {
    return TutorRunRequest(
      selection: const TutorSelection(limit: 1),
      generate: generate,
      write: write,
      regenerate: regenerate,
      forceApproved: forceApproved,
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
