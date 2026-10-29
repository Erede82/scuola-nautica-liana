import 'italian_lexicon.dart';

// Deterministic letter-join repairs and the leftovers that must not pass.
//
// A generic split of every Italian word that starts with an article is not
// used: `lavoro`, `laterale`, and `sistema` are real words. A missing space
// is inserted only when a token has one high-confidence decomposition into
// known lexemes, with a closed-class word on one side or two long content
// words. Anything still suspicious is left unchanged and rejected.

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

final RegExp _accentedEGlue = RegExp(r"(?<![A-Za-zÀ-ÿ])(è)(?=[a-zàèéìòù]{2,})");

final List<String> _closedSuffixesLongestFirst = List<String>.of(
  _closedSuffixes,
)..sort((a, b) => b.length.compareTo(a.length));

final RegExp _letterRun = RegExp(r'[A-Za-zÀ-ÿ]+');

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
  next = _repairLongestClosedSuffix(next);
  next = next.replaceAllMapped(_accentedEGlue, (match) => '${match.group(1)} ');
  next = _repairUnknownJoins(next);
  next = _repairSplitWords(next);
  return next;
}

/// Tokens that remain suspicious after [repairTutorGluedWords].
List<String> tutorUncertainGluedTokens(String text) {
  final found = <String>[];
  for (final match in _spacingToken.allMatches(text)) {
    final decision = _decideToken(match.group(0)!);
    if (decision.action != _SpacingAction.unchanged) {
      found.add(match.group(0)!);
    }
  }
  return found;
}

/// Report-only inventory. Does not rewrite [text].
List<TutorSpacingFinding> tutorSpacingFindings(String text) {
  final findings = <TutorSpacingFinding>[];
  for (final match in _spacingToken.allMatches(text)) {
    final token = match.group(0)!;
    final decision = _decideToken(token);
    if (decision.action == _SpacingAction.unchanged) continue;
    findings.add(
      TutorSpacingFinding(
        token: token,
        replacement: decision.replacement,
        context: _context(text, match.start, match.end),
        reason: decision.reason,
        severity: 'high',
        action: decision.action == _SpacingAction.fixed
            ? 'AUTO_FIXED'
            : 'REJECTED_FOR_REVIEW',
        start: match.start,
      ),
    );
  }
  for (final match in _splitWord.allMatches(text)) {
    final token = match.group(0)!;
    final joined = _joinSplitWord(match.group(1)!, match.group(2)!);
    if (joined == null) continue;
    findings.add(
      TutorSpacingFinding(
        token: token,
        replacement: joined,
        context: _context(text, match.start, match.end),
        reason: 'split_word',
        severity: 'high',
        action: 'AUTO_FIXED',
        start: match.start,
      ),
    );
  }
  return findings;
}

class TutorSpacingFinding {
  const TutorSpacingFinding({
    required this.token,
    required this.replacement,
    required this.context,
    required this.reason,
    required this.severity,
    required this.action,
    required this.start,
  });

  final String token;
  final String replacement;
  final String context;
  final String reason;
  final String severity;
  final String action;
  final int start;

  Map<String, Object?> toJson() => {
    'token': token,
    'replacement': replacement,
    'context': context,
    'reason': reason,
    'severity': severity,
    'action': action,
    'start': start,
  };
}

enum _SpacingAction { unchanged, fixed, uncertain }

class _TokenDecision {
  const _TokenDecision(this.action, this.replacement, this.reason);

  final _SpacingAction action;
  final String replacement;
  final String reason;
}

const _unchangedToken = _TokenDecision(_SpacingAction.unchanged, '', '');

const _apostropheClitics = [
  "dall'",
  "dell'",
  "nell'",
  "sull'",
  "all'",
  "quell'",
  "un'",
  "l'",
];

const _beforeDigits = {
  'ai',
  'al',
  'col',
  'con',
  'da',
  'dal',
  'del',
  'di',
  'fra',
  'gli',
  'ha',
  'ho',
  'il',
  'la',
  'le',
  'lo',
  'nel',
  'per',
  'piu',
  'più',
  'si',
  'sul',
  'tra',
  'un',
  'una',
  'uno',
};

const _shortClitics = {'ci', 'gli', 'la', 'le', 'li', 'lo', 'mi', 'ne', 'si', 'ti', 'vi'};

const _accentedWholes = {
  'affinché',
  'affinchè',
  'benché',
  'benchè',
  'caffè',
  'cioè',
  'cosicché',
  'è',
  'finché',
  'finchè',
  'giacché',
  'giacchè',
  'mosè',
  'né',
  'nè',
  'nonché',
  'perché',
  'perchè',
  'piè',
  'poiché',
  'poichè',
  'purché',
  'purchè',
  'sicché',
  'tè',
};

