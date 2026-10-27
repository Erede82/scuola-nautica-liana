import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:tutor_liana_generator/tutor_generator.dart';

import 'support.dart';

void main() {
  const apiKey = 'test-openai-key';

  TutorGenerationRequest textRequest({String? model}) {
    final question = sampleQuestion();
    return TutorGenerationRequest(
      question: question,
      prompt: buildTutorPrompt(question, imageAttached: false),
      model: model,
    );
  }

  OpenAITutorProvider provider(_ScriptedTransport transport) {
    return OpenAITutorProvider(apiKey: apiKey, transport: transport);
  }

  test('a text request uses strict Responses output and no image', () async {
    final transport = _ScriptedTransport([(_) => _ok(validModelJson())]);
    final request = textRequest();
    await provider(transport).generate(request);
    final sent = transport.requests.single;
    expect(sent.method, 'POST');
    expect(sent.uri, openAIResponsesEndpoint);
    expect(sent.headers['Authorization'], 'Bearer $apiKey');
    final body = jsonDecode(utf8.decode(sent.body)) as Map<String, Object?>;
    expect(body['model'], openAITutorDefaultModel);
    expect(body['store'], isFalse);
    expect(openAITutorMaxOutputTokens, 1000);
    expect(body['max_output_tokens'], 1000);
    expect(body['reasoning'], {'effort': 'low'});
    expect(body.containsKey('tools'), isFalse);
    expect(body['instructions'], request.prompt.system);
    final format = (body['text'] as Map)['format'] as Map<String, Object?>;
    expect(format['type'], 'json_schema');
    expect(format['name'], openAITutorSchemaName);
    expect(format['strict'], isTrue);
    final schema = format['schema'] as Map<String, Object?>;
    expect(schema['additionalProperties'], isFalse);
    expect(schema['required'], [
      'explanation',
      'simple_explanation',
      'memory_example',
      'needs_review',
      'review_reason',
    ]);
    final content = ((body['input'] as List).single as Map)['content'] as List;
    expect(content, hasLength(1));
    expect(content.single['type'], 'input_text');
    expect(content.single['text'], request.prompt.user);
  });

  test('an image request sends the validated bytes as a data URL', () async {
    final png = Uint8List.fromList([
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
      0x01,
    ]);
    final transport = _ScriptedTransport([(_) => _ok(validModelJson())]);
    final question = sampleQuestion();
    await provider(transport).generate(
      TutorGenerationRequest(
        question: question,
        prompt: buildTutorPrompt(question, imageAttached: true),
        model: 'gpt-6.1-sol-custom',
        imageBytes: png,
        imageMediaType: 'image/png',
      ),
    );
    final body =
        jsonDecode(utf8.decode(transport.requests.single.body))
            as Map<String, Object?>;
    expect(body['model'], 'gpt-6.1-sol-custom');
    expect(body['reasoning'], {'effort': 'low'});
    expect(body['max_output_tokens'], 1000);
    final content = ((body['input'] as List).single as Map)['content'] as List;
    expect(content.first['type'], 'input_text');
    final image = content[1] as Map<String, Object?>;
    expect(image['type'], 'input_image');
    expect(image['detail'], 'auto');
    final url = image['image_url'] as String;
    expect(url.startsWith('data:image/png;base64,'), isTrue);
    expect(base64Decode(url.substring('data:image/png;base64,'.length)), png);
  });

  test(
    'a structured response returns parsed fields, usage, and model',
    () async {
      final transport = _ScriptedTransport([
        (_) => _ok(
          validModelJson(),
          model: 'gpt-6.1-sol-2026-09-29',
          usage: {'input_tokens': 12, 'output_tokens': 7},
          responseId: 'resp_123',
          requestId: 'req_123',
        ),
      ]);
      final response = await provider(transport).generate(textRequest());
      final parsed = parseTutorOutput(response.structuredJson);
      expect(parsed.needsReview, isFalse);
      expect(response.modelId, 'gpt-6.1-sol-2026-09-29');
      expect(response.usage.inputTokens, 12);
      expect(response.usage.outputTokens, 7);
      expect(response.requestId, 'req_123');
      expect(response.responseId, 'resp_123');
    },
  );

  test('a refusal is a controlled failure', () async {
    final transport = _ScriptedTransport([
      (_) => _response({
        'id': 'resp_ref',
        'status': 'completed',
        'model': openAITutorDefaultModel,
        'output': [
          {
            'type': 'message',
            'status': 'completed',
            'content': [
              {'type': 'refusal', 'refusal': 'cannot help'},
            ],
          },
        ],
      }),
    ]);
    await _expectOpenAI(provider(transport), (error) {
      expect(error.refusal, isTrue);
      expect(error.transient, isFalse);
      expect(error.toString(), isNot(contains(apiKey)));
    });
  });

  test('malformed structured text fails in the parser', () async {
    final transport = _ScriptedTransport([
      (_) => _response({
        'status': 'completed',
        'model': openAITutorDefaultModel,
        'output': [
          {
            'type': 'message',
            'status': 'completed',
            'content': [
              {'type': 'output_text', 'text': 'not-json'},
            ],
          },
        ],
      }),
    ]);
    expect(
      provider(transport).generate(textRequest()),
      throwsA(isA<TutorOutputParseException>()),
    );
  });

  test('an incomplete response is not accepted', () async {
    final transport = _ScriptedTransport([
      (_) => _response({
        'status': 'incomplete',
        'output': [
          {
            'type': 'message',
            'content': [
              {'type': 'output_text', 'text': jsonEncode(validModelJson())},
            ],
          },
        ],
      }),
    ]);
    await _expectOpenAI(provider(transport), (error) {
      expect(error.transient, isFalse);
      expect(error.refusal, isFalse);
    });
  });

  test(
    'HTTP 429 is transient and is not retried inside the provider',
    () async {
      final transport = _ScriptedTransport([
        (_) => TutorHttpResponse(
          statusCode: 429,
          headers: const {'x-request-id': 'req_429'},
          body: _utf8Stream('{"error":{"message":"rate"}}'),
        ),
      ]);
      await _expectOpenAI(provider(transport), (error) {
        expect(error.transient, isTrue);
        expect(isTransientProviderError(error), isTrue);
        expect(error.requestId, 'req_429');
        expect(error.toString(), isNot(contains(apiKey)));
      });
      expect(transport.requests, hasLength(1));
    },
  );

  test('HTTP 401 is not transient and does not leak the key', () async {
    final transport = _ScriptedTransport([
      (_) => TutorHttpResponse(
        statusCode: 401,
        headers: const {},
        body: _utf8Stream('{"error":{"message":"bad $apiKey"}}'),
      ),
    ]);
    await _expectOpenAI(provider(transport), (error) {
      expect(error.transient, isFalse);
      expect(isTransientProviderError(error), isFalse);
      expect(error.statusCode, 401);
      expect(error.toString(), isNot(contains(apiKey)));
      expect(error.message, 'authentication failed');
    });
    expect(transport.requests, hasLength(1));
  });

  test('a timeout is transient', () async {
    final transport = _ScriptedTransport([
      (_) => throw TimeoutException('deadline'),
    ]);
    await _expectOpenAI(provider(transport), (error) {
      expect(error.transient, isTrue);
      expect(isTransientProviderError(error), isTrue);
      expect(error.toString(), isNot(contains(apiKey)));
    });
  });

  test('missing usage stays null', () async {
    final transport = _ScriptedTransport([
      (_) => _response({
        'id': 'resp_no_usage',
        'status': 'completed',
        'output': [
          {
            'type': 'message',
            'status': 'completed',
            'content': [
              {'type': 'output_text', 'text': jsonEncode(validModelJson())},
            ],
          },
        ],
      }, requestId: 'req_no_usage'),
    ]);
    final response = await provider(transport).generate(textRequest());
    expect(response.usage.inputTokens, isNull);
    expect(response.usage.outputTokens, isNull);
    expect(response.modelId, openAITutorDefaultModel);
    expect(response.requestId, 'req_no_usage');
  });

  test('provider gates stay closed unless OpenAI is explicit', () {
    expect(buildTutorProvider(generate: false), isA<RefusingTutorProvider>());
    expect(buildTutorProvider(generate: true), isA<RefusingTutorProvider>());
    expect(
      buildTutorProvider(providerName: 'openai', generate: false),
      isA<RefusingTutorProvider>(),
    );
    expect(
      () => buildTutorProvider(
        providerName: 'openai',
        generate: true,
        openAIApiKey: ' ',
      ),
      throwsFormatException,
    );
    expect(
      buildTutorProvider(
        providerName: 'openai',
        generate: true,
        openAIApiKey: apiKey,
        transport: _ScriptedTransport([]),
      ),
      isA<OpenAITutorProvider>(),
    );
  });

  test('openai without generate makes no HTTP call', () async {
    final transport = _ScriptedTransport([
      (_) => throw StateError('must not be called'),
    ]);
    final summary =
        await TutorPipeline(
          catalog: FixedCatalog([catalogItem(sampleQuestion())]),
          store: ThrowingStore(),
          provider: OpenAITutorProvider(apiKey: apiKey, transport: transport),
          images: UnavailableImageSource(),
        ).run(
          const TutorRunRequest(
            selection: TutorSelection(limit: 1),
            generate: false,
            write: false,
            regenerate: false,
            forceApproved: false,
          ),
        );
    expect(transport.requests, isEmpty);
    expect(summary.providerCalls, 0);
    expect(summary.dbWrites, 0);
  });

  test(
    'a fake OpenAI generation does not write and reports usage gaps',
    () async {
      final transport = _ScriptedTransport([
        (_) => _response({
          'id': 'resp_gap',
          'status': 'completed',
          'model': openAITutorDefaultModel,
          'output': [
            {
              'type': 'message',
              'status': 'completed',
              'content': [
                {'type': 'output_text', 'text': jsonEncode(validModelJson())},
              ],
            },
          ],
        }, requestId: 'req_gap'),
      ]);
      final store = MemoryTutorStore();
      final summary =
          await TutorPipeline(
            catalog: FixedCatalog([catalogItem(sampleQuestion())]),
            store: store,
            provider: OpenAITutorProvider(apiKey: apiKey, transport: transport),
            images: UnavailableImageSource(),
          ).run(
            const TutorRunRequest(
              selection: TutorSelection(limit: 1),
              generate: true,
              write: false,
              regenerate: false,
              forceApproved: false,
            ),
          );
      expect(transport.requests, hasLength(1));
      expect(summary.dbWrites, 0);
      expect(store.inserts, isEmpty);
      expect(summary.inputTokens, isNull);
      expect(summary.inputTokensComplete, isFalse);
      expect(summary.outputTokensComplete, isFalse);
      expect(summary.items.single.providerRequestId, 'req_gap');
      expect(summary.items.single.providerResponseId, 'resp_gap');
    },
  );

  test('a refusal does not persist a Tutor row', () async {
    final transport = _ScriptedTransport([
      (_) => _response({
        'status': 'completed',
        'output': [
          {
            'type': 'message',
            'status': 'completed',
            'content': [
              {'type': 'refusal', 'refusal': 'no'},
            ],
          },
        ],
      }),
    ]);
    final store = MemoryTutorStore();
    final summary =
        await TutorPipeline(
          catalog: FixedCatalog([catalogItem(sampleQuestion())]),
          store: store,
          provider: OpenAITutorProvider(apiKey: apiKey, transport: transport),
          images: UnavailableImageSource(),
        ).run(
          const TutorRunRequest(
            selection: TutorSelection(limit: 1),
            generate: true,
            write: true,
            regenerate: false,
            forceApproved: false,
          ),
        );
    expect(summary.dbWrites, 0);
    expect(store.inserts, isEmpty);
    expect(summary.items.single.rejections, contains('provider_refusal'));
  });

  test('malformed OpenAI output does not persist a Tutor row', () async {
    final transport = _ScriptedTransport([
      (_) => _response({
        'status': 'completed',
        'output': [
          {
            'type': 'message',
            'status': 'completed',
            'content': [
              {'type': 'output_text', 'text': '{"explanation":1}'},
            ],
          },
        ],
      }),
    ]);
    final store = MemoryTutorStore();
    final summary =
        await TutorPipeline(
          catalog: FixedCatalog([catalogItem(sampleQuestion())]),
          store: store,
          provider: OpenAITutorProvider(apiKey: apiKey, transport: transport),
          images: UnavailableImageSource(),
        ).run(
          const TutorRunRequest(
            selection: TutorSelection(limit: 1),
            generate: true,
            write: true,
            regenerate: false,
            forceApproved: false,
          ),
        );
    expect(summary.dbWrites, 0);
    expect(store.inserts, isEmpty);
    expect(summary.items.single.rejections, contains('malformed_output'));
  });

  test('a normal response below the body cap still parses', () async {
    final encoded = utf8.encode(
      jsonEncode({
        'id': 'resp_small',
        'status': 'completed',
        'model': openAITutorDefaultModel,
        'output': [
          {
            'type': 'message',
            'status': 'completed',
            'content': [
              {'type': 'output_text', 'text': jsonEncode(validModelJson())},
            ],
          },
        ],
      }),
    );
    final transport = _ScriptedTransport([
      (_) => TutorHttpResponse(
        statusCode: 200,
        headers: const {'x-request-id': 'req_small'},
        body: Stream.value(encoded),
      ),
    ]);
    final response = await OpenAITutorProvider(
      apiKey: apiKey,
      transport: transport,
      maxResponseBytes: encoded.length + 1,
    ).generate(textRequest());
    expect(parseTutorOutput(response.structuredJson).needsReview, isFalse);
    expect(response.requestId, 'req_small');
  });

  test('a body of exactly the configured cap is accepted', () async {
    final payload = _completedPayload(validModelJson());
    final encoded = utf8.encode(jsonEncode(payload));
    final transport = _ScriptedTransport([
      (_) => TutorHttpResponse(
        statusCode: 200,
        headers: const {},
        body: Stream.value(encoded),
      ),
    ]);
    final response = await OpenAITutorProvider(
      apiKey: apiKey,
      transport: transport,
      maxResponseBytes: encoded.length,
    ).generate(textRequest());
    expect(response.responseId, 'resp_cap');
    expect(transport.requests, hasLength(1));
  });

  test('one byte over the cap is rejected once and is not retried', () async {
    final payload = _completedPayload(validModelJson());
    final encoded = utf8.encode(jsonEncode(payload));
    final transport = _ScriptedTransport([
      (_) => TutorHttpResponse(
        statusCode: 200,
        headers: const {},
        body: Stream.fromIterable([
          encoded.sublist(0, encoded.length - 1),
          encoded.sublist(encoded.length - 1),
        ]),
      ),
    ]);
    final store = MemoryTutorStore();
    final tutor = OpenAITutorProvider(
      apiKey: apiKey,
      transport: transport,
      maxResponseBytes: encoded.length - 1,
    );
    await _expectOpenAI(tutor, (error) {
      expect(error.message, 'response_body_too_large');
      expect(error.transient, isFalse);
      expect(isTransientProviderError(error), isFalse);
      expect(error.toString(), isNot(contains(apiKey)));
      expect(error.toString().length, lessThan(80));
    });
    expect(transport.requests, hasLength(1));
    final pipelineTransport = _ScriptedTransport([
      (_) => TutorHttpResponse(
        statusCode: 200,
        headers: const {},
        body: Stream.value(encoded),
      ),
    ]);
    final summary =
        await TutorPipeline(
          catalog: FixedCatalog([catalogItem(sampleQuestion())]),
          store: store,
          provider: OpenAITutorProvider(
            apiKey: apiKey,
            transport: pipelineTransport,
            maxResponseBytes: encoded.length - 1,
          ),
          images: UnavailableImageSource(),
        ).run(
          const TutorRunRequest(
            selection: TutorSelection(limit: 1),
            generate: true,
            write: true,
            regenerate: false,
            forceApproved: false,
          ),
        );
    expect(pipelineTransport.requests, hasLength(1));
    expect(summary.dbWrites, 0);
    expect(store.inserts, isEmpty);
    expect(summary.items.single.rejections, contains('provider_error'));
  });

  test(
    'the production cap keeps an exact body and rejects one extra byte',
    () async {
      expect(openAITutorMaxResponseBytes, 1048576);
      final atCap = Uint8List(openAITutorMaxResponseBytes);
      final kept = await readBoundedBody(
        Stream.value(atCap),
        maxBytes: openAITutorMaxResponseBytes,
      );
      expect(kept.length, openAITutorMaxResponseBytes);

      Object? failure;
      try {
        await readBoundedBody(
          Stream.fromIterable([
            atCap,
            Uint8List.fromList([1]),
          ]),
          maxBytes: openAITutorMaxResponseBytes,
        );
      } on OpenAITutorException catch (error) {
        failure = error;
      }
      expect(failure, isA<OpenAITutorException>());
      final error = failure as OpenAITutorException;
      expect(error.message, 'response_body_too_large');
      expect(error.transient, isFalse);
      expect(isTransientProviderError(error), isFalse);
      expect(error.toString(), isNot(contains('Authorization')));
    },
  );

  test('an oversized malformed body fails at the size guard', () async {
    final junk = Uint8List.fromList(List<int>.filled(40, 0x78));
    Object? failure;
    try {
      await readBoundedBody(
        Stream.fromIterable([junk.sublist(0, 20), junk.sublist(20)]),
        maxBytes: 39,
      );
    } on OpenAITutorException catch (error) {
      failure = error;
    }
    final error = failure as OpenAITutorException;
    expect(error.message, 'response_body_too_large');
    expect(error.toString(), isNot(contains('xxx')));
    expect(isTransientProviderError(error), isFalse);
  });

  test('copyedit is a text-only request on the configured model', () async {
    const explanation = 'Esprime quindi il rapporto, misuratain miglia marine.';
    const simple = 'In breve, vale la risposta ufficiale indicata.';
    const memory = 'Pensala come una boa che resta al suo posto.';
    final transport = _ScriptedTransport([
      (_) => _ok({
        'explanation': explanation,
        'simple_explanation': simple,
        'memory_example': memory,
        'changed': false,
        'review_reason': null,
      }),
    ]);
    await provider(transport).copyedit(
      const TutorCopyeditRequest(
        explanation: explanation,
        simpleExplanation: simple,
        memoryExample: memory,
        model: null,
      ),
    );
    final body =
        jsonDecode(utf8.decode(transport.requests.single.body))
            as Map<String, Object?>;
    final encoded = jsonEncode(body);
    expect(body['model'], openAITutorDefaultModel);
    expect(body['store'], isFalse);
    expect(body['max_output_tokens'], openAITutorMaxOutputTokens);
    expect(body['reasoning'], {'effort': openAITutorReasoningEffort});
    expect(body['instructions'], tutorCopyeditSystemPrompt);
    expect(body.containsKey('tools'), isFalse);
    final format = (body['text'] as Map)['format'] as Map<String, Object?>;
    expect(format['name'], tutorCopyeditSchemaName);
    expect(format['strict'], isTrue);
    expect(format['schema'], tutorCopyeditJsonSchema());
    final content = ((body['input'] as List).single as Map)['content'] as List;
    expect(content, hasLength(1));
    expect(content.single['type'], 'input_text');
    expect(content.single, isNot(contains('input_image')));
    expect(
      content.single['text'],
      tutorCopyeditUserText(
        explanation: explanation,
        simpleExplanation: simple,
        memoryExample: memory,
      ),
    );
    expect(encoded, isNot(contains('input_image')));
    expect(encoded, isNot(contains('Domanda di prova')));
    expect(encoded, isNot(contains(apiKey)));
    expect(encoded, isNot(contains('OPENAI_API_KEY')));
    expect(
      transport.requests.single.headers['Authorization'],
      'Bearer $apiKey',
    );
  });
}

