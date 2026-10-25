import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'provider.dart';
import 'validation.dart';

/// Documented model id. The model page lists this id as its snapshot.
const String openAITutorDefaultModel = 'gpt-6.1-sol';

/// Includes visible output and, for reasoning models, reasoning tokens.
const int openAITutorMaxOutputTokens = 1000;

const Duration openAITutorRequestTimeout = Duration(seconds: 90);

final Uri openAIResponsesEndpoint = Uri.parse(
  'https://api.openai.com/v1/responses',
);

const String openAITutorSchemaName = 'tutor_liana_generation';

Map<String, Object?> openAITutorJsonSchema() {
  return {
    'type': 'object',
    'additionalProperties': false,
    'properties': {
      'explanation': {'type': 'string'},
      'simple_explanation': {'type': 'string'},
      'memory_example': {'type': 'string'},
      'needs_review': {'type': 'boolean'},
      'review_reason': {
        'type': ['string', 'null'],
      },
    },
    'required': [
      'explanation',
      'simple_explanation',
      'memory_example',
      'needs_review',
      'review_reason',
    ],
  };
}

String requireOpenAIApiKey(String? key) {
  if (key == null || key.trim().isEmpty) {
    throw FormatException(
      'OPENAI_API_KEY is missing. It is read only when '
      '--provider openai is combined with --generate.',
    );
  }
  if (key.contains(' ') || key.contains('\n') || key.contains('\r')) {
    throw FormatException('OPENAI_API_KEY is malformed');
  }
  return key.trim();
}

/// Selects the live provider. OpenAI is constructed only for an explicit
/// `--provider openai` together with `--generate`.
TutorGenerationProvider buildTutorProvider({
  String? providerName,
  required bool generate,
  String? openAIApiKey,
  TutorHttpTransport? transport,
}) {
  final name = providerName?.trim().toLowerCase();
  if (name == null || name.isEmpty) return RefusingTutorProvider();
  if (name != 'openai') {
    throw FormatException('--provider must be openai.');
  }
  if (!generate) return RefusingTutorProvider();
  return OpenAITutorProvider(
    apiKey: requireOpenAIApiKey(openAIApiKey),
    transport: transport,
  );
}

class TutorHttpRequest {
  const TutorHttpRequest({
    required this.method,
    required this.uri,
    required this.headers,
    required this.body,
  });

  final String method;
  final Uri uri;
  final Map<String, String> headers;
  final Uint8List body;
}

class TutorHttpResponse {
  const TutorHttpResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
  });

  final int statusCode;
  final Map<String, String> headers;
  final String body;
}

abstract class TutorHttpTransport {
  Future<TutorHttpResponse> send(
    TutorHttpRequest request, {
    required Duration timeout,
  });
}

class IoTutorHttpTransport implements TutorHttpTransport {
  @override
  Future<TutorHttpResponse> send(
    TutorHttpRequest request, {
    required Duration timeout,
  }) async {
    final client = HttpClient();
    try {
      final httpRequest = await client
          .openUrl(request.method, request.uri)
          .timeout(timeout);
      httpRequest.followRedirects = false;
      request.headers.forEach(httpRequest.headers.set);
      httpRequest.add(request.body);
      final response = await httpRequest.close().timeout(timeout);
      final bytes = await response
          .fold<List<int>>(<int>[], (collected, chunk) {
            collected.addAll(chunk);
            return collected;
          })
          .timeout(timeout);
      final headers = <String, String>{};
      response.headers.forEach((name, values) {
        headers[name.toLowerCase()] = values.join(',');
      });
      return TutorHttpResponse(
        statusCode: response.statusCode,
        headers: headers,
        body: utf8.decode(bytes),
      );
    } finally {
      client.close(force: true);
    }
  }
}

class OpenAITutorException implements Exception {
  OpenAITutorException(
    this.message, {
    required this.transient,
    this.statusCode,
    this.requestId,
    this.refusal = false,
  });

  final String message;
  final bool transient;
  final int? statusCode;
  final String? requestId;
  final bool refusal;

  @override
  String toString() {
    final status = statusCode == null ? '' : 'HTTP $statusCode ';
    return 'OpenAI $status$message'.trim();
  }
}

class OpenAITutorProvider implements TutorGenerationProvider {
  OpenAITutorProvider({
    required String apiKey,
    TutorHttpTransport? transport,
    this.defaultModel = openAITutorDefaultModel,
    this.timeout = openAITutorRequestTimeout,
    Uri? endpoint,
  }) : apiKey = requireOpenAIApiKey(apiKey),
       transport = transport ?? IoTutorHttpTransport(),
       endpoint = endpoint ?? openAIResponsesEndpoint;

  final String apiKey;
  final TutorHttpTransport transport;
  final String defaultModel;
  final Duration timeout;
  final Uri endpoint;

