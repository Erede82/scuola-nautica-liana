import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tutor_liana_generator/tutor_generator.dart';

import 'support.dart';

const _badSpace =
    'Esprime quindi il rapporto tra una distanza, misuratain miglia marine, '
    'e il tempo impiegato a percorrerla.';
const _fixedSpace =
    'Esprime quindi il rapporto tra una distanza, misurata in miglia marine, '
    'e il tempo impiegato a percorrerla.';
const _clean =
    'Navigare a un nodo significa percorrere un miglio marino in un’ora.';
const _fiveKnots =
    'Se mantieni una velocità di 5 nodi per un’ora, resta il ritmo.';
const _simple = 'In breve, vale la risposta ufficiale indicata.';
const _memory = 'Pensala come una boa che resta al suo posto.';

void main() {
  final fixedNow = DateTime.utc(2026, 10, 27, 8);

  test('spacing a glued word keeps the meaning inside the allowance', () {
    final check = verifyTutorCopyedit(
      beforeExplanation: _badSpace,
      beforeSimple: _simple,
      beforeMemory: _memory,
      afterExplanation: _fixedSpace,
      afterSimple: _simple,
      afterMemory: _memory,
    );
    expect(check.accepted, isTrue);
    expect(
      (_fixedSpace.length - _badSpace.length).abs(),
      lessThanOrEqualTo(tutorCopyeditLengthAllowance(_badSpace.length)),
    );
  });

  test('a clean sentence is accepted unchanged', () {
    final check = verifyTutorCopyedit(
      beforeExplanation: _clean,
      beforeSimple: _simple,
      beforeMemory: _memory,
      afterExplanation: _clean,
      afterSimple: _simple,
      afterMemory: _memory,
    );
    expect(check.accepted, isTrue);
  });

  test('5 nodi stays 5 nodi and 6 nodi is rejected', () {
    expect(
      verifyTutorCopyedit(
        beforeExplanation: _fiveKnots,
        beforeSimple: _simple,
        beforeMemory: _memory,
        afterExplanation: _fiveKnots,
        afterSimple: _simple,
        afterMemory: _memory,
      ).accepted,
      isTrue,
    );
    final changed = verifyTutorCopyedit(
      beforeExplanation: _fiveKnots,
      beforeSimple: _simple,
      beforeMemory: _memory,
      afterExplanation: _fiveKnots.replaceFirst('5 nodi', '6 nodi'),
      afterSimple: _simple,
      afterMemory: _memory,
    );
    expect(changed.accepted, isFalse);
    expect(changed.rejections, contains('copyedit_number_changed'));
  });

  test('changing un miglio into due miglia is rejected', () {
    final check = verifyTutorCopyedit(
      beforeExplanation: _clean,
      beforeSimple: _simple,
      beforeMemory: _memory,
      afterExplanation: _clean.replaceFirst('un miglio', 'due miglia'),
      afterSimple: _simple,
      afterMemory: _memory,
    );
    expect(check.accepted, isFalse);
    expect(check.rejections, contains('copyedit_guarded_token_changed'));
  });

  test('a decimal comma and a decimal dot are the same number', () {
    const before = 'La scala indica 1,5 miglia marine.';
    const after = 'La scala indica 1.5 miglia marine.';
    final check = verifyTutorCopyedit(
      beforeExplanation: before,
      beforeSimple: _simple,
      beforeMemory: _memory,
      afterExplanation: after,
      afterSimple: _simple,
      afterMemory: _memory,
    );
    expect(check.accepted, isTrue);
  });

  test('a changed URL or option label is rejected', () {
    final url = verifyTutorCopyedit(
      beforeExplanation: 'Vedi https://example.com/a per il testo.',
      beforeSimple: _simple,
      beforeMemory: _memory,
      afterExplanation: 'Vedi https://example.com/b per il testo.',
      afterSimple: _simple,
      afterMemory: _memory,
    );
    expect(url.rejections, contains('copyedit_url_changed'));
    final option = verifyTutorCopyedit(
      beforeExplanation: 'La nota cita opzione A nel registro.',
      beforeSimple: _simple,
      beforeMemory: _memory,
      afterExplanation: 'La nota cita opzione B nel registro.',
      afterSimple: _simple,
      afterMemory: _memory,
    );
    expect(option.rejections, contains('copyedit_option_label_changed'));
  });

  test('a major expansion is rejected', () {
    const extra =
        ' Aggiunge considerazione extra sul percorso didattico che non '
        'appartiene al testo di partenza e allunga troppo il paragrafo.';
    final check = verifyTutorCopyedit(
      beforeExplanation: _clean,
      beforeSimple: _simple,
      beforeMemory: _memory,
      afterExplanation: '$_clean$extra',
      afterSimple: _simple,
      afterMemory: _memory,
    );
    expect(check.accepted, isFalse);
    expect(check.rejections, contains('copyedit_length_changed'));
    expect(check.rejections, contains('copyedit_rewrite'));
  });

  test('short semantic swaps are rejected even inside a long paragraph', () {
    expect(
      _check(
        'La prua della barca resta visibile.',
        'La poppa della barca resta visibile.',
      ).rejections,
      contains('copyedit_rewrite'),
    );
    expect(
      _check(
        'Il vento arriva da nord e resta stabile.',
        'Il vento arriva da sud e resta stabile.',
      ).rejections,
      contains('copyedit_rewrite'),
    );
    expect(
      _check(
        'Il fanale di destra resta acceso.',
        'Il fanale di sinistra resta acceso.',
      ).rejections,
      contains('copyedit_rewrite'),
    );
    const pad = 'La regola resta quella indicata nel testo. ';
    final long = _check(
      '${pad * 8}La prua resta visibile.',
      '${pad * 8}La poppa resta visibile.',
    );
    expect(long.rejections, contains('copyedit_rewrite'));
    expect(
      tutorCopyeditEditAllowance(('${pad * 8}La prua resta visibile.').length),
      greaterThan(tutorCopyeditSubstitutionFloor),
    );
  });

  test('a two-character typo stays inside the substitution floor', () {
    final check = _check(
      'Il colore giallo resta visibile.',
      'Il colore gxaxlo resta visibile.',
    );
    expect(check.accepted, isTrue);
    expect(tutorCopyeditSubstitutionFloor, 2);
  });

  test('signed numbers stay signed and a range hyphen is not a sign', () {
    expect(
      _check(
        'La correzione è -5 gradi sul valore.',
        'La correzione è 5 gradi sul valore.',
      ).rejections,
      contains('copyedit_number_changed'),
    );
    expect(
      _check(
        'La correzione è 5 gradi sul valore.',
        'La correzione è -5 gradi sul valore.',
      ).rejections,
      contains('copyedit_number_changed'),
    );
    expect(
      _check(
        'Il valore segnato è +5 gradi.',
        'Il valore segnato è 5 gradi.',
      ).rejections,
      contains('copyedit_number_changed'),
    );
    expect(
      _check(
        'La correzione è \u22125 gradi sul valore.',
        'La correzione è -5 gradi sul valore.',
      ).accepted,
      isTrue,
    );
    expect(
      _check('La catena è di 4-6 metri.', 'La catena è di 4-6 metri.').accepted,
      isTrue,
    );
    expect(
      _check(
        'La catena è di 4-6 metri.',
        'La catena è di 4-7 metri.',
      ).rejections,
      contains('copyedit_number_changed'),
    );
  });

  test('compact technical tokens reject a unit change and keep spacing', () {
    expect(
      _check(
        'Il limite è 6 NM in quella zona.',
        'Il limite è 6 M in quella zona.',
      ).rejections,
      contains('copyedit_technical_token_changed'),
    );
    expect(
      _check(
        'La batteria è da 12 V nominali.',
        'La batteria è da 12 A nominali.',
      ).rejections,
      contains('copyedit_technical_token_changed'),
    );
    expect(
      _check(
        "L angolo è 30° sul rilevamento.",
        "L angolo è 30' sul rilevamento.",
      ).rejections,
      contains('copyedit_technical_token_changed'),
    );
    expect(
      _check(
        'Il canale VHF resta quello indicato.',
        'Il canale MF/HF resta quello indicato.',
      ).rejections,
      contains('copyedit_technical_token_changed'),
    );
    expect(
      _check(
        'Il limite è 6 NM in quella zona.',
        'Il limite è 6NM in quella zona.',
      ).accepted,
      isTrue,
    );
    expect(
      _check(
        'La batteria è da 12V nominali.',
        'La batteria è da 12 V nominali.',
      ).accepted,
      isTrue,
    );
    const compact =
        'Restano validi 12V, 24V, 5A, 10kW, 6NM, 5s, 26m, 11M, 13B e il 50esimo.';
    expect(_check(compact, compact).accepted, isTrue);
  });

  test(
    'uppercase compass letters are technical tokens and compounds stay whole',
    () {
      expect(
        _check('Rotta N.', 'Rotta S.').rejections,
        contains('copyedit_technical_token_changed'),
      );
      expect(
        _check('Rotta E.', 'Rotta W.').rejections,
        contains('copyedit_technical_token_changed'),
      );
      expect(
        _check('Rotta NE.', 'Rotta SE.').rejections,
        contains('copyedit_technical_token_changed'),
      );
      expect(
        _check('Rotta NE.', 'Rotta N E.').rejections,
        contains('copyedit_technical_token_changed'),
      );
      expect(_check('Rotta N.', 'Rotta N.').accepted, isTrue);
      expect(_check('Rotta E.', 'Rotta E.').accepted, isTrue);
      expect(_check('Rotta NE.', 'Rotta NE.').accepted, isTrue);
      expect(
        _check(
          'La barca e la boa restano vicine.',
          'La barca e la boa restano vicine.',
        ).accepted,
        isTrue,
      );
      expect(
        _check('Rotta n.', 'Rotta s.').rejections,
        isNot(contains('copyedit_technical_token_changed')),
      );
    },
  );

  test('copyedit user text contains only the three fields', () {
    final text = tutorCopyeditUserText(
      explanation: _badSpace,
      simpleExplanation: _simple,
      memoryExample: _memory,
    );
    expect(text, contains(_badSpace));
    expect(text, isNot(contains('Domanda di prova')));
    expect(text, isNot(contains('option_a')));
    expect(tutorCopyeditVersion, 'tutor_copyedit_v1');
    expect(tutorLianaPromptVersion, 'tutor_liana_v2');
  });

  test('unchanged copyedit keeps the clean wording', () async {
    final provider = ScriptedProvider(
      [_generated(explanation: _clean)],
      copyedits: [_edited(explanation: _clean)],
      requestId: 'gen-req',
      responseId: 'gen-resp',
      copyeditRequestId: 'copy-req',
      copyeditResponseId: 'copy-resp',
    );
    final summary = await _run(provider, showOutput: true, clock: fixedNow);
    final item = summary.items.single;
    expect(provider.calls, 1);
    expect(provider.copyeditCalls, 1);
    expect(item.outcome, 'review_required');
    expect(item.explanation, _clean);
    expect(item.copyeditChanged, isFalse);
    expect(item.copyeditVersion, tutorCopyeditVersion);
    expect(summary.dbWrites, 0);
  });

  test('misuratain is corrected and only the final text is shown', () async {
    const leakedReason = 'fixed misuratain glued word';
    final provider = ScriptedProvider(
      [_generated(explanation: _badSpace)],
      copyedits: [
        _edited(
          explanation: _fixedSpace,
          changed: true,
          reviewReason: leakedReason,
        ),
      ],
    );
    final events = <Map<String, Object?>>[];
    final summary = await _run(
      provider,
      showOutput: true,
      write: false,
      clock: fixedNow,
      store: ThrowingStore(),
      log: events.add,
    );
    final item = summary.items.single;
    expect(item.outcome, 'review_required');
    expect(item.explanation, _fixedSpace);
    expect(item.copyeditChanged, isTrue);
    expect(summary.dbWrites, 0);
    expect(provider.lastCopyedit?.explanation, _badSpace);
    expect(provider.lastCopyedit?.simpleExplanation, _simple);
    final encoded = jsonEncode(events.single);
    expect(encoded, contains('misurata in'));
    expect(encoded, isNot(contains('misuratain')));
    expect(encoded, isNot(contains(leakedReason)));
    expect(encoded, isNot(contains('OPENAI_API_KEY')));
  });

  test('copyedit that keeps 5 nodi is accepted', () async {
    final provider = ScriptedProvider(
      [_generated(explanation: _fiveKnots)],
      copyedits: [_edited(explanation: _fiveKnots)],
    );
    final summary = await _run(provider, showOutput: true, clock: fixedNow);
    expect(summary.items.single.explanation, _fiveKnots);
    expect(summary.items.single.copyeditChanged, isFalse);
    expect(summary.dbWrites, 0);
  });

  test('a numeric alteration is rejected and hidden', () async {
    final provider = ScriptedProvider(
      [_generated(explanation: _fiveKnots)],
      copyedits: [
        _edited(explanation: _fiveKnots.replaceFirst('5 nodi', '6 nodi')),
      ],
    );
    final events = <Map<String, Object?>>[];
    final summary = await _run(
      provider,
      showOutput: true,
      write: true,
      clock: fixedNow,
      store: ThrowingStore(),
      log: events.add,
    );
    expect(summary.dbWrites, 0);
    expect(summary.items.single.outcome, 'failed');
    expect(summary.items.single.explanation, isNull);
    expect(
      summary.items.single.rejections,
      contains('copyedit_number_changed'),
    );
    final encoded = jsonEncode(events.single);
    expect(encoded, isNot(contains('6 nodi')));
    expect(encoded, isNot(contains(_fiveKnots)));
  });

  test('changing un miglio into due miglia fails the item', () async {
    final provider = ScriptedProvider(
      [_generated(explanation: _clean)],
      copyedits: [
        _edited(explanation: _clean.replaceFirst('un miglio', 'due miglia')),
      ],
    );
    final summary = await _run(
      provider,
      showOutput: true,
      write: true,
      clock: fixedNow,
      store: MemoryTutorStore(),
    );
    expect(summary.dbWrites, 0);
    expect(summary.items.single.outcome, 'failed');
    expect(summary.items.single.explanation, isNull);
    expect(
      summary.items.single.rejections,
      contains('copyedit_guarded_token_changed'),
    );
  });

  test('a major expansion is not accepted as show-output', () async {
    const extra =
        ' Aggiunge considerazione extra sul percorso didattico che non '
        'appartiene al testo di partenza e allunga troppo il paragrafo.';
    final provider = ScriptedProvider(
      [_generated(explanation: _clean)],
      copyedits: [_edited(explanation: '$_clean$extra')],
    );
    final events = <Map<String, Object?>>[];
    final summary = await _run(
      provider,
      showOutput: true,
      write: true,
      clock: fixedNow,
      store: MemoryTutorStore(),
      log: events.add,
    );
    expect(summary.dbWrites, 0);
    expect(summary.items.single.explanation, isNull);
    expect(
      summary.items.single.rejections,
      contains('copyedit_length_changed'),
    );
    expect(jsonEncode(events.single), isNot(contains(extra.trim())));
  });

  test('malformed copyedit fails without a fallback write', () async {
    final provider = ScriptedProvider(
      [_generated(explanation: _clean)],
      copyedits: [
        {'explanation': _clean},
      ],
    );
    final summary = await _run(
      provider,
      write: true,
      showOutput: true,
      clock: fixedNow,
      store: MemoryTutorStore(),
    );
    expect(provider.copyeditCalls, 1);
    expect(summary.dbWrites, 0);
    expect(summary.items.single.outcome, 'failed');
    expect(summary.items.single.rejections, contains('copyedit_malformed'));
    expect(summary.items.single.explanation, isNull);
  });

  test('a copyedit refusal fails the item', () async {
    final provider = ScriptedProvider(
      [_generated(explanation: _clean)],
      copyedits: [
        OpenAITutorException(
          'model refused the copyedit',
          transient: false,
          refusal: true,
          requestId: 'copy-refused',
        ),
      ],
    );
    final summary = await _run(
      provider,
      write: true,
      showOutput: true,
      clock: fixedNow,
      store: MemoryTutorStore(),
    );
    expect(summary.dbWrites, 0);
    expect(summary.items.single.outcome, 'failed');
    expect(summary.items.single.rejections, contains('copyedit_refusal'));
    expect(summary.items.single.explanation, isNull);
    expect(summary.items.single.copyeditRequestId, 'copy-refused');
  });

  test('a copyedit provider failure does not store the first pass', () async {
    final store = MemoryTutorStore();
    final provider = ScriptedProvider(
      [_generated(explanation: _badSpace)],
      copyedits: [OpenAITutorException('copyedit down', transient: false)],
    );
    final summary = await _run(
      provider,
      write: true,
      showOutput: true,
      clock: fixedNow,
      store: store,
    );
    expect(summary.dbWrites, 0);
    expect(store.inserts, isEmpty);
    expect(summary.items.single.outcome, 'failed');
    expect(
      summary.items.single.rejections,
      contains('copyedit_provider_error'),
    );
    expect(summary.items.single.explanation, isNull);
    expect(
      jsonEncode(summary.items.single.toJson()),
      isNot(contains('misuratain')),
    );
  });

  test('semantic, sign, and unit swaps are hidden and not written', () async {
    final cases = [
      (
        'La prua della barca resta visibile.',
        'La poppa della barca resta visibile.',
        'copyedit_rewrite',
      ),
      (
        'Il vento arriva da nord e resta stabile.',
        'Il vento arriva da sud e resta stabile.',
        'copyedit_rewrite',
      ),
      (
        'Il fanale di destra resta acceso.',
        'Il fanale di sinistra resta acceso.',
        'copyedit_rewrite',
      ),
      (
        'La correzione è -5 gradi sul valore.',
        'La correzione è 5 gradi sul valore.',
        'copyedit_number_changed',
      ),
      (
        'Il limite è 6 NM in quella zona.',
        'Il limite è 6 M in quella zona.',
        'copyedit_technical_token_changed',
      ),
      (
        'La batteria è da 12 V nominali.',
        'La batteria è da 12 A nominali.',
        'copyedit_technical_token_changed',
      ),
      (
        "L angolo è 30° sul rilevamento.",
        "L angolo è 30' sul rilevamento.",
        'copyedit_technical_token_changed',
      ),
      (
        'Il canale VHF resta quello indicato.',
        'Il canale MF/HF resta quello indicato.',
        'copyedit_technical_token_changed',
      ),
    ];
    for (final item in cases) {
      final store = MemoryTutorStore();
      final provider = ScriptedProvider(
        [_generated(explanation: item.$1)],
        copyedits: [_edited(explanation: item.$2)],
      );
      final events = <Map<String, Object?>>[];
      final summary = await _run(
        provider,
        write: true,
        showOutput: true,
        clock: fixedNow,
        store: store,
        log: events.add,
      );
      expect(summary.dbWrites, 0, reason: item.$1);
      expect(store.inserts, isEmpty, reason: item.$1);
      expect(summary.items.single.outcome, 'failed', reason: item.$1);
      expect(summary.items.single.explanation, isNull, reason: item.$1);
      expect(
        summary.items.single.rejections,
        contains(item.$3),
        reason: item.$1,
      );
      expect(
        events.single.containsKey('explanation'),
        isFalse,
        reason: item.$1,
      );
      expect(
        jsonEncode(events.single),
        isNot(contains(item.$2)),
        reason: item.$1,
      );
    }
  });

  test('without --copyedit the run stays one pass', () async {
    final provider = ScriptedProvider([_generated(explanation: _badSpace)]);
    final summary = await _run(
      provider,
      copyedit: false,
      showOutput: true,
      clock: fixedNow,
    );
    expect(provider.calls, 1);
    expect(provider.copyeditCalls, 0);
    expect(summary.providerCalls, 1);
    expect(summary.items.single.generationProviderCalls, 1);
    expect(summary.items.single.copyeditProviderCalls, 0);
    expect(summary.items.single.explanation, _badSpace);
    expect(summary.items.single.copyeditChanged, isNull);
    expect(summary.items.single.copyeditVersion, isNull);
    expect(summary.items.single.inputTokens, 10);
    expect(summary.inputTokens, 10);
  });

  test('first-pass 5nodi fails before any copyedit call', () async {
    const glued = 'Se mantieni una velocità di 5nodi per un’ora.';
    final provider = ScriptedProvider(
      [_generated(explanation: glued)],
      copyedits: [_edited(explanation: glued.replaceFirst('5nodi', '5 nodi'))],
    );
    final summary = await _run(
      provider,
      write: true,
      showOutput: true,
      clock: fixedNow,
      store: MemoryTutorStore(),
    );
    expect(provider.calls, 1);
    expect(provider.copyeditCalls, 0);
    expect(summary.dbWrites, 0);
    expect(summary.items.single.outcome, 'failed');
    expect(summary.items.single.explanation, isNull);
    expect(
      summary.items.single.rejections,
      contains('concatenated_number_word'),
    );
  });

  test('copyedit that introduces a glued number word is rejected', () async {
    const before = 'La regola descrive il calcolo veliero con calma.';
    const after = 'La regola descrive il calcolo 5veliero con calma.';
    final provider = ScriptedProvider(
      [_generated(explanation: before)],
      copyedits: [_edited(explanation: after)],
    );
    final summary = await _run(
      provider,
      write: true,
      showOutput: true,
      clock: fixedNow,
      store: MemoryTutorStore(),
    );
    expect(provider.copyeditCalls, 1);
    expect(summary.dbWrites, 0);
    expect(summary.items.single.explanation, isNull);
    expect(
      summary.items.single.rejections,
      contains('concatenated_number_word'),
    );
  });

  test('an explicit write stores only the copyedited text', () async {
    final question = sampleQuestion();
    final store = MemoryTutorStore();
    final provider = ScriptedProvider(
      [_generated(explanation: _badSpace)],
      copyedits: [_edited(explanation: _fixedSpace, changed: false)],
    );
    final summary = await _run(
      provider,
      write: true,
      showOutput: true,
      clock: fixedNow,
      store: store,
      question: question,
    );
    expect(summary.dbWrites, 1);
    expect(summary.items.single.copyeditChanged, isTrue);
    final stored = store.inserts.single;
    expect(stored.explanation, _fixedSpace);
    expect(stored.explanation, isNot(contains('misuratain')));
    expect(stored.status, 'review_required');
    expect(stored.reviewedAt, isNull);
    expect(stored.approvedAt, isNull);
    expect(stored.promptVersion, tutorLianaPromptVersion);
    expect(stored.copyeditVersion, tutorCopyeditVersion);
    expect(stored.toJson()['copyedit_version'], tutorCopyeditVersion);
    expect(stored.sourceHash, tutorSourceHash(question));
    expect(stored.simpleExplanation, _simple);
    expect(stored.memoryExample, _memory);
  });

  test(
    'copyedit retries are bounded and counted apart from generation',
    () async {
      final recovered = ScriptedProvider(
        [_generated(explanation: _clean)],
        copyedits: [
          OpenAITutorException('request timed out', transient: true),
          _edited(explanation: _clean),
        ],
      );
      final recoveredSummary = await _run(
        recovered,
        showOutput: true,
        clock: fixedNow,
      );
      expect(recovered.calls, 1);
      expect(recovered.copyeditCalls, 2);
      expect(recovered.copyeditCalls, lessThanOrEqualTo(3));
      expect(recoveredSummary.items.single.outcome, 'review_required');
      expect(recoveredSummary.items.single.generationProviderCalls, 1);
      expect(recoveredSummary.items.single.copyeditProviderCalls, 2);
      expect(recoveredSummary.items.single.providerCalls, 3);

      final exhausted = ScriptedProvider(
        [_generated(explanation: _clean)],
        copyedits: [
          OpenAITutorException('request timed out', transient: true),
          OpenAITutorException('request timed out', transient: true),
          OpenAITutorException('request timed out', transient: true),
          _edited(explanation: _clean),
        ],
      );
      final failed = await _run(
        exhausted,
        write: true,
        showOutput: true,
        clock: fixedNow,
        store: MemoryTutorStore(),
      );
      expect(exhausted.calls, 1);
      expect(exhausted.copyeditCalls, 3);
      expect(failed.dbWrites, 0);
      expect(failed.items.single.outcome, 'failed');
      expect(failed.items.single.explanation, isNull);
      expect(
        failed.items.single.rejections,
        contains('copyedit_provider_error'),
      );
    },
  );

  test('token and request accounting distinguishes the two passes', () async {
    final provider = ScriptedProvider(
      [_generated(explanation: _fixedSpace)],
      copyedits: [_edited(explanation: _fixedSpace)],
      usage: const TutorUsage(inputTokens: 10, outputTokens: 4),
      copyeditUsage: const TutorUsage(inputTokens: 3, outputTokens: 2),
      requestId: 'gen-req',
      responseId: 'gen-resp',
      copyeditRequestId: 'copy-req',
      copyeditResponseId: 'copy-resp',
    );
    final summary = await _run(
      provider,
      showOutput: true,
      clock: fixedNow,
      pricing: const PricingCatalog({
        'test-model': ModelPrice(
          inputUsdPerMillion: 1000000,
          outputUsdPerMillion: 2000000,
        ),
      }),
    );
    final item = summary.items.single;
    expect(item.generationProviderCalls, 1);
    expect(item.copyeditProviderCalls, 1);
    expect(item.providerCalls, 2);
    expect(item.generationInputTokens, 10);
    expect(item.generationOutputTokens, 4);
    expect(item.copyeditInputTokens, 3);
    expect(item.copyeditOutputTokens, 2);
    expect(item.inputTokens, 13);
    expect(item.outputTokens, 6);
    expect(item.model, 'test-model');
    expect(item.copyeditModel, 'test-model');
    expect(item.providerRequestId, 'gen-req');
    expect(item.providerResponseId, 'gen-resp');
    expect(item.copyeditRequestId, 'copy-req');
    expect(item.copyeditResponseId, 'copy-resp');
    expect(item.copyeditVersion, tutorCopyeditVersion);
    expect(summary.providerCalls, 2);
    expect(summary.inputTokens, 13);
    expect(summary.outputTokens, 6);
    expect(summary.estimatedCostUsd, 25.0);
    final json = item.toJson();
    expect(json['generation_provider_calls'], 1);
    expect(json['copyedit_provider_calls'], 1);
    expect(json['copyedit_openai_request_id'], 'copy-req');
    expect(json['openai_request_id'], 'gen-req');
  });

  test('--copyedit requires --generate and does not imply a write', () async {
    final help = await Process.run('dart', [
      'run',
      'bin/tutor_generate.dart',
      '--help',
    ]);
    expect(help.exitCode, 0);
    expect(help.stdout, contains('--copyedit'));
    expect(help.stdout, contains('does not write'));

    final catalog = await _catalogFile();
    addTearDown(() => catalog.parent.delete(recursive: true));
    final missingGenerate = await Process.run('dart', [
      'run',
      'bin/tutor_generate.dart',
      '--catalog',
      catalog.path,
      '--question-id',
      _questionId,
      '--copyedit',
    ]);
    expect(missingGenerate.exitCode, 2);
    expect(missingGenerate.stderr, contains('--copyedit requires --generate'));

    final gated = await Process.run('dart', [
      'run',
      'bin/tutor_generate.dart',
      '--catalog',
      catalog.path,
      '--question-id',
      _questionId,
      '--generate',
      '--copyedit',
      '--show-output',
    ]);
    expect(gated.exitCode, 2);
    expect(gated.stderr, contains('Refusing --generate'));
    expect(gated.stdout, isNot(contains('explanation')));
    expect(gated.stdout, isNot(contains('OPENAI_API_KEY')));
  });
}

