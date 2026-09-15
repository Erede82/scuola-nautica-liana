import 'web_reload_adapter_stub.dart'
    if (dart.library.html) 'web_reload_adapter_web.dart' as impl;

/// Reload PWA preservando hash route e query (no redirect a `/`).
typedef WebReloadAdapter = void Function();

WebReloadAdapter defaultWebReloadAdapter = impl.reloadCurrentPage;
