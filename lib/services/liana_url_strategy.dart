import 'liana_url_strategy_stub.dart'
    if (dart.library.html) 'liana_url_strategy_web.dart' as impl;

/// Configura la URL strategy Liana (web: root sempre `/#/`; altrimenti no-op).
///
/// Da chiamare **prima** di [runApp].
void configureLianaUrlStrategy() => impl.configureLianaUrlStrategy();

/// Serializzazione hash URL Liana (pura, testabile senza browser).
///
/// Differisce da [HashUrlStrategy] solo per la root:
/// - `""` / `"/"` → `pathname + search + "#/"`
/// - altre route → comportamento hash standard (`#/login`, …)
String prepareLianaHashExternalUrl({
  required String internalUrl,
  required String pathname,
  required String search,
}) {
  if (internalUrl.isEmpty || internalUrl == '/') {
    return '$pathname$search#/';
  }
  return '$pathname$search#$internalUrl';
}
