import 'version_fetcher_stub.dart'
    if (dart.library.html) 'version_fetcher_web.dart' as impl;

import 'remote_app_version.dart';

/// GET `/version.json?t=<epoch>` con cache-bust.
typedef VersionJsonFetcher = Future<String?> Function(String url);

VersionJsonFetcher defaultVersionJsonFetcher = impl.fetchVersionJsonBody;

Future<RemoteAppVersion?> fetchRemoteAppVersion({
  required VersionJsonFetcher fetcher,
  required int cacheBustEpochMs,
  String path = '/version.json',
}) async {
  final url = '$path?t=$cacheBustEpochMs';
  try {
    final body = await fetcher(url);
    if (body == null) return null;
    return RemoteAppVersion.tryParse(body);
  } catch (_) {
    return null;
  }
}
