import 'dart:typed_data';

import 'prompt.dart';
import 'question.dart';

class TutorUsage {
  const TutorUsage({this.inputTokens, this.outputTokens});

  final int? inputTokens;
  final int? outputTokens;
}

class TutorGenerationRequest {
  const TutorGenerationRequest({
    required this.question,
    required this.prompt,
    required this.model,
    this.imageBytes,
    this.imageMediaType,
  });

  final TutorQuestion question;
  final TutorPrompt prompt;
  final String? model;
  final Uint8List? imageBytes;
  final String? imageMediaType;
}

/// Text-only copyedit. The question and image are not part of this request.
class TutorCopyeditRequest {
  const TutorCopyeditRequest({
    required this.explanation,
    required this.simpleExplanation,
    required this.memoryExample,
    required this.model,
  });

  final String explanation;
  final String simpleExplanation;
  final String memoryExample;
  final String? model;
}

class TutorProviderResponse {
  const TutorProviderResponse({
    required this.modelId,
    required this.structuredJson,
    required this.usage,
    this.requestId,
    this.responseId,
  });

  final String modelId;
  final Object? structuredJson;
  final TutorUsage usage;
  final String? requestId;
  final String? responseId;
}

abstract class TutorGenerationProvider {
  Future<TutorProviderResponse> generate(TutorGenerationRequest request);

  Future<TutorProviderResponse> copyedit(TutorCopyeditRequest request);
}

/// Fail-closed boundary. No vendor HTTP client is bundled.
class RefusingTutorProvider implements TutorGenerationProvider {
  @override
  Future<TutorProviderResponse> generate(TutorGenerationRequest request) {
    throw TutorProviderUnavailable(
      'No live Tutor provider is configured. '
      'Set up a reviewed adapter that reads AI_API_KEY from the environment, '
      'accepts structured JSON, attaches image bytes, and returns token usage. '
      'This foundation does not call an AI API.',
    );
  }

  @override
  Future<TutorProviderResponse> copyedit(TutorCopyeditRequest request) {
    throw TutorProviderUnavailable(
      'No live Tutor provider is configured. '
      'Copyedit is an offline generation pass and does not call an AI API.',
    );
  }
}

class TutorProviderUnavailable implements Exception {
  TutorProviderUnavailable(this.message);
  final String message;
  @override
  String toString() => message;
}

bool isTransientProviderError(Object error) {
  if (error is TutorProviderUnavailable) return false;
  if (error is FormatException) return false;
  final text = error.toString().toLowerCase();
  return text.contains('socket') ||
      text.contains('timeout') ||
      text.contains('timed out') ||
      text.contains('http 429') ||
      text.contains('http 500') ||
      text.contains('http 502') ||
      text.contains('http 503') ||
      text.contains('http 504');
}

Future<T> withBoundedRetries<T>(
  Future<T> Function() action, {
  required int maxAttempts,
  required bool Function(Object error) isTransient,
  Duration Function(int attempt)? delayForAttempt,
}) async {
  Object? lastError;
  final attempts = maxAttempts < 1 ? 1 : maxAttempts;
  for (var attempt = 1; attempt <= attempts; attempt++) {
    try {
      return await action();
    } catch (error) {
      lastError = error;
      final canRetry = attempt < attempts && isTransient(error);
      if (!canRetry) rethrow;
      final delay = delayForAttempt?.call(attempt) ?? Duration.zero;
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }
    }
  }
  throw StateError('retry exhausted: $lastError');
}
