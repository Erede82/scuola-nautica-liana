import 'dart:convert';

import 'copyedit.dart';
import 'cost.dart';
import 'eligibility.dart';
import 'image_source.dart';
import 'openai_provider.dart';
import 'persistence.dart';
import 'prompt.dart';
import 'provider.dart';
import 'question.dart';
import 'selection.dart';
import 'validation.dart';

typedef TutorClock = DateTime Function();

class TutorCatalogItem {
  const TutorCatalogItem({
    required this.question,
    required this.sourceHash,
    required this.existing,
  });

  final TutorQuestion question;
  final String sourceHash;
  final TutorExistingRow? existing;
}

abstract class TutorCatalog {
  Future<List<TutorCatalogItem>> load(TutorSelection selection);

  /// Empty pools in a `--sample` selection. Generation is not failed for them.
  List<String> get missingSampleSlots => const [];
}

abstract class TutorExplanationStore {
  Future<void> insert(TutorWritePayload payload);
  Future<void> update({
    required TutorWritePayload payload,
    required String filter,
  });
}

class TutorRunRequest {
  const TutorRunRequest({
    required this.selection,
    required this.generate,
    required this.write,
    required this.regenerate,
    required this.forceApproved,
    this.concurrency = 1,
    this.minInterval = Duration.zero,
    this.maxAttempts = 3,
    this.model,
    this.pricing = const PricingCatalog({}),
    this.showOutput = false,
    this.copyedit = false,
  });

  final TutorSelection selection;
  final bool generate;
  final bool write;
  final bool regenerate;
  final bool forceApproved;
  final int concurrency;
  final Duration minInterval;
  final int maxAttempts;
  final String? model;
  final PricingCatalog pricing;

  /// When true, a validated generation includes the three Tutor texts in the
  /// item JSON. This never persists a row.
  final bool showOutput;

  /// When true, a valid generation is copyedited before it can be shown or
  /// written. This never persists a row by itself.
  final bool copyedit;
}

class TutorItemResult {
  const TutorItemResult({
    required this.questionId,
    required this.category,
    required this.lessonNumber,
    required this.topic,
    required this.hasImage,
    required this.sourceHash,
    required this.action,
    required this.existingStatus,
    required this.providerCalls,
    required this.generationProviderCalls,
    required this.copyeditProviderCalls,
    required this.dbWrites,
    required this.outcome,
    this.model,
    this.inputTokens,
    this.outputTokens,
    this.durationMs,
    this.rejections = const [],
    this.flags = const [],
    this.needsReview,
    this.generationReviewReason,
    this.generationInputTokens,
    this.generationOutputTokens,
    this.copyeditInputTokens,
    this.copyeditOutputTokens,
    this.copyeditModel,
    this.copyeditDurationMs,
    this.copyeditChanged,
    this.copyeditVersion,
    this.copyeditRequestId,
    this.copyeditResponseId,
    this.providerRequestId,
    this.providerResponseId,
    this.explanation,
    this.simpleExplanation,
    this.memoryExample,
  });

  final String questionId;
  final String category;
  final int? lessonNumber;
  final String topic;
  final bool hasImage;
  final String sourceHash;
  final String action;
  final String? existingStatus;
  final int providerCalls;
  final int generationProviderCalls;
  final int copyeditProviderCalls;
  final int dbWrites;
  final String outcome;
  final String? model;
  final int? inputTokens;
  final int? outputTokens;
  final int? durationMs;
  final List<String> rejections;
  final List<String> flags;
  final bool? needsReview;
  final String? generationReviewReason;
  final int? generationInputTokens;
  final int? generationOutputTokens;
  final int? copyeditInputTokens;
  final int? copyeditOutputTokens;
  final String? copyeditModel;
  final int? copyeditDurationMs;
  final bool? copyeditChanged;
  final String? copyeditVersion;
  final String? copyeditRequestId;
  final String? copyeditResponseId;
  final String? providerRequestId;
  final String? providerResponseId;