final RegExp _spacingToken = RegExp(
  r"[A-Za-zÀ-ÿ]+(?:['’][A-Za-zÀ-ÿ]+)+|[A-Za-zÀ-ÿ]+[0-9]+°?|[A-Za-zÀ-ÿ]+",
);

final RegExp _degreeGlue = RegExp(r'^([A-Za-zÀ-ÿ]{2,})([0-9]+°)$');

final RegExp _wordThenDigits = RegExp(r'^([A-Za-zÀ-ÿ]{2,})([0-9]+)$');

final RegExp _splitWord = RegExp(
  r'(?<![A-Za-zÀ-ÿ])([A-Za-zÀ-ÿ]{5,10}) ([A-Za-zÀ-ÿ]{3,5})(?![A-Za-zÀ-ÿ])',
);

final List<String> _longClosed = tutorClosedClassWords
    .where((word) => word.length >= 4 && !word.contains("'"))
    .toList()
  ..sort((a, b) => b.length.compareTo(a.length));

String _fold(String value) =>
    value.replaceAll('’', "'").replaceAll('‘', "'").toLowerCase();

bool _isLexeme(String foldedLower) {
  if (tutorItalianLexemes.contains(foldedLower)) return true;
  for (final clitic in _apostropheClitics) {
    if (!foldedLower.startsWith(clitic)) continue;
    final tail = foldedLower.substring(clitic.length);
    if (tail.isNotEmpty && tutorItalianLexemes.contains(tail)) return true;
  }
  return false;
}

_TokenDecision _fixed(String replacement, String reason) =>
    _TokenDecision(_SpacingAction.fixed, replacement, reason);

_TokenDecision _uncertain(String reason) =>
    _TokenDecision(_SpacingAction.uncertain, '', reason);

_TokenDecision _decideToken(String token) {
  final folded = _fold(token);
  // `mail` is both `ma` + `il` and an English word. Do not guess a space.
  if (folded == 'mail') return _uncertain('uncertain_mail');
  if (_isLexeme(folded) || _accentedWholes.contains(folded)) {
    return _unchangedToken;
  }
  final degree = _degreeGlue.firstMatch(token);
  if (degree != null) {
    return _fixed(
      '${degree.group(1)} ${degree.group(2)}',
      'degree_number',
    );
  }
  final wordDigits = _wordThenDigits.firstMatch(token);
  if (wordDigits != null &&
      _beforeDigits.contains(_fold(wordDigits.group(1)!))) {
    return _fixed(
      '${wordDigits.group(1)} ${wordDigits.group(2)}',
      'word_number',
    );
  }
  if ((token.endsWith('è') || token.endsWith('È')) && token.length >= 5) {
    final left = token.substring(0, token.length - 1);
    if (_isLexeme(_fold(left))) {
      return _fixed('$left è', 'word_e');
    }
  }
  if (folded.contains("'")) {
    final apostrophe = _decideApostrophe(token, folded);
    if (apostrophe != null) return apostrophe;
  }
  final splits = _contentSplits(folded);
  if (splits.length == 1) {
    final index = splits.single;
    return _fixed(
      '${token.substring(0, index)} ${token.substring(index)}',
      _splitReason(folded, index),
    );
  }
  if (splits.length > 1) return _uncertain('ambiguous_split');
  if (_unresolvedClosedBoundary(folded)) {
    return _uncertain('unresolved_closed_boundary');
  }
  return _unchangedToken;
}

String _splitReason(String folded, int index) {
  final left = folded.substring(0, index);
  final right = folded.substring(index);
  if (tutorClosedClassWords.contains(left) ||
      tutorClosedClassWords.contains(right)) {
    return 'closed_class_boundary';
  }
  return 'content_lexemes';
}

bool _validSplit(String left, String right) {
  if (!_isLexeme(left) || !_isLexeme(right)) return false;
  final leftClosed = tutorClosedClassWords.contains(left);
  final rightClosed = tutorClosedClassWords.contains(right);
  if (leftClosed || rightClosed) {
    if (left.length == 1 && left != 'e' && left != 'è') return false;
    if (right.length == 1 && right != 'e' && right != 'è') return false;
    if (left.length == 1 && !rightClosed && right.length < 4) return false;
    if (right.length == 1 && left.length < 6) return false;
    if (_shortClitics.contains(right) && left.length < 8) return false;
    // `vedi` is `ve` + `di`, and `invia` is `in` + `via`. A one- or
    // two-letter function word may join only another function word, or a
    // content word of at least four letters.
    if ((leftClosed && left.length <= 2) || (rightClosed && right.length <= 2)) {
      final contentIsLeft = rightClosed && right.length <= 2;
      final content = contentIsLeft ? left : right;
      final contentClosed = contentIsLeft ? leftClosed : rightClosed;
      if (!contentClosed && content.length < 4) return false;
    }
    return true;
  }
  if (right.contains("'") && left.length >= 4 && _isLexeme(right)) {
    return true;
  }
  return left.length >= 4 &&
      right.length >= 4 &&
      !left.contains("'") &&
      !right.contains("'") &&
      left.length + right.length >= 10;
}