TutorHttpResponse _ok(
  Map<String, Object?> structured, {
  String model = openAITutorDefaultModel,
  Map<String, Object?>? usage,
  String responseId = 'resp_ok',
  String requestId = 'req_ok',
}) {
  return _response({
    'id': responseId,
    'model': model,
    'status': 'completed',
    'usage': ?usage,
    'output': [
      {
        'type': 'message',
        'status': 'completed',
        'content': [
          {'type': 'output_text', 'text': jsonEncode(structured)},
        ],
      },
    ],
  }, requestId: requestId);
}

TutorHttpResponse _response(Map<String, Object?> body, {String? requestId}) {
  return TutorHttpResponse(
    statusCode: 200,
    headers: {'x-request-id': ?requestId},
    body: _utf8Stream(jsonEncode(body)),
  );
}

Stream<List<int>> _utf8Stream(String text) {
  return Stream<List<int>>.value(utf8.encode(text));
}

Map<String, Object?> _completedPayload(Map<String, Object?> structured) {
  return {
    'id': 'resp_cap',
    'status': 'completed',
    'model': openAITutorDefaultModel,
    'output': [
      {
        'type': 'message',
        'status': 'completed',
        'content': [
          {'type': 'output_text', 'text': jsonEncode(structured)},
        ],
      },
    ],
  };
}

Future<void> _expectOpenAI(
  OpenAITutorProvider provider,
  void Function(OpenAITutorException error) check,
) async {
  try {
    await provider.generate(
      TutorGenerationRequest(
        question: sampleQuestion(),
        prompt: buildTutorPrompt(sampleQuestion(), imageAttached: false),
        model: null,
      ),
    );
    fail('expected OpenAITutorException');
  } on OpenAITutorException catch (error) {
    check(error);
  }
}

class _ScriptedTransport implements TutorHttpTransport {
  _ScriptedTransport(this._handlers);

  final List<Object Function(TutorHttpRequest request)> _handlers;
  final List<TutorHttpRequest> requests = [];

  @override
  Future<TutorHttpResponse> send(
    TutorHttpRequest request, {
    required Duration timeout,
  }) async {
    requests.add(request);
    if (_handlers.isEmpty) {
      throw StateError('unexpected OpenAI HTTP call');
    }
    final result = _handlers.removeAt(0)(request);
    if (result is Exception) throw result;
    return result as TutorHttpResponse;
  }
}
