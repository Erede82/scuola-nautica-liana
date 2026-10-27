import 'package:tutor_liana_generator/tutor_generator.dart';

TutorQuestion sampleQuestion({
  String id = '11111111-1111-4111-8111-111111111111',
  String licenseCategory = 'A12',
  int? lessonNumber = 4,
  String examTopicCode = 'SCAFO',
  String sourceTopicText = 'Lo scafo',
  String prompt = 'Domanda di prova',
  String optionA = 'Uno',
  String optionB = 'Due',
  String optionC = 'Tre',
  String correctOption = 'A',
  String? officialExplanation,
  String? imagePath,
}) {
  return TutorQuestion(
    id: id,
    licenseCategory: licenseCategory,
    lessonNumber: lessonNumber,
    examTopicCode: examTopicCode,
    sourceTopicText: sourceTopicText,
    prompt: prompt,
    optionA: optionA,
    optionB: optionB,
    optionC: optionC,
    correctOption: correctOption,
    officialExplanation: officialExplanation,
    imagePath: imagePath,
  );
}

TutorCatalogItem catalogItem(
  TutorQuestion question, {
  TutorExistingRow? existing,
  String? sourceHash,
}) {
  return TutorCatalogItem(
    question: question,
    sourceHash: sourceHash ?? tutorSourceHash(question),
    existing: existing,
  );
}

Map<String, Object?> validModelJson() {
  return {
    'explanation':
        'La risposta ufficiale è corretta perché descrive la regola della domanda. '
        'Il testo resta sulla regola e non cambia l opzione.',
    'simple_explanation': 'In breve, vale la risposta ufficiale indicata.',
    'memory_example': 'Pensala come una boa che resta al suo posto.',
    'needs_review': false,
    'review_reason': null,
  };
}

class ScriptedProvider implements TutorGenerationProvider {
  ScriptedProvider(
    this._responses, {
    List<Object?>? copyedits,
    this.usage = const TutorUsage(inputTokens: 10, outputTokens: 4),
    this.copyeditUsage = const TutorUsage(inputTokens: 3, outputTokens: 2),
    this.requestId,
    this.responseId,
    this.copyeditRequestId,
    this.copyeditResponseId,
  }) : _copyedits = copyedits ?? [];

  final List<Object?> _responses;
  final List<Object?> _copyedits;
  final TutorUsage usage;
  final TutorUsage copyeditUsage;
  final String? requestId;
  final String? responseId;
  final String? copyeditRequestId;
  final String? copyeditResponseId;
  int calls = 0;
  int copyeditCalls = 0;
  TutorGenerationRequest? lastRequest;
  TutorCopyeditRequest? lastCopyedit;

  @override
  Future<TutorProviderResponse> generate(TutorGenerationRequest request) async {
    calls += 1;
    lastRequest = request;
    if (_responses.isEmpty) {
      throw StateError('provider called with no scripted response');
    }
    final next = _responses.removeAt(0);
    if (next is Exception) throw next;
    if (next is Error) throw next;
    return TutorProviderResponse(
      modelId: 'test-model',
      structuredJson: next,
      usage: usage,
      requestId: requestId,
      responseId: responseId,
    );
  }

  @override
  Future<TutorProviderResponse> copyedit(TutorCopyeditRequest request) async {
    copyeditCalls += 1;
    lastCopyedit = request;
    if (_copyedits.isEmpty) {
      throw StateError('copyedit called with no scripted response');
    }
    final next = _copyedits.removeAt(0);
    if (next is Exception) throw next;
    if (next is Error) throw next;
    return TutorProviderResponse(
      modelId: 'test-model',
      structuredJson: next,
      usage: copyeditUsage,
      requestId: copyeditRequestId,
      responseId: copyeditResponseId,
    );
  }
}

class ThrowingStore implements TutorExplanationStore {
  @override
  Future<void> insert(TutorWritePayload payload) {
    throw StateError('unexpected insert');
  }

  @override
  Future<void> update({
    required TutorWritePayload payload,
    required String filter,
  }) {
    throw StateError('unexpected update');
  }
}

class FixedCatalog implements TutorCatalog {
  FixedCatalog(this.items);
  final List<TutorCatalogItem> items;
  int loads = 0;

  @override
  List<String> get missingSampleSlots => const [];

  @override
  Future<List<TutorCatalogItem>> load(TutorSelection selection) async {
    loads += 1;
    return items;
  }
}