  /// Validated texts. Null unless `--show-output` followed a successful check.
  final String? explanation;
  final String? simpleExplanation;
  final String? memoryExample;

  Map<String, Object?> toJson() {
    final json = <String, Object?>{
      'question_id': questionId,
      'category': category,
      'lesson': lessonNumber,
      'topic': topic,
      'image': hasImage,
      'source_hash': sourceHash,
      'existing_status': existingStatus,
      'action': action,
      'outcome': outcome,
      'needs_review': needsReview,
      'generation_review_reason': generationReviewReason,
      'openai_request_id': providerRequestId,
      'openai_response_id': providerResponseId,
      'provider_calls': providerCalls,
      'generation_provider_calls': generationProviderCalls,
      'copyedit_provider_calls': copyeditProviderCalls,
      'db_writes': dbWrites,
      'model': model,
      'input_tokens': inputTokens,
      'output_tokens': outputTokens,
      'generation_input_tokens': generationInputTokens,
      'generation_output_tokens': generationOutputTokens,
      'copyedit_input_tokens': copyeditInputTokens,
      'copyedit_output_tokens': copyeditOutputTokens,
      'copyedit_model': copyeditModel,
      'copyedit_duration_ms': copyeditDurationMs,
      'copyedit_changed': copyeditChanged,
      'copyedit_version': copyeditVersion,
      'copyedit_openai_request_id': copyeditRequestId,
      'copyedit_openai_response_id': copyeditResponseId,
      'duration_ms': durationMs,
      'rejections': rejections,
      'flags': flags,
    };
    if (explanation != null) {
      json['explanation'] = explanation;
      json['simple_explanation'] = simpleExplanation;
      json['memory_example'] = memoryExample;
    }
    return json;
  }
}

class TutorRunSummary {
  const TutorRunSummary({
    required this.items,
    required this.providerCalls,
    required this.dbWrites,
    required this.inputTokens,
    required this.outputTokens,
    required this.inputTokensComplete,
    required this.outputTokensComplete,
    required this.estimatedCostUsd,
  });

  final List<TutorItemResult> items;
  final int providerCalls;
  final int dbWrites;
  final int? inputTokens;
  final int? outputTokens;
  final bool inputTokensComplete;
  final bool outputTokensComplete;
  final double? estimatedCostUsd;

  int get selected => items.length;
  int get skipped => items.where((item) => item.outcome == 'skipped').length;
  int get generated =>
      items.where((item) => item.outcome == 'review_required').length;
  int get failed => items.where((item) => item.outcome == 'failed').length;
  int get reviewRequired => generated;

  Map<String, Object?> toJson() {
    return {
      'selected': selected,
      'skipped': skipped,
      'generated': generated,
      'failed': failed,
      'review_required': reviewRequired,
      'provider_calls': providerCalls,
      'db_writes': dbWrites,
      'input_tokens': inputTokens,
      'input_tokens_complete': inputTokensComplete,
      'output_tokens': outputTokens,
      'output_tokens_complete': outputTokensComplete,
      'estimated_cost_usd': estimatedCostUsd,
      'dry_run': providerCalls == 0 && dbWrites == 0,
    };
  }
}

class TutorPipeline {
  TutorPipeline({
    required this.catalog,
    required this.store,
    required this.provider,
    required this.images,
    TutorClock? clock,
    this.log,
  }) : clock = clock ?? DateTime.now;

  final TutorCatalog catalog;
  final TutorExplanationStore store;
  final TutorGenerationProvider provider;
  final TutorImageSource images;
  final TutorClock clock;
  final void Function(Map<String, Object?> event)? log;