  @override
  Future<TutorProviderResponse> generate(TutorGenerationRequest request) async {
    final requestedModel = _requestedModel(request.model);
    final payload = _requestBody(request, requestedModel);
    final httpRequest = TutorHttpRequest(
      method: 'POST',
      uri: endpoint,
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: Uint8List.fromList(utf8.encode(jsonEncode(payload))),
    );
    final TutorHttpResponse response;
    try {
      response = await transport.send(httpRequest, timeout: timeout);
    } on TimeoutException {
      throw OpenAITutorException('request timed out', transient: true);
    } on SocketException {
      throw OpenAITutorException('socket error', transient: true);
    }
    final requestId = _header(response.headers, 'x-request-id');
    if (response.statusCode != 200) {
      throw OpenAITutorException(
        _statusMessage(response.statusCode),
        transient: _isTransientStatus(response.statusCode),
        statusCode: response.statusCode,
        requestId: requestId,
      );
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw OpenAITutorException(
        'response was not JSON',
        transient: false,
        statusCode: response.statusCode,
        requestId: requestId,
      );
    }
    if (decoded is! Map) {
      throw OpenAITutorException(
        'response was not a JSON object',
        transient: false,
        requestId: requestId,
      );
    }
    final body = Map<String, Object?>.from(decoded);
    return _parseBody(
      body,
      requestedModel: requestedModel,
      requestId: requestId,
    );
  }

  String _requestedModel(String? model) {
    final trimmed = model?.trim();
    if (trimmed == null || trimmed.isEmpty) return defaultModel;
    return trimmed;
  }

  Map<String, Object?> _requestBody(
    TutorGenerationRequest request,
    String model,
  ) {
    final bytes = request.imageBytes;
    final mediaType = request.imageMediaType?.trim();
    final hasBytes = bytes != null;
    final hasType = mediaType != null && mediaType.isNotEmpty;
    if (hasBytes != hasType || (hasBytes && bytes.isEmpty)) {
      throw OpenAITutorException(
        'validated image bytes and media type are required together',
        transient: false,
      );
    }
    final content = <Map<String, Object?>>[
      {'type': 'input_text', 'text': request.prompt.user},
    ];
    if (hasBytes) {
      content.add({
        'type': 'input_image',
        'image_url': 'data:$mediaType;base64,${base64Encode(bytes)}',
        'detail': 'auto',
      });
    }
    return {
      'model': model,
      'store': false,
      'max_output_tokens': openAITutorMaxOutputTokens,
      'instructions': request.prompt.system,
      'input': [
        {'role': 'user', 'content': content},
      ],
      'text': {
        'format': {
          'type': 'json_schema',
          'name': openAITutorSchemaName,
          'strict': true,
          'schema': openAITutorJsonSchema(),
        },
      },
    };
  }

  TutorProviderResponse _parseBody(
    Map<String, Object?> body, {
    required String requestedModel,
    required String? requestId,
  }) {
    final responseId = _nonEmptyString(body['id']);
    final status = body['status']?.toString();
    if (body['error'] != null || status != 'completed') {
      throw OpenAITutorException(
        'response status ${status ?? 'missing'} was not completed',
        transient: false,
        requestId: requestId,
      );
    }
    final extracted = _extractOutput(body['output']);
    if (extracted.refusal) {
      throw OpenAITutorException(
        'model refused the generation',
        transient: false,
        requestId: requestId,
        refusal: true,
      );
    }
    final text = extracted.text;
    if (text == null || text.trim().isEmpty) {
      throw OpenAITutorException(
        'completed response had no output text',
        transient: false,
        requestId: requestId,
      );
    }
    final Object? structured;
    try {
      structured = jsonDecode(text);
    } on FormatException {
      throw TutorOutputParseException('structured output is not JSON');
    }
    if (structured is! Map) {
      throw TutorOutputParseException('structured output is not a JSON object');
    }
    final returnedModel = _nonEmptyString(body['model']);
    return TutorProviderResponse(
      modelId: returnedModel ?? requestedModel,
      structuredJson: Map<String, Object?>.from(structured),
      usage: _usage(body['usage']),
      requestId: requestId,
      responseId: responseId,
    );
  }

  _ExtractedOutput _extractOutput(Object? output) {
    if (output is! List) return const _ExtractedOutput();
    String? text;
    var refusal = false;
    for (final item in output) {
      if (item is! Map) continue;
      if (item['type']?.toString() != 'message') continue;
      final itemStatus = item['status']?.toString();
      if (itemStatus != null && itemStatus != 'completed') continue;
      final content = item['content'];
      if (content is! List) continue;
      for (final part in content) {
        if (part is! Map) continue;
        final type = part['type']?.toString();
        if (type == 'refusal') refusal = true;
        if (type == 'output_text' && part['text'] is String) {
          text = part['text'] as String;
        }
      }
    }
    return _ExtractedOutput(text: text, refusal: refusal);
  }

  TutorUsage _usage(Object? raw) {
    if (raw is! Map) return const TutorUsage();
    return TutorUsage(
      inputTokens: _token(raw['input_tokens']),
      outputTokens: _token(raw['output_tokens']),
    );
  }

  int? _token(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  String _statusMessage(int statusCode) {
    return switch (statusCode) {
      401 || 403 => 'authentication failed',
      400 || 404 || 422 => 'request rejected',
      429 => 'rate limited',
      500 || 502 || 503 || 504 => 'temporary server error',
      _ => 'request failed',
    };
  }

  bool _isTransientStatus(int statusCode) {
    return statusCode == 429 ||
        statusCode == 500 ||
        statusCode == 502 ||
        statusCode == 503 ||
        statusCode == 504;
  }

  String? _header(Map<String, String> headers, String name) {
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == name) return _nonEmptyString(entry.value);
    }
    return null;
  }

  String? _nonEmptyString(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class _ExtractedOutput {
  const _ExtractedOutput({this.text, this.refusal = false});

  final String? text;
  final bool refusal;
}
