/// Guard di startup web/PWA: distingue route Flutter stale da recovery Auth reale.
///
/// Caso tipico: hash Flutter `#/forgot-password` residuo da una sessione
/// precedente. Non è un flusso Auth recovery.
///
/// Limitazione documentata: l’app **non** implementa una schermata dedicata
/// “imposta nuova password” dopo il link email. I payload Supabase reali
/// (`access_token` / `type=recovery` / `code` in hash o query) vengono
/// lasciati intatti così `supabase_flutter` può recuperarli; non inventiamo
/// un flow UI nuovo.
///
/// La normalizzazione runtime avviene in `web/index.html` *prima* del bootstrap
/// Flutter (history.replaceState). Questo modulo espone la stessa logica in
/// forma testabile.
library;

/// True se hash/query contengono un payload Auth/recovery reale.
bool hasRealAuthRecoveryPayload({
  required String hash,
  required String search,
}) {
  final blob = '$hash&$search';
  return RegExp(
    r'(?:^|[&#?])(?:access_token|refresh_token|type=recovery|type%3Drecovery|code)=',
    caseSensitive: false,
  ).hasMatch(blob);
}

/// True se il fragment è la named route Flutter forgot-password (stale).
bool isStaleForgotPasswordFragment(String hash) {
  final h = hash.startsWith('#') ? hash.substring(1) : hash;
  return RegExp(
    r'^/?forgot-password/?(\?.*)?$',
    caseSensitive: false,
  ).hasMatch(h);
}

/// True se il pathname è `/forgot-password` (path URL strategy).
bool isStaleForgotPasswordPath(String path) {
  return RegExp(r'/forgot-password/?$', caseSensitive: false).hasMatch(path);
}

/// Calcola l’URL di replace per un cold start stale, o `null` se non agire.
///
/// Usato dai test e allineato allo script in `web/index.html`.
String? resolvedCleanStartupLocation({
  required String hash,
  required String search,
  required String pathname,
}) {
  if (hasRealAuthRecoveryPayload(hash: hash, search: search)) {
    return null;
  }

  final fragmentLooksStale = isStaleForgotPasswordFragment(hash);
  final pathLooksStale = isStaleForgotPasswordPath(pathname);
  if (!fragmentLooksStale && !pathLooksStale) {
    return null;
  }

  final cleanPath = pathLooksStale
      ? pathname.replaceFirst(
          RegExp(r'/forgot-password/?$', caseSensitive: false),
          '/',
        )
      : pathname;
  final normalizedPath = cleanPath.isEmpty ? '/' : cleanPath;
  return search.isEmpty ? normalizedPath : '$normalizedPath?$search';
}