TutorCopyeditCheck _check(String before, String after) {
  return verifyTutorCopyedit(
    beforeExplanation: before,
    beforeSimple: _simple,
    beforeMemory: _memory,
    afterExplanation: after,
    afterSimple: _simple,
    afterMemory: _memory,
  );
}

Map<String, Object?> _generated({required String explanation}) {
  return validModelJson()
    ..['explanation'] = explanation
    ..['simple_explanation'] = _simple
    ..['memory_example'] = _memory;
}

Map<String, Object?> _edited({
  required String explanation,
  bool changed = false,
  String? reviewReason,
}) {
  return {
    'explanation': explanation,
    'simple_explanation': _simple,
    'memory_example': _memory,
    'changed': changed,
    'review_reason': reviewReason,
  };
}

Future<TutorRunSummary> _run(
  ScriptedProvider provider, {
  required DateTime clock,
  bool write = false,
  bool showOutput = false,
  bool copyedit = true,
  TutorExplanationStore? store,
  TutorQuestion? question,
  PricingCatalog pricing = const PricingCatalog({}),
  void Function(Map<String, Object?> event)? log,
}) {
  final item = catalogItem(question ?? sampleQuestion());
  return TutorPipeline(
    catalog: FixedCatalog([item]),
    store: store ?? ThrowingStore(),
    provider: provider,
    images: UnavailableImageSource(),
    clock: () => clock,
    log: log,
  ).run(
    TutorRunRequest(
      selection: const TutorSelection(limit: 1),
      generate: true,
      write: write,
      regenerate: false,
      forceApproved: false,
      showOutput: showOutput,
      copyedit: copyedit,
      pricing: pricing,
    ),
  );
}

const _questionId = '11111111-1111-4111-8111-111111111111';

Future<File> _catalogFile() async {
  final directory = await Directory.systemTemp.createTemp('tutor-copyedit-');
  final file = File('${directory.path}/catalog.json');
  await file.writeAsString(
    jsonEncode([
      {
        'id': _questionId,
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