List<int> _contentSplits(String folded) {
  if (folded.contains("'") || RegExp(r'[0-9]').hasMatch(folded)) {
    return const [];
  }
  final hits = <int>[];
  for (var index = 1; index < folded.length; index++) {
    if (_validSplit(folded.substring(0, index), folded.substring(index))) {
      hits.add(index);
    }
  }
  return hits;
}

_TokenDecision? _decideApostrophe(String token, String folded) {
  for (final clitic in _apostropheClitics) {
    final index = folded.indexOf(clitic);
    if (index < 0) continue;
    final left = folded.substring(0, index);
    final rest = folded.substring(index + clitic.length);
    if (left.isEmpty) {
      if (tutorItalianLexemes.contains(rest)) return _unchangedToken;
      final tails = _tailSplits(rest);
      if (tails.length == 1) {
        final cut = clitic.length + tails.single;
        return _fixed(
          '${token.substring(0, cut)} ${token.substring(cut)}',
          'apostrophe_tail',
        );
      }
      if (tails.length > 1) return _uncertain('ambiguous_apostrophe_tail');
      continue;
    }
    if (!tutorItalianLexemes.contains(left) &&
        !tutorClosedClassWords.contains(left)) {
      continue;
    }
    if (tutorItalianLexemes.contains(rest)) {
      return _fixed(
        '${token.substring(0, index)} ${token.substring(index)}',
        'apostrophe_prefix',
      );
    }
    final tails = _tailSplits(rest);
    if (tails.length == 1) {
      final cut = index + clitic.length + tails.single;
      return _fixed(
        '${token.substring(0, index)} ${token.substring(index, cut)} ${token.substring(cut)}',
        'apostrophe_tail',
      );
    }
    if (tails.length > 1) return _uncertain('ambiguous_apostrophe_tail');
  }
  return null;
}

List<int> _tailSplits(String rest) {
  final hits = <int>[];
  for (var index = 3; index < rest.length - 1; index++) {
    final left = rest.substring(0, index);
    final right = rest.substring(index);
    if (tutorItalianLexemes.contains(left) &&
        tutorClosedClassWords.contains(right) &&
        right.length >= 2) {
      hits.add(index);
    }
  }
  return hits;
}

bool _unresolvedClosedBoundary(String folded) {
  if (_isLexeme(folded) || folded.contains("'")) return false;
  for (final closed in _longClosed) {
    final index = folded.indexOf(closed);
    if (index < 0) continue;
    final before = index;
    final after = folded.length - (index + closed.length);
    if (before >= 4 && after >= 3) return true;
    if (before == 0 &&
        after >= 4 &&
        !_isLexeme(folded.substring(closed.length))) {
      return true;
    }
    if (after == 0 && before >= 4 && !_isLexeme(folded.substring(0, before))) {
      return true;
    }
  }
  return false;
}

String _repairLongestClosedSuffix(String text) {
  return text.replaceAllMapped(_letterRun, (match) {
    final token = match.group(0)!;
    final folded = _fold(token);
    for (final suffix in _closedSuffixesLongestFirst) {
      if (!folded.endsWith(suffix)) continue;
      final stemLength = token.length - suffix.length;
      if (stemLength < 6) continue;
      return '${token.substring(0, stemLength)} ${token.substring(stemLength)}';
    }
    return token;
  });
}

String _repairUnknownJoins(String text) {
  return text.replaceAllMapped(_spacingToken, (match) {
    final decision = _decideToken(match.group(0)!);
    if (decision.action != _SpacingAction.fixed) return match.group(0)!;
    return decision.replacement;
  });
}

String? _joinSplitWord(String left, String right) {
  final foldedLeft = _fold(left);
  if (foldedLeft.length < 5) return null;
  if (tutorItalianLexemes.contains(foldedLeft) ||
      tutorClosedClassWords.contains(foldedLeft)) {
    return null;
  }
  final joined = _fold('$left$right');
  if (!tutorItalianLexemes.contains(joined)) return null;
  return '$left$right';
}

String _repairSplitWords(String text) {
  return text.replaceAllMapped(_splitWord, (match) {
    final joined = _joinSplitWord(match.group(1)!, match.group(2)!);
    return joined ?? match.group(0)!;
  });
}

String _context(String text, int start, int end) {
  final left = start < 24 ? 0 : start - 24;
  final right = end + 24 > text.length ? text.length : end + 24;
  return text.substring(left, right).replaceAll('\n', ' ');
}
