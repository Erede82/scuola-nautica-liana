import 'package:test/test.dart';
import 'package:tutor_liana_generator/tutor_generator.dart';

void main() {
  TutorQualityReport check(Map<String, Object?> json, {String correct = 'A'}) {
    return validateTutorOutput(parseTutorOutput(json), correctOption: correct);
  }

  Map<String, Object?> base({
    String explanation =
        'La risposta ufficiale descrive la regola in modo diretto. Resta valida per ogni studente.',
    String simple = 'In breve, conta la risposta ufficiale.',
    String memory = 'Ricordala come una boa ferma.',
    bool needsReview = false,
    Object? reviewReason,
  }) {
    return {
      'explanation': explanation,
      'simple_explanation': simple,
      'memory_example': memory,
      'needs_review': needsReview,
      'review_reason': reviewReason,
    };
  }

  test('a complete three-text response is accepted for review', () {
    final report = check(base());
    expect(report.acceptForReview, isTrue);
    expect(report.rejections, isEmpty);
  });

  test('empty fields are rejected', () {
    expect(
      check(base(explanation: '   ')).rejections,
      contains('empty_explanation'),
    );
    expect(
      check(base(simple: '')).rejections,
      contains('empty_simple_explanation'),
    );
    expect(
      check(base(memory: ' ')).rejections,
      contains('empty_memory_example'),
    );
  });

  test('malformed structured output is rejected', () {
    expect(
      () => parseTutorOutput({'explanation': 'solo questo'}),
      throwsA(isA<TutorOutputParseException>()),
    );
    expect(
      () => parseTutorOutput('testo libero'),
      throwsA(isA<TutorOutputParseException>()),
    );
    expect(
      () => parseTutorOutput({...base(), 'extra': true}),
      throwsA(isA<TutorOutputParseException>()),
    );
  });

  test('a contradictory answer and an invented citation are rejected', () {
    expect(
      check(
        base(explanation: 'La risposta corretta è B, non quella indicata.'),
      ).rejections,
      contains('contradicts_official_answer'),
    );
    expect(
      check(
        base(explanation: 'Lo dice l articolo 42 del codice della nautica.'),
      ).rejections,
      contains('invented_citation'),
    );
  });

  test('excessive output is rejected and needs_review is flagged', () {
    expect(
      check(base(explanation: 'a' * (explanationHardMax + 1))).rejections,
      contains('excessive_explanation'),
    );
    final flagged = check(
      base(needsReview: true, reviewReason: 'Manca il contesto visivo.'),
    );
    expect(flagged.acceptForReview, isTrue);
    expect(flagged.flags, contains('needs_review'));
  });

  test('write payload cannot be approved', () {
    final payload = TutorWritePayload(
      questionId: '11111111-1111-4111-8111-111111111111',
      sourceHash: 'ab' * 32,
      explanation: 'Uno.',
      simpleExplanation: 'Due.',
      memoryExample: 'Tre.',
      model: 'test-model',
      generatedAt: DateTime.utc(2026, 10, 24),
      output: const TutorParsedOutput(
        explanation: 'Uno.',
        simpleExplanation: 'Due.',
        memoryExample: 'Tre.',
        needsReview: false,
        reviewReason: 'unnecessary',
      ),
    );
    expect(payload.status, 'review_required');
    expect(payload.approvedAt, isNull);
    expect(payload.reviewedAt, isNull);
    expect(payload.generationReviewReason, isNull);
    expect(payload.promptVersion, tutorLianaPromptVersion);
    expect(payload.toJson()['approved_at'], isNull);
    expect(payload.toJson()['reviewed_at'], isNull);
    expect(payload.toJson().containsKey('generation_review_reason'), isTrue);
    expect(payload.toJson()['generation_review_reason'], isNull);
    expect(
      protectedUpdateFilter(
        questionId: payload.questionId,
        currentHash: payload.sourceHash,
      ),
      contains('status.neq.approved'),
    );
  });

  test('publishable keys are refused', () {
    expect(
      () => assertServiceRoleKey('sb_publishable_example'),
      throwsArgumentError,
    );
  });
}