  Future<TutorRunSummary> run(TutorRunRequest request) async {
    validateSelection(request.selection);
    if (request.write && !request.generate) {
      throw FormatException('--write requires --generate.');
    }
    if (request.copyedit && !request.generate) {
      throw FormatException('--copyedit requires --generate.');
    }
    if (request.generate && provider is RefusingTutorProvider) {
      throw TutorProviderUnavailable(
        'Refusing --generate. No live provider adapter is installed, '
        'so this run will not call an AI API or write Tutor rows.',
      );
    }

    final selected = await catalog.load(request.selection);
    final concurrency = request.concurrency.clamp(1, 4);
    final results = List<TutorItemResult?>.filled(selected.length, null);
    var next = 0;

    Future<void> worker() async {
      while (true) {
        final index = next;
        next += 1;
        if (index >= selected.length) return;
        results[index] = await _one(selected[index], request);
        final event = results[index]!.toJson();
        log?.call(event);
      }
    }

    final workers = concurrency > selected.length
        ? selected.length
        : concurrency;
    if (workers == 0) {
      return const TutorRunSummary(
        items: [],
        providerCalls: 0,
        dbWrites: 0,
        inputTokens: 0,
        outputTokens: 0,
        inputTokensComplete: true,
        outputTokensComplete: true,
        estimatedCostUsd: null,
      );
    }
    await Future.wait(List.generate(workers, (_) => worker()));
    final items = results.cast<TutorItemResult>();
    final called = items.where((item) => item.providerCalls > 0);
    final inputTokensComplete = called.every(
      (item) => item.inputTokens != null,
    );
    final outputTokensComplete = called.every(
      (item) => item.outputTokens != null,
    );
    final inputTokens = inputTokensComplete
        ? called.fold<int>(0, (sum, item) => sum + item.inputTokens!)
        : null;
    final outputTokens = outputTokensComplete
        ? called.fold<int>(0, (sum, item) => sum + item.outputTokens!)
        : null;
    double? cost;
    var costKnown = true;
    for (final item in items) {
      if (item.providerCalls == 0) continue;
      final part = _pricedPasses(request.pricing, item);
      if (part == null) {
        costKnown = false;
        break;
      }
      cost = (cost ?? 0) + part;
    }
    return TutorRunSummary(
      items: items,
      providerCalls: items.fold(0, (sum, item) => sum + item.providerCalls),
      dbWrites: items.fold(0, (sum, item) => sum + item.dbWrites),
      inputTokens: inputTokens,
      outputTokens: outputTokens,
      inputTokensComplete: inputTokensComplete,
      outputTokensComplete: outputTokensComplete,
      estimatedCostUsd: costKnown ? cost : null,
    );
  }

