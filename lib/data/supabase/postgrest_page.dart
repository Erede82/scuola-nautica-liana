/// PostgREST Data API default max rows. The client must page even if this
/// stays at 1000.
const int postgrestReadPageSize = 1000;

/// Reads every row from an ordered PostgREST query.
///
/// [fetchPage] receives an inclusive range. A full page is not treated as
/// the end of the result: the next page is always requested. A later page
/// error propagates and does not return a shorter list.
Future<List<Map<String, dynamic>>> collectPostgrestPages({
  required Future<List<dynamic>> Function(int fromInclusive, int toInclusive)
  fetchPage,
  int pageSize = postgrestReadPageSize,
}) async {
  if (pageSize < 1) {
    throw ArgumentError.value(pageSize, 'pageSize');
  }
  final rows = <Map<String, dynamic>>[];
  var offset = 0;
  while (true) {
    final page = await fetchPage(offset, offset + pageSize - 1);
    if (page.length > pageSize) {
      throw StateError(
        'PostgREST page returned ${page.length} rows; requested at most $pageSize.',
      );
    }
    for (final item in page) {
      if (item is! Map) continue;
      rows.add(Map<String, dynamic>.from(item));
    }
    if (page.length < pageSize) return rows;
    offset += pageSize;
  }
}
