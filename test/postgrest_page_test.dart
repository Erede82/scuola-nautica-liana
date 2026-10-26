import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/data/supabase/postgrest_page.dart';

void main() {
  test('a full page is not the end of the result', () async {
    final rows = [
      for (var i = 0; i < 1000; i++) {'id': 'r$i'},
    ];
    final ranges = <List<int>>[];
    final collected = await collectPostgrestPages(
      pageSize: postgrestReadPageSize,
      fetchPage: (from, to) async {
        ranges.add([from, to]);
        return _slice(rows, from, to);
      },
    );
    expect(ranges, [
      [0, 999],
      [1000, 1999],
    ]);
    expect(collected, hasLength(1000));
    expect(collected.map((row) => row['id']).toSet(), hasLength(1000));
  });

  test('row 1001 is included', () async {
    final rows = [
      for (var i = 0; i < 1001; i++) {'id': 'r$i'},
    ];
    final collected = await collectPostgrestPages(
      pageSize: 1000,
      fetchPage: (from, to) async => _slice(rows, from, to),
    );
    expect(collected, hasLength(1001));
    expect(collected.last['id'], 'r1000');
  });

  test('three pages are collected without duplicates', () async {
    final rows = [
      for (var i = 0; i < 2500; i++) {'id': 'r$i'},
    ];
    var calls = 0;
    final collected = await collectPostgrestPages(
      pageSize: 1000,
      fetchPage: (from, to) async {
        calls++;
        return _slice(rows, from, to);
      },
    );
    expect(calls, 3);
    expect(collected, hasLength(2500));
    expect(collected.map((row) => row['id']).toSet(), hasLength(2500));
    expect(collected.first['id'], 'r0');
    expect(collected.last['id'], 'r2499');
  });

  test('a later page failure does not return a partial list', () async {
    var calls = 0;
    await expectLater(
      collectPostgrestPages(
        pageSize: 2,
        fetchPage: (from, to) async {
          calls++;
          if (calls == 2) throw StateError('page failed');
          return [
            {'id': 'a'},
            {'id': 'b'},
          ];
        },
      ),
      throwsA(isA<StateError>()),
    );
    expect(calls, 2);
  });
}

List<Map<String, dynamic>> _slice(
  List<Map<String, dynamic>> rows,
  int from,
  int to,
) {
  if (from >= rows.length) return const [];
  final end = to + 1 > rows.length ? rows.length : to + 1;
  return rows.sublist(from, end);
}