  Future<TutorItemResult> _one(
    TutorCatalogItem item,
    TutorRunRequest request,
  ) async {
    final question = item.question;
    final action = planTutorAction(
      existing: item.existing,
      currentHash: item.sourceHash,
      regenerate: request.regenerate,
      forceApproved: request.forceApproved,
    );
    TutorItemResult base({
      required String outcome,
      int generationProviderCalls = 0,
      int copyeditProviderCalls = 0,
      int dbWrites = 0,
      String? model,
      int? generationInputTokens,
      int? generationOutputTokens,
      int? copyeditInputTokens,
      int? copyeditOutputTokens,
      String? copyeditModel,
      int? copyeditDurationMs,
      bool? copyeditChanged,
      String? copyeditVersion,
      String? copyeditRequestId,
      String? copyeditResponseId,
      int? durationMs,
      List<String> rejections = const [],
      List<String> flags = const [],
      bool? needsReview,
      String? generationReviewReason,
      String? providerRequestId,
      String? providerResponseId,
      String? explanation,
      String? simpleExplanation,
      String? memoryExample,
    }) {
      final secondRan = copyeditProviderCalls > 0;
      return TutorItemResult(
        questionId: question.id,
        category: question.licenseCategory,
        lessonNumber: question.lessonNumber,
        topic: question.topicCode,
        hasImage: question.hasImage,
        sourceHash: item.sourceHash,
        action: action.label,
        existingStatus: item.existing?.status,
        providerCalls: generationProviderCalls + copyeditProviderCalls,
        generationProviderCalls: generationProviderCalls,
        copyeditProviderCalls: copyeditProviderCalls,
        dbWrites: dbWrites,
        outcome: outcome,
        model: model,
        inputTokens: _sumTokens(
          generationInputTokens,
          copyeditInputTokens,
          secondRan: secondRan,
        ),
        outputTokens: _sumTokens(
          generationOutputTokens,
          copyeditOutputTokens,
          secondRan: secondRan,
        ),
        generationInputTokens: generationInputTokens,
        generationOutputTokens: generationOutputTokens,
        copyeditInputTokens: copyeditInputTokens,
        copyeditOutputTokens: copyeditOutputTokens,
        copyeditModel: copyeditModel,
        copyeditDurationMs: copyeditDurationMs,
        copyeditChanged: copyeditChanged,
        copyeditVersion: copyeditVersion,
        copyeditRequestId: copyeditRequestId,
        copyeditResponseId: copyeditResponseId,
        durationMs: durationMs,
        rejections: rejections,
        flags: flags,
        needsReview: needsReview,
        generationReviewReason: generationReviewReason,
        providerRequestId: providerRequestId,
        providerResponseId: providerResponseId,
        explanation: explanation,
        simpleExplanation: simpleExplanation,
        memoryExample: memoryExample,
      );
    }

    if (!action.callsProvider) {
      return base(outcome: 'skipped');
    }
    if (!request.generate) {
      return base(outcome: 'planned');
    }

    final started = DateTime.now();
    var generationCalls = 0;
    var copyeditCalls = 0;
    try {
      TutorImageAsset? image;
      if (question.hasImage) {
        final path = question.trimmedImagePath!;
        final mediaType = mediaTypeForImagePath(path);
        if (mediaType == null) {
          throw TutorImageException('unsupported image type for $path');
        }
        image = validateQuizImageAsset(await images.fetch(path));
      }
      final prompt = buildTutorPrompt(question, imageAttached: image != null);
      final response = await withBoundedRetries(
        () {
          generationCalls += 1;
          return provider.generate(
            TutorGenerationRequest(
              question: question,
              prompt: prompt,
              model: request.model,
              imageBytes: image?.bytes,
              imageMediaType: image?.mediaType,
            ),
          );
        },
        maxAttempts: request.maxAttempts,
        isTransient: isTransientProviderError,
        delayForAttempt: (attempt) => Duration(milliseconds: 250 * attempt),
      );
      if (request.minInterval > Duration.zero) {
        await Future<void>.delayed(request.minInterval);
      }
      final parsed = parseTutorOutput(response.structuredJson);
      final quality = validateTutorOutput(
        parsed,
        correctOption: question.correctOption,
      );
      final duration = DateTime.now().difference(started).inMilliseconds;
      final reviewReason = persistedGenerationReviewReason(parsed);
      if (!quality.acceptForReview) {
        return base(
          outcome: 'failed',
          generationProviderCalls: generationCalls,
          model: response.modelId,
          generationInputTokens: response.usage.inputTokens,
          generationOutputTokens: response.usage.outputTokens,
          durationMs: duration,
          rejections: quality.rejections,
          flags: quality.flags,
          needsReview: parsed.needsReview,
          generationReviewReason: reviewReason,
          providerRequestId: response.requestId,
          providerResponseId: response.responseId,
        );
      }
      var accepted = parsed;
      var acceptedQuality = quality;
      TutorProviderResponse? copyResponse;
      int? copyeditDurationMs;
      bool? copyeditChanged;
      if (request.copyedit) {
        final copyStarted = DateTime.now();
        try {
          copyResponse = await withBoundedRetries(
            () {
              copyeditCalls += 1;
              return provider.copyedit(
                TutorCopyeditRequest(
                  explanation: parsed.explanation.trim(),
                  simpleExplanation: parsed.simpleExplanation.trim(),
                  memoryExample: parsed.memoryExample.trim(),
                  model: request.model,
                ),
              );
            },
            maxAttempts: request.maxAttempts,
            isTransient: isTransientProviderError,
            delayForAttempt: (attempt) => Duration(milliseconds: 250 * attempt),
          );
        } on TutorCopyeditParseException catch (error) {
          return _copyeditFailure(
            base: base,
            generationCalls: generationCalls,
            copyeditCalls: copyeditCalls,
            generation: response,
            rejections: const ['copyedit_malformed'],
            flags: [error.message],
            started: started,
          );
        } on TutorOutputParseException catch (error) {
          return _copyeditFailure(
            base: base,
            generationCalls: generationCalls,
            copyeditCalls: copyeditCalls,
            generation: response,
            rejections: const ['copyedit_malformed'],
            flags: [error.message],
            started: started,
          );
        } on OpenAITutorException catch (error) {
          return _copyeditFailure(
            base: base,
            generationCalls: generationCalls,
            copyeditCalls: copyeditCalls,
            generation: response,
            copyedit: null,
            rejections: [
              error.refusal ? 'copyedit_refusal' : 'copyedit_provider_error',
            ],
            flags: [error.message],
            requestId: error.requestId,
            started: started,
          );
        } catch (error) {
          return _copyeditFailure(
            base: base,
            generationCalls: generationCalls,
            copyeditCalls: copyeditCalls,
            generation: response,
            rejections: const ['copyedit_provider_error'],
            flags: [error.toString()],
            started: started,
          );
        }
        final receivedCopy = copyResponse!;
        if (request.minInterval > Duration.zero) {
          await Future<void>.delayed(request.minInterval);
        }
        copyeditDurationMs = DateTime.now()
            .difference(copyStarted)
            .inMilliseconds;
        final TutorCopyeditOutput edited;
        try {
          edited = parseTutorCopyedit(receivedCopy.structuredJson);
        } on TutorCopyeditParseException catch (error) {
          return _copyeditFailure(
            base: base,
            generationCalls: generationCalls,
            copyeditCalls: copyeditCalls,
            generation: response,
            copyedit: receivedCopy,
            copyeditDurationMs: copyeditDurationMs,
            rejections: const ['copyedit_malformed'],
            flags: [error.message],
            started: started,
          );
        }
        final beforeExplanation = parsed.explanation.trim();
        final beforeSimple = parsed.simpleExplanation.trim();
        final beforeMemory = parsed.memoryExample.trim();
        final afterExplanation = edited.explanation.trim();
        final afterSimple = edited.simpleExplanation.trim();
        final afterMemory = edited.memoryExample.trim();
        final invariant = verifyTutorCopyedit(
          beforeExplanation: beforeExplanation,
          beforeSimple: beforeSimple,
          beforeMemory: beforeMemory,
          afterExplanation: afterExplanation,
          afterSimple: afterSimple,
          afterMemory: afterMemory,
        );
        copyeditChanged =
            beforeExplanation != afterExplanation ||
            beforeSimple != afterSimple ||
            beforeMemory != afterMemory;
        if (!invariant.accepted) {
          return _copyeditFailure(
            base: base,
            generationCalls: generationCalls,
            copyeditCalls: copyeditCalls,
            generation: response,
            copyedit: receivedCopy,
            copyeditDurationMs: copyeditDurationMs,
            copyeditChanged: copyeditChanged,
            rejections: invariant.rejections,
            started: started,
          );
        }
        final reparsed = TutorParsedOutput(
          explanation: afterExplanation,
          simpleExplanation: afterSimple,
          memoryExample: afterMemory,
          needsReview: parsed.needsReview,
          reviewReason: parsed.reviewReason,
        );
        final requality = validateTutorOutput(
          reparsed,
          correctOption: question.correctOption,
        );
        if (!requality.acceptForReview) {
          return _copyeditFailure(
            base: base,
            generationCalls: generationCalls,
            copyeditCalls: copyeditCalls,
            generation: response,
            copyedit: receivedCopy,
            copyeditDurationMs: copyeditDurationMs,
            copyeditChanged: copyeditChanged,
            rejections: requality.rejections,
            flags: [...requality.flags, 'after_copyedit'],
            started: started,
          );
        }
        accepted = reparsed;
        acceptedQuality = requality;
      }
      final payload = TutorWritePayload(
        questionId: question.id,
        sourceHash: item.sourceHash,
        explanation: accepted.explanation.trim(),
        simpleExplanation: accepted.simpleExplanation.trim(),
        memoryExample: accepted.memoryExample.trim(),
        model: response.modelId,
        generatedAt: clock().toUtc(),
        output: accepted,
        copyeditVersion: request.copyedit ? tutorCopyeditVersion : null,
      );
      final expectedCopyedit = request.copyedit ? tutorCopyeditVersion : null;
      if (payload.status != tutorStoredStatus ||
          payload.approvedAt != null ||
          payload.reviewedAt != null ||
          payload.promptVersion != tutorLianaPromptVersion ||
          payload.copyeditVersion != expectedCopyedit ||
          payload.generationReviewReason != reviewReason ||
          (payload.generationReviewReason != null &&
              payload.generationReviewReason!.trim().isEmpty)) {
        throw StateError('write payload violated the review-only contract');
      }
      var writes = 0;
      if (request.write) {
        await _persist(action, payload, item.sourceHash);
        writes = 1;
      }
      return base(
        outcome: 'review_required',
        generationProviderCalls: generationCalls,
        copyeditProviderCalls: copyeditCalls,
        dbWrites: writes,
        model: response.modelId,
        generationInputTokens: response.usage.inputTokens,
        generationOutputTokens: response.usage.outputTokens,
        copyeditInputTokens: copyResponse?.usage.inputTokens,
        copyeditOutputTokens: copyResponse?.usage.outputTokens,
        copyeditModel: copyResponse?.modelId,
        copyeditDurationMs: copyeditDurationMs,
        copyeditChanged: copyeditChanged,
        copyeditVersion: request.copyedit ? tutorCopyeditVersion : null,
        copyeditRequestId: copyResponse?.requestId,
        copyeditResponseId: copyResponse?.responseId,
        durationMs: DateTime.now().difference(started).inMilliseconds,
        flags: acceptedQuality.flags,
        needsReview: accepted.needsReview,
        generationReviewReason: payload.generationReviewReason,
        providerRequestId: response.requestId,
        providerResponseId: response.responseId,
        explanation: request.showOutput ? payload.explanation : null,
        simpleExplanation: request.showOutput
            ? payload.simpleExplanation
            : null,
        memoryExample: request.showOutput ? payload.memoryExample : null,
      );
    } on TutorImageException catch (error) {
      return base(
        outcome: 'failed',
        rejections: ['image_unreadable'],
        flags: [error.message],
      );
    } on TutorOutputParseException catch (error) {
      return base(
        outcome: 'failed',
        generationProviderCalls: generationCalls,
        copyeditProviderCalls: copyeditCalls,
        rejections: ['malformed_output'],
        flags: [error.message],
      );
    } on OpenAITutorException catch (error) {
      return base(
        outcome: 'failed',
        generationProviderCalls: generationCalls,
        copyeditProviderCalls: copyeditCalls,
        rejections: [error.refusal ? 'provider_refusal' : 'provider_error'],
        flags: [error.message],
        providerRequestId: error.requestId,
      );
    } catch (error) {
      return base(
        outcome: 'failed',
        generationProviderCalls: generationCalls,
        copyeditProviderCalls: copyeditCalls,
        rejections: ['provider_error'],
        flags: [error.toString()],
      );
    }
  }

