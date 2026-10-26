import 'dart:convert';

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
      'db_writes': dbWrites,
      'model': model,
      'input_tokens': inputTokens,
      'output_tokens': outputTokens,
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
      final model = item.model;
      final input = item.inputTokens;
      final output = item.outputTokens;
      if (model == null || input == null || output == null) {
        costKnown = false;
        break;
      }
      final part = request.pricing.estimate(
        model: model,
        inputTokens: input,
        outputTokens: output,
      );
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
      int providerCalls = 0,
      int dbWrites = 0,
      String? model,
      int? inputTokens,
      int? outputTokens,
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
      return TutorItemResult(
        questionId: question.id,
        category: question.licenseCategory,
        lessonNumber: question.lessonNumber,
        topic: question.topicCode,
        hasImage: question.hasImage,
        sourceHash: item.sourceHash,
        action: action.label,
        existingStatus: item.existing?.status,
        providerCalls: providerCalls,
        dbWrites: dbWrites,
        outcome: outcome,
        model: model,
        inputTokens: inputTokens,
        outputTokens: outputTokens,
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
    var providerCalls = 0;
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
          providerCalls += 1;
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
          providerCalls: providerCalls,
          model: response.modelId,
          inputTokens: response.usage.inputTokens,
          outputTokens: response.usage.outputTokens,
          durationMs: duration,
          rejections: quality.rejections,
          flags: quality.flags,
          needsReview: parsed.needsReview,
          generationReviewReason: reviewReason,
          providerRequestId: response.requestId,
          providerResponseId: response.responseId,
        );
      }
      final payload = TutorWritePayload(
        questionId: question.id,
        sourceHash: item.sourceHash,
        explanation: parsed.explanation.trim(),
        simpleExplanation: parsed.simpleExplanation.trim(),
        memoryExample: parsed.memoryExample.trim(),
        model: response.modelId,
        generatedAt: clock().toUtc(),
        output: parsed,
      );
      if (payload.status != tutorStoredStatus ||
          payload.approvedAt != null ||
          payload.reviewedAt != null ||
          payload.promptVersion != tutorLianaPromptVersion ||
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
        providerCalls: providerCalls,
        dbWrites: writes,
        model: response.modelId,
        inputTokens: response.usage.inputTokens,
        outputTokens: response.usage.outputTokens,
        durationMs: duration,
        flags: quality.flags,
        needsReview: parsed.needsReview,
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
        providerCalls: providerCalls,
        rejections: ['malformed_output'],
        flags: [error.message],
      );
    } on OpenAITutorException catch (error) {
      return base(
        outcome: 'failed',
        providerCalls: providerCalls,
        rejections: [error.refusal ? 'provider_refusal' : 'provider_error'],
        flags: [error.message],
        providerRequestId: error.requestId,
      );
    } catch (error) {
      return base(
        outcome: 'failed',
        providerCalls: providerCalls,
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

String tutorSummaryLine(TutorRunSummary summary) =>
    jsonEncode(summary.toJson());
