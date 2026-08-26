/// Guard di startup web/PWA: root Flutter canonica `/#/` e route stale.
///
/// Comportamenti (allineati a `web/index.html`, prima di `flutter_bootstrap.js`):
/// - `/` → `/#/`
/// - `/?foo=bar` → `/?foo=bar#/`
/// - `/#/forgot-password` (senza recovery) → `/#/`
/// - `/#/`, `/#/login`, `/#/register` → no-op (idempotente)
///
/// Limitazione documentata: l’app **non** implementa una schermata dedicata
/// “imposta nuova password” dopo il link email. I payload Supabase reali
/// (`access_token` / `type=recovery` / `code` in hash o query) vengono
/// lasciati intatti così `supabase_flutter` può recuperarli.
library;

/// Root hash Flutter dopo normalizzazione.
const String flutterHashRoot = '#/';

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

bool _isHashEmpty(String hash) => hash.isEmpty || hash == '#';

bool _isAppRootPath(String pathname) =>
    pathname.isEmpty || pathname == '/';

/// Calcola l’URL di replace per cold start, o `null` se non agire.
///
/// Flutter Web usa hash routing: la root canonica è `/#/`, non `/`.
String? resolvedCleanStartupLocation({
  required String hash,
  required String search,
  required String pathname,
}) {
  if (hasRealAuthRecoveryPayload(hash: hash, search: search)) {
    return null;
  }

  final query = search.isEmpty ? '' : search;
  final fragmentLooksStale = isStaleForgotPasswordFragment(hash);
  final pathLooksStale = isStaleForgotPasswordPath(pathname);

  if (fragmentLooksStale || pathLooksStale) {
    final cleanPath = pathLooksStale
        ? pathname.replaceFirst(
            RegExp(r'/forgot-password/?$', caseSensitive: false),
            '/',
          )
        : pathname;
    final normalizedPath = cleanPath.isEmpty ? '/' : cleanPath;
    return '$normalizedPath$query$flutterHashRoot';
  }

  // Root hashless → `/#/` (idempotente: `/#/` ha hash non vuoto → no-op).
  if (_isAppRootPath(pathname) && _isHashEmpty(hash)) {
    final normalizedPath = pathname.isEmpty ? '/' : pathname;
    return '$normalizedPath$query$flutterHashRoot';
  }

  return null;
}