  Future<void> _persist(
    TutorPlanAction action,
    TutorWritePayload payload,
    String currentHash,
  ) {
    switch (action) {
      case TutorPlanAction.generate:
        return store.insert(payload);
      case TutorPlanAction.forceApproved:
        return store.update(
          payload: payload,
          filter: forcedUpdateFilter(questionId: payload.questionId),
        );
      case TutorPlanAction.regenerateStale:
      case TutorPlanAction.regenerateMarkedStale:
      case TutorPlanAction.regenerateCurrent:
        return store.update(
          payload: payload,
          filter: protectedUpdateFilter(
            questionId: payload.questionId,
            currentHash: currentHash,
          ),
        );
      case TutorPlanAction.skipApprovedCurrent:
      case TutorPlanAction.skipReviewCurrent:
        throw StateError('skipped action cannot write');
    }
  }
}

int? _sumTokens(int? first, int? second, {required bool secondRan}) {
  if (!secondRan) return first;
  if (first == null || second == null) return null;
  return first + second;
}

double? _pricedPasses(PricingCatalog pricing, TutorItemResult item) {
  double total = 0;
  var priced = false;
  double? add(String? model, int? input, int? output, int calls) {
    if (calls == 0) return 0;
    if (model == null || input == null || output == null) return null;
    return pricing.estimate(
      model: model,
      inputTokens: input,
      outputTokens: output,
    );
  }

  final generation = add(
    item.model,
    item.generationInputTokens,
    item.generationOutputTokens,
    item.generationProviderCalls,
  );
  if (item.generationProviderCalls > 0) {
    if (generation == null) return null;
    total += generation;
    priced = true;
  }
  final copyedit = add(
    item.copyeditModel,
    item.copyeditInputTokens,
    item.copyeditOutputTokens,
    item.copyeditProviderCalls,
  );
  if (item.copyeditProviderCalls > 0) {
    if (copyedit == null) return null;
    total += copyedit;
    priced = true;
  }
  return priced ? total : null;
}

