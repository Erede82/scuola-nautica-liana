/// Paginazione client-side per SELECT PostgREST/Supabase.
///
/// Supabase applica un tetto silenzioso ([defaultMaxRows], tipicamente 1000):
/// senza `.range()` una query può restituire un sottoinsieme senza errore.
/// Si pagina finché un batch è più corto di [pageSize].
const int kSupabaseDefaultMaxRows = 1000;

/// Dimensione pagina sotto il tetto di default, con margine per join pesanti.
const int kSupabaseSelectPageSize = 500;

/// Scarica tutte le pagine di un SELECT filtrato.
///
/// [fetchPage] riceve indici **inclusivi** `from`/`to` come in `.range(from, to)`.
/// Il chiamante deve ordinare in modo stabile prima del range.
Future<List<dynamic>> fetchAllSupabasePages(
  Future<dynamic> Function(int from, int to) fetchPage, {
  int pageSize = kSupabaseSelectPageSize,
}) async {
  if (pageSize < 1) {
    throw ArgumentError.value(pageSize, 'pageSize', 'must be >= 1');
  }
  if (pageSize > kSupabaseDefaultMaxRows) {
    throw ArgumentError.value(
      pageSize,
      'pageSize',
      'must be <= $kSupabaseDefaultMaxRows (PostgREST silent cap)',
    );
  }

  final all = <dynamic>[];
  var from = 0;
  while (true) {
    final to = from + pageSize - 1;
    final res = await fetchPage(from, to);
    final batch = res as List<dynamic>;
    all.addAll(batch);
    if (batch.length < pageSize) break;
    from += pageSize;
  }
  return all;
}
