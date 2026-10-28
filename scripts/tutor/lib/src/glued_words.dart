// Deterministic letter-join repairs and the leftovers that must not pass.
//
// A generic split of every Italian word that starts with an article is not
// used: `lavoro`, `laterale`, and `sistema` are real words. Repairs are
// limited to joins whose boundary is unique. Anything still suspicious is
// reported and rejected, not guessed.

final RegExp _tokenBoundaryBefore = RegExp(r'(?<![0-9A-Za-zÀ-ÿ])');

/// Observed pilot joins with one safe spacing. Longest keys are applied first.
const _explicitGluedRepairs = <String, String>{
  "superficiedell'acqua": "superficie dell'acqua",
  'superficiedell’acqua': 'superficie dell’acqua',
  'elettricaalimentata': 'elettrica alimentata',
  'imbarcazionedovuto': 'imbarcazione dovuto',
  'condizioniindicate': 'condizioni indicate',
  'Lacaratteristica': 'La caratteristica',
  'lacaratteristica': 'la caratteristica',
  'quellogenerato': 'quello generato',
  'consideratouso': 'considerato uso',
  'carburantenel': 'carburante nel',
  'distanzache': 'distanza che',
  'dellalinea': 'della linea',
  'gialloalla': 'giallo alla',
  'periododi': 'periodo di',
  'nondevono': 'non devono',
  'Laregola': 'La regola',
  'laregola': 'la regola',
  'quelladi': 'quella di',
  'siavvia': 'si avvia',
  'labrezza': 'la brezza',
  'laterra': 'la terra',
  'labarca': 'la barca',
  'vadalla': 'va dalla',
  'seusato': 'se usato',
  'èla': 'è la',
};

const _closedSuffixes = [
  'negli',
  'nella',
  'nelle',
  'nello',
  'della',
  'dello',
  'delle',
  'degli',
  'sulla',
  'sullo',
  'sulle',
  'sugli',
  'dalla',
  'dallo',
  'dalle',
  'dagli',
  'alla',
  'allo',
  'alle',
  'agli',
  'nel',
];

final RegExp _demonstrativeGlue = RegExp(
  r'(?<![A-Za-zÀ-ÿ])(quello|quella|quelli|quelle)(?=[a-zàèéìòù]{4,})',
);

final RegExp _nonGlue = RegExp(r'(?<![A-Za-zÀ-ÿ])(non|Non)(?=[a-zàèéìòù]{5,})');

final RegExp _apostropheCliticGlue = RegExp(
  r"(?<![A-Za-zÀ-ÿ])([A-Za-zÀ-ÿ]{4,})((?:dell|nell|sull|all|dall|quell)['’])",
);

final RegExp _accentedEGlue = RegExp(r"(?<![A-Za-zÀ-ÿ])(è)(?=[a-zàèéìòù]{2,})");

/// `mail` is `ma` + `il` in the pilot corpus and also an English word.
/// The spacing is not guessed.
final RegExp _uncertainMail = RegExp(
  r'(?<![A-Za-zÀ-ÿ])mail(?![A-Za-zÀ-ÿ])',
  caseSensitive: false,
);

final RegExp _closedSuffixGlue = RegExp(
  '(?<![A-Za-zÀ-ÿ])([A-Za-zÀ-ÿ]{6,})(${_closedSuffixes.join('|')})(?![A-Za-zÀ-ÿ])',
);

String repairTutorGluedWords(String text) {
  var next = text;
  final keys = _explicitGluedRepairs.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  for (final glued in keys) {
    next = next.replaceAll(
      RegExp(
        '${_tokenBoundaryBefore.pattern}${RegExp.escape(glued)}(?![A-Za-zÀ-ÿ])',
      ),
      _explicitGluedRepairs[glued]!,
    );
  }
  next = next.replaceAllMapped(
    _demonstrativeGlue,
    (match) => '${match.group(1)} ',
  );
  next = next.replaceAllMapped(_nonGlue, (match) {
    final following = match.input.substring(match.end);
    if (following.startsWith('ostante') || following.startsWith('dimeno')) {
      return match.group(0)!;
    }
    return '${match.group(1)} ';
  });
  next = next.replaceAllMapped(
    _closedSuffixGlue,
    (match) => '${match.group(1)} ${match.group(2)}',
  );
  next = next.replaceAllMapped(
    _apostropheCliticGlue,
    (match) => '${match.group(1)} ${match.group(2)}',
  );
  next = next.replaceAllMapped(_accentedEGlue, (match) => '${match.group(1)} ');
  return next;
}

/// Tokens that remain suspicious after [repairTutorGluedWords].
List<String> tutorUncertainGluedTokens(String text) {
  return [for (final match in _uncertainMail.allMatches(text)) match.group(0)!];
}