TutorItemResult _copyeditFailure({
  required TutorItemResult Function({
    required String outcome,
    int generationProviderCalls,
    int copyeditProviderCalls,
    int dbWrites,
    String? model,
    int? generationInputTokens,
    int? generationOutputTokens,
    int? copyeditInputTokens,
    int? copyeditOutputTokens,
    String? copyeditModel,
    int? copyeditDurationMs,
    bool? copyeditChanged,
    String? copyeditVersion,
    String? copyeditRequestId,
    String? copyeditResponseId,
    int? durationMs,
    List<String> rejections,
    List<String> flags,
    bool? needsReview,
    String? generationReviewReason,
    String? providerRequestId,
    String? providerResponseId,
    String? explanation,
    String? simpleExplanation,
    String? memoryExample,
  })
  base,
  required int generationCalls,
  required int copyeditCalls,
  required TutorProviderResponse generation,
  TutorProviderResponse? copyedit,
  int? copyeditDurationMs,
  bool? copyeditChanged,
  required List<String> rejections,
  List<String> flags = const [],
  String? requestId,
  required DateTime started,
}) {
  return base(
    outcome: 'failed',
    generationProviderCalls: generationCalls,
    copyeditProviderCalls: copyeditCalls,
    model: generation.modelId,
    generationInputTokens: generation.usage.inputTokens,
    generationOutputTokens: generation.usage.outputTokens,
    copyeditInputTokens: copyedit?.usage.inputTokens,
    copyeditOutputTokens: copyedit?.usage.outputTokens,
    copyeditModel: copyedit?.modelId,
    copyeditDurationMs: copyeditDurationMs,
    copyeditChanged: copyeditChanged,
    copyeditVersion: tutorCopyeditVersion,
    copyeditRequestId: requestId ?? copyedit?.requestId,
    copyeditResponseId: copyedit?.responseId,
    durationMs: DateTime.now().difference(started).inMilliseconds,
    rejections: rejections,
    flags: flags,
    providerRequestId: generation.requestId,
    providerResponseId: generation.responseId,
  );
}

String tutorSummaryLine(TutorRunSummary summary) =>
    jsonEncode(summary.toJson());
