import 'package:test/test.dart';
import 'package:tutor_liana_generator/tutor_generator.dart';

import 'support.dart';

void main() {
  const clean = 'Il nodo misura la velocità, non la distanza.';

  test('a missing space after a comma, semicolon, or colon is inserted', () {
    expect(normalizeTutorTypographyText('velocità,non'), 'velocità, non');
    expect(
      normalizeTutorTypographyText(
        'Se navighi a velocità costante di 5 nodi,in un’ora.',
      ),
      'Se navighi a velocità costante di 5 nodi, in un’ora.',
    );
    expect(normalizeTutorTypographyText('vero;quindi'), 'vero; quindi');
    expect(
      normalizeTutorTypographyText('attenzione:questa'),
      'attenzione: questa',
    );
  });

  test('numbers, times, URLs, and technical notation stay unchanged', () {
    const unchanged = [
      '1,5',
      '10,25',
      '12:30',
      '4:6',
      'https://example.com',
      'http://example.com/a',
      'VHF/FM',
      'MF/HF',
      '10kW',
      '6NM',
      '12V',
      '30°',
      "60'",
      '-5',
      '6 NM',
      '12 V',
      'Rotta N',
      'Rotta NE',
    ];
    for (final text in unchanged) {
      expect(normalizeTutorTypographyText(text), text, reason: text);
    }
  });

  test('correct spacing is unchanged and the normalizer is idempotent', () {
    expect(normalizeTutorTypographyText(clean), clean);
    final once = normalizeTutorTypographyText('velocità,non;quindi:questa');
    expect(normalizeTutorTypographyText(once), once);
    expect(once, 'velocità, non; quindi: questa');
  });

  test('all three Tutor fields are normalized', () {
    final output = normalizeTutorTypographyOutput(
      const TutorParsedOutput(
        explanation: 'velocità,non',
        simpleExplanation: 'vero;quindi',
        memoryExample: 'attenzione:questa',
        needsReview: false,
        reviewReason: null,
      ),
    );
    expect(output.explanation, 'velocità, non');
    expect(output.simpleExplanation, 'vero; quindi');
    expect(output.memoryExample, 'attenzione: questa');
    expect(output.needsReview, isFalse);
  });

  test('a known unit glued to a number is spaced and then accepted', () {
    expect(
      normalizeTutorTypographyText('Se navighi a 5nodi.'),
      'Se navighi a 5 nodi.',
    );
    expect(
      normalizeTutorTypographyText('Con 30litri resti in mare.'),
      'Con 30 litri resti in mare.',
    );
    expect(
      normalizeTutorTypographyText('Si ottiene circa69 minuti.'),
      'Si ottiene circa 69 minuti.',
    );
    final report = validateTutorOutput(
      normalizeTutorTypographyOutput(
        const TutorParsedOutput(
          explanation: 'Se navighi a 5nodi per un’ora.',
          simpleExplanation: 'Con 30litri resti in mare.',
          memoryExample: 'Si ottiene circa69 minuti.',
          needsReview: false,
          reviewReason: null,
        ),
      ),
      correctOption: 'A',
    );
    expect(report.acceptForReview, isTrue);
    expect(report.rejections, isEmpty);
  });

  test('an unknown number join is not guessed and stays rejected', () {
    expect(normalizeTutorTypographyText('Codice 5qwerty.'), 'Codice 5qwerty.');
    expect(normalizeTutorTypographyText('Vedi pagina12.'), 'Vedi pagina12.');
    final report = validateTutorOutput(
      const TutorParsedOutput(
        explanation: 'Codice 5qwerty resta fuori dalla regola.',
        simpleExplanation: 'Vedi pagina12 e poi fermati.',
        memoryExample: 'Pensala come una boa.',
        needsReview: false,
        reviewReason: null,
      ),
      correctOption: 'A',
    );
    expect(report.acceptForReview, isFalse);
    expect(report.rejections, contains('concatenated_number_word'));
  });

  test('observed pilot spacing defects are fixed or rejected', () {
    const repairs = {
      'mare,la': 'mare, la',
      'rispondere,occorre': 'rispondere, occorre',
      'gasolio,nel': 'gasolio, nel',
      'disponibili,si': 'disponibili, si',
      'iniettori.Il': 'iniettori. Il',
      'costa.Il': 'costa. Il',
      '30litri': '30 litri',
      'circa69': 'circa 69',
      'quellogenerato': 'quello generato',
      'elettricaalimentata': 'elettrica alimentata',
      'distanzache': 'distanza che',
      'carburantenel': 'carburante nel',
      "superficiedell'acqua": "superficie dell'acqua",
      'labrezza': 'la brezza',
      'laterra': 'la terra',
      'vadalla': 'va dalla',
      'seusato': 'se usato',
      'quelladi': 'quella di',
      'èla': 'è la',
      'labarca': 'la barca',
      'dellalinea': 'della linea',
      'periododi': 'periodo di',
      'gialloalla': 'giallo alla',
      'Lacaratteristica': 'La caratteristica',
      'consideratouso': 'considerato uso',
      'siavvia': 'si avvia',
      'nondevono': 'non devono',
      'condizioniindicate': 'condizioni indicate',
      'Laregola': 'La regola',
      'imbarcazionedovuto': 'imbarcazione dovuto',
    };
    for (final entry in repairs.entries) {
      final normalized = normalizeTutorTypographyText(entry.key);
      expect(normalized, entry.value, reason: entry.key);
      expect(
        normalizeTutorTypographyText(normalized),
        normalized,
        reason: entry.key,
      );
      expect(normalized.contains(entry.key), isFalse, reason: entry.key);
    }

    final mail = validateTutorOutput(
      const TutorParsedOutput(
        explanation: 'Il motore gira ma il gasolio non arriva.',
        simpleExplanation: 'Confronta mail con la regola ufficiale.',
        memoryExample: 'Pensala come una boa.',
        needsReview: false,
        reviewReason: null,
      ),
      correctOption: 'A',
    );
    expect(normalizeTutorTypographyText('mail'), 'mail');
    expect(mail.acceptForReview, isFalse);
    expect(mail.rejections, contains('glued_word'));
    expect(
      validateTutorOutput(
        const TutorParsedOutput(
          explanation: 'Il motore gira ma il gasolio non arriva.',
          simpleExplanation: 'Invia una email solo se serve.',
          memoryExample: 'Pensala come una boa.',
          needsReview: false,
          reviewReason: null,
        ),
        correctOption: 'A',
      ).acceptForReview,
      isTrue,
    );
  });

  test('legitimate Italian and technical forms are not split', () {
    const unchanged = [
      'lavoro',
      'laterale',
      'latitudine',
      'iniettori',
      'distanza',
      'sistema',
      'sicurezza',
      'sempre',
      'periodo',
      'condizioni',
      'nonostante',
      'elettriche',
      'biblioteche',
      'farfalla',
      'gialla',
      'cannella',
      'imbarcazione',
      'caratteristica',
      'terraferma',
      "dell'imbarcazione",
      "nell'ora",
      "sull'unità",
      "un'altra",
      "l'acqua",
      'email',
      'lavoro',
      'laterale',
      'lamiera',
      'lancio',
      'maiale',
      'mai',
      'nondimeno',
      'nonostante',
      'pericolo',
      'partenza',
      'conoscenza',
      'diporto',
      'Pensala',
      '12V',
      '24V',
      '090°',
      '180°',
      '10kW',
      '6NM',
      '5s',
      '26m',
      '50esimo',
      '1,5',
      '3.5',
      '1.032,00',
      '6.197,00',
      'VHF',
      '12:30',
      'Fl.Y.3s4M',
      "dall'altezza",
      "dell'imbarcazione",
      "nell'acqua",
      "sull'unità",
      "l'acqua",
      "un'altra",
      'quello generato',
      'la brezza',
      '30 litri',
      'circa 69',
    ];
    for (final text in unchanged) {
      expect(normalizeTutorTypographyText(text), text, reason: text);
      final report = validateTutorOutput(
        TutorParsedOutput(
          explanation: 'La regola ufficiale resta $text per lo studente.',
          simpleExplanation: 'In breve, conta la risposta ufficiale.',
          memoryExample: 'Pensala come una boa.',
          needsReview: false,
          reviewReason: null,
        ),
        correctOption: 'A',
      );
      expect(report.acceptForReview, isTrue, reason: text);
      expect(report.rejections, isEmpty, reason: text);
    }
  });

  test(
    'a copyedit echo of glued text is repaired and is not a quality pass by itself',
    () async {
      const glued =
          'Il mare,la regola dice che quellogenerato resta valido. Con 30litri e circa69 minuti.';
      final generated = validModelJson()
        ..['explanation'] = glued
        ..['simple_explanation'] = 'In breve, costa.Il motore siavvia.'
        ..['memory_example'] = 'Pensala come una boa.';
      final provider = ScriptedProvider(
        [generated],
        copyedits: [
          {
            'explanation': glued,
            'simple_explanation': 'In breve, costa.Il motore siavvia.',
            'memory_example': 'Pensala come una boa.',
            'changed': false,
            'review_reason': null,
          },
        ],
      );
      final store = MemoryTutorStore();
      final summary =
          await TutorPipeline(
            catalog: FixedCatalog([catalogItem(sampleQuestion())]),
            store: store,
            provider: provider,
            images: UnavailableImageSource(),
            clock: () => DateTime.utc(2026, 10, 29),
          ).run(
            const TutorRunRequest(
              selection: TutorSelection(limit: 1),
              generate: true,
              write: true,
              regenerate: false,
              forceApproved: false,
              showOutput: true,
              copyedit: true,
            ),
          );
      final item = summary.items.single;
      expect(summary.dbWrites, 1);
      expect(item.outcome, 'review_required');
      expect(item.copyeditChanged, isFalse);
      expect(item.typographyNormalized, isTrue);
      expect(item.explanation, contains('mare, la'));
      expect(item.explanation, contains('quello generato'));
      expect(item.explanation, contains('30 litri'));
      expect(item.explanation, contains('circa 69'));
      expect(item.simpleExplanation, contains('costa. Il'));
      expect(item.simpleExplanation, contains('si avvia'));
      expect(item.explanation, isNot(contains('mare,la')));
      expect(item.explanation, isNot(contains('30litri')));
      expect(store.inserts, hasLength(1));
      expect(store.inserts.single.status, 'review_required');
      expect(store.inserts.single.explanation, contains('mare, la'));
      expect(store.inserts.single.explanation, isNot(contains('mare,la')));
    },
  );

  test('an uncertain join is rejected and is not written', () async {
    final generated = validModelJson()
      ..['simple_explanation'] = 'Confronta mail con la regola ufficiale.';
    final provider = ScriptedProvider(
      [generated],
      copyedits: [
        {
          'explanation': generated['explanation'],
          'simple_explanation': 'Confronta mail con la regola ufficiale.',
          'memory_example': generated['memory_example'],
          'changed': false,
          'review_reason': null,
        },
      ],
    );
    final store = MemoryTutorStore();
    final summary =
        await TutorPipeline(
          catalog: FixedCatalog([catalogItem(sampleQuestion())]),
          store: store,
          provider: provider,
          images: UnavailableImageSource(),
          clock: () => DateTime.utc(2026, 10, 29),
        ).run(
          const TutorRunRequest(
            selection: TutorSelection(limit: 1),
            generate: true,
            write: true,
            regenerate: false,
            forceApproved: false,
            showOutput: true,
            copyedit: true,
          ),
        );
    final item = summary.items.single;
    expect(summary.dbWrites, 0);
    expect(store.inserts, isEmpty);
    expect(item.outcome, 'failed');
    expect(provider.copyeditCalls, 0);
    expect(item.rejections, contains('glued_word'));
  });

  test('real pilot 2 joins are repaired and no longer silently accepted', () {
    const repairs = {
      'navigaentro': 'naviga entro',
      'dall’altezzadelle': 'dall’altezza delle',
      'dueimbarcazioni': 'due imbarcazioni',
      'anchedall’altezza': 'anche dall’altezza',
      'bendistante': 'ben distante',
      'Pensaal': 'Pensa al',
      'lacilindrata': 'la cilindrata',
      'cilindrataè': 'cilindrata è',
      'ai29': 'ai 29',
      'lasciarelibero': 'lasciare libero',
      'obbligatoriala': 'obbligatoria la',
      'migliadalla': 'miglia dalla',
      'Questonon': 'Questo non',
      'unacustodia': 'una custodia',
      'propriaimbarcazione': 'propria imbarcazione',
      'di150': 'di 150',
      'edi': 'e di',
      'bisognodi': 'bisogno di',
      'allacosta': 'alla costa',
      'digalleggiamento': 'di galleggiamento',
      'partedello': 'parte dello',
      'attuazioneal': 'attuazione al',
      'almenoun': 'almeno un',
      'guida,poi': 'guida, poi',
      'frontefreddo': 'fronte freddo',
      'spingeverso': 'spinge verso',
      'epunta': 'e punta',
      'Conil': 'Con il',
      'Perciò048°': 'Perciò 048°',
      'lasigla': 'la sigla',
      'tragittoè': 'tragitto è',
      'consumatie': 'consumati e',
      'sitrova': 'si trova',
      'hail': 'ha il',
      'interv allo': 'intervallo',
      'più di150': 'più di 150',
    };
    for (final entry in repairs.entries) {
      final normalized = normalizeTutorTypographyText(entry.key);
      expect(normalized, entry.value, reason: entry.key);
      expect(normalized.contains(entry.key), isFalse, reason: entry.key);
      final report = validateTutorOutput(
        TutorParsedOutput(
          explanation: 'La regola ufficiale resta chiara: ${entry.value}.',
          simpleExplanation: 'In breve, conta la risposta ufficiale.',
          memoryExample: 'Pensala come una boa.',
          needsReview: false,
          reviewReason: null,
        ),
        correctOption: 'A',
      );
      expect(report.acceptForReview, isTrue, reason: entry.key);
      expect(report.rejections, isEmpty, reason: entry.key);
    }
  });

  test('a real spaced pilot sentence is not rewritten', () {
    const sentence =
        "Per un'imbarcazione da diporto che naviga entro le 12 miglia.";
    expect(normalizeTutorTypographyText(sentence), sentence);
    expect(
      validateTutorOutput(
        const TutorParsedOutput(
          explanation: sentence,
          simpleExplanation: 'In breve, conta la risposta ufficiale.',
          memoryExample: 'Pensala come una boa.',
          needsReview: false,
          reviewReason: null,
        ),
        correctOption: 'A',
      ).acceptForReview,
      isTrue,
    );
  });

  test('an unresolved internal join is rejected and is not rewritten', () {
    const glued = 'La pruadellaimbarcazione resta visibile.';
    expect(normalizeTutorTypographyText(glued), glued);
    final report = validateTutorOutput(
      const TutorParsedOutput(
        explanation: glued,
        simpleExplanation: 'In breve, conta la risposta ufficiale.',
        memoryExample: 'Pensala come una boa.',
        needsReview: false,
        reviewReason: null,
      ),
      correctOption: 'A',
    );
    expect(report.acceptForReview, isFalse);
    expect(report.rejections, contains('glued_word'));
  });

  test('the final gate repairs a copyedit echo and rejects one it cannot', () async {
    const clean = 'La barca naviga entro il porto con il vento.';
    final generated = validModelJson()
      ..['explanation'] = clean.replaceAll('naviga entro', 'navigaentro')
      ..['simple_explanation'] = 'Il valore resta nell’interv allo utile.'
      ..['memory_example'] = 'Pensala come una boa.';
    final provider = ScriptedProvider(
      [generated],
      copyedits: [
        {
          'explanation': clean.replaceAll('naviga entro', 'navigaentro'),
          'simple_explanation': 'Il valore resta nell’interv allo utile.',
          'memory_example': 'Pensala come una boa.',
          'changed': false,
          'review_reason': null,
        },
      ],
    );
    final store = MemoryTutorStore();
    final summary =
        await TutorPipeline(
          catalog: FixedCatalog([catalogItem(sampleQuestion())]),
          store: store,
          provider: provider,
          images: UnavailableImageSource(),
          clock: () => DateTime.utc(2026, 10, 29),
        ).run(
          const TutorRunRequest(
            selection: TutorSelection(limit: 1),
            generate: true,
            write: true,
            regenerate: false,
            forceApproved: false,
            showOutput: true,
            copyedit: true,
          ),
        );
    final item = summary.items.single;
    expect(item.outcome, 'review_required');
    expect(item.explanation, contains('naviga entro'));
    expect(item.explanation, isNot(contains('navigaentro')));
    expect(item.simpleExplanation, contains('intervallo'));
    expect(item.simpleExplanation, isNot(contains('interv allo')));
    expect(store.inserts.single.explanation, contains('naviga entro'));
    expect(provider.lastCopyedit?.explanation, contains('naviga entro'));

    final rejected = ScriptedProvider(
      [
        validModelJson()
          ..['explanation'] = 'La prua della imbarcazione resta visibile.'
          ..['simple_explanation'] = 'In breve, conta la risposta ufficiale.'
          ..['memory_example'] = 'Pensala come una boa.',
      ],
      copyedits: [
        {
          'explanation': 'La pruadellaimbarcazione resta visibile.',
          'simple_explanation': 'In breve, conta la risposta ufficiale.',
          'memory_example': 'Pensala come una boa.',
          'changed': true,
          'review_reason': null,
        },
      ],
    );
    final rejectedStore = MemoryTutorStore();
    final rejectedSummary =
        await TutorPipeline(
          catalog: FixedCatalog([catalogItem(sampleQuestion())]),
          store: rejectedStore,
          provider: rejected,
          images: UnavailableImageSource(),
          clock: () => DateTime.utc(2026, 10, 29),
        ).run(
          const TutorRunRequest(
            selection: TutorSelection(limit: 1),
            generate: true,
            write: true,
            regenerate: false,
            forceApproved: false,
            showOutput: true,
            copyedit: true,
          ),
        );
    expect(rejectedSummary.dbWrites, 0);
    expect(rejectedStore.inserts, isEmpty);
    expect(rejected.copyeditCalls, 1);
    expect(rejectedSummary.items.single.outcome, 'failed');
    expect(rejectedSummary.items.single.rejections, contains('glued_word'));
  });

  test('semantic and technical copyedit guards stay in place', () {
    expect(
      verifyTutorCopyedit(
        beforeExplanation: 'La prua della barca resta visibile.',
        beforeSimple: 'Il vento arriva da nord.',
        beforeMemory: 'Rotta N.',
        afterExplanation: 'La poppa della barca resta visibile.',
        afterSimple: 'Il vento arriva da sud.',
        afterMemory: 'Rotta S.',
      ).rejections,
      containsAll(['copyedit_rewrite', 'copyedit_technical_token_changed']),
    );
    expect(
      verifyTutorCopyedit(
        beforeExplanation: 'La correzione è -5 gradi.',
        beforeSimple: 'Il limite è 6 NM.',
        beforeMemory: 'La batteria è da 12 V e l angolo è 30° sul canale VHF.',
        afterExplanation: 'La correzione è 5 gradi.',
        afterSimple: 'Il limite è 6 M.',
        afterMemory:
            'La batteria è da 12 A e l angolo è 30\' sul canale MF/HF.',
      ).rejections,
      containsAll([
        'copyedit_number_changed',
        'copyedit_technical_token_changed',
      ]),
    );
  });

  test(
    'a live-style copyedit echo is spaced locally and not marked as a model change',
    () async {
      const simple = 'Il nodo misura la velocità,non la distanza.';
      const memory =
          'Se navighi a velocità costante di 5 nodi,in un’ora percorri 5 miglia marine.';
      final generated = validModelJson()
        ..['simple_explanation'] = simple
        ..['memory_example'] = memory;
      final provider = ScriptedProvider(
        [generated],
        copyedits: [
          {
            'explanation': generated['explanation'],
            'simple_explanation': simple,
            'memory_example': memory,
            'changed': false,
            'review_reason': null,
          },
        ],
      );
      final summary =
          await TutorPipeline(
            catalog: FixedCatalog([catalogItem(sampleQuestion())]),
            store: ThrowingStore(),
            provider: provider,
            images: UnavailableImageSource(),
            clock: () => DateTime.utc(2026, 10, 27),
          ).run(
            const TutorRunRequest(
              selection: TutorSelection(limit: 1),
              generate: true,
              write: false,
              regenerate: false,
              forceApproved: false,
              showOutput: true,
              copyedit: true,
            ),
          );
      final item = summary.items.single;
      expect(summary.dbWrites, 0);
      expect(provider.copyeditCalls, 1);
      expect(item.outcome, 'review_required');
      expect(item.copyeditChanged, isFalse);
      expect(item.typographyNormalized, isTrue);
      expect(
        item.simpleExplanation,
        'Il nodo misura la velocità, non la distanza.',
      );
      expect(
        item.memoryExample,
        'Se navighi a velocità costante di 5 nodi, in un’ora percorri 5 miglia marine.',
      );
      expect(item.simpleExplanation, isNot(contains(',non')));
      expect(item.memoryExample, isNot(contains(',in')));
      expect(provider.lastCopyedit?.simpleExplanation, contains(', non'));
    },
  );
}
