import 'package:flutter_web_plugins/url_strategy.dart';

import 'liana_url_strategy.dart';

/// Hash URL strategy che serializza la root Flutter come `/#/` (non `/`).
///
/// Tutti gli altri metodi restano quelli di [HashUrlStrategy].
class LianaHashUrlStrategy extends HashUrlStrategy {
  /// [platformLocation] utile nei test per mockare pathname/search.
  LianaHashUrlStrategy([super.platformLocation])
      : _platformLocation = platformLocation ?? BrowserPlatformLocation();

  final PlatformLocation _platformLocation;

  @override
  String prepareExternalUrl(String internalUrl) {
    return prepareLianaHashExternalUrl(
      internalUrl: internalUrl,
      pathname: _platformLocation.pathname,
      search: _platformLocation.search,
    );
  }
}

void configureLianaUrlStrategy() {
  setUrlStrategy(LianaHashUrlStrategy());
}
