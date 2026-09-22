import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/data/supabase/supabase_select_pagination.dart';

void main() {
  group('fetchAllSupabasePages', () {
    test('aggrega più pagine finché il batch è corto', () async {
      final calls = <(int, int)>[];
      final pages = <int, List<int>>{
        0: List.generate(kSupabaseSelectPageSize, (i) => i),
        kSupabaseSelectPageSize: List.generate(
          kSupabaseSelectPageSize,
          (i) => kSupabaseSelectPageSize + i,
        ),
        kSupabaseSelectPageSize * 2: List.generate(17, (i) => 1000 + i),
      };

      final all = await fetchAllSupabasePages((from, to) async {
        calls.add((from, to));
        expect(to - from + 1, kSupabaseSelectPageSize);
        return pages[from] ?? <int>[];
      });

      expect(calls, [
        (0, kSupabaseSelectPageSize - 1),
        (kSupabaseSelectPageSize, kSupabaseSelectPageSize * 2 - 1),
        (kSupabaseSelectPageSize * 2, kSupabaseSelectPageSize * 3 - 1),
      ]);
      expect(all.length, kSupabaseSelectPageSize * 2 + 17);
      expect(all.first, 0);
      expect(all.last, 1016);
    });

    test('singola pagina corta termina subito', () async {
      var calls = 0;
      final all = await fetchAllSupabasePages((from, to) async {
        calls += 1;
        return <int>[1, 2, 3];
      });
      expect(calls, 1);
      expect(all, [1, 2, 3]);
    });

    test('rifiuta pageSize sopra il tetto PostgREST di default', () {
      expect(
        () => fetchAllSupabasePages(
          (from, to) async => <int>[],
          pageSize: kSupabaseDefaultMaxRows + 1,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('PostgREST truncation regression (Directory pratiche)', () {
    test(
      'pacchetti documenti new_license × ~200 allievi superano max-rows',
      () {
        // new_license checklist: 4 documenti file (+ foto patente).
        // Con ≥5 righe medie/allievo (re-upload), 201 × 5 = 1005 > 1000.
        const fileDocSlotsNewLicense = 4;
        const docsPerStudentConservative = 5;
        expect(fileDocSlotsNewLicense, greaterThanOrEqualTo(4));

        const studentsAtCap =
            (kSupabaseDefaultMaxRows ~/ docsPerStudentConservative) + 1;
        expect(
          studentsAtCap * docsPerStudentConservative,
          greaterThan(kSupabaseDefaultMaxRows),
        );
        // Soglia operativa ben sotto le 1000 pratiche (1 dossier/allievo).
        expect(studentsAtCap, lessThan(kSupabaseDefaultMaxRows));
      },
    );

    test('listPracticeDossiers pagina documenti/foto/dossier', () {
      final source = File(
        'lib/repositories/backoffice/backoffice_repository_supabase.dart',
      ).readAsStringSync();

      expect(source, contains('fetchAllSupabasePages'));
      expect(source, contains('supabase_select_pagination.dart'));

      final docsLoaderStart = source.indexOf(
        'Future<Map<String, List<StudentDocument>>> _loadStudentDocumentsByStudentIds',
      );
      expect(docsLoaderStart, greaterThan(0));
      final docsLoaderEnd = source.indexOf(
        'Future<Map<String, List<StudentPhoto>>> _loadStudentPhotosByStudentIds',
        docsLoaderStart + 1,
      );
      final docsLoader = source.substring(docsLoaderStart, docsLoaderEnd);
      expect(docsLoader, contains('fetchAllSupabasePages'));
      expect(docsLoader, contains('.range(from, to)'));
      expect(docsLoader, contains(".order('id', ascending: true)"));
      expect(
        docsLoader.contains(".inFilter('student_id', studentIds);"),
        isFalse,
        reason: 'Document batch must not end after inFilter without range',
      );

      final photosLoaderStart = docsLoaderEnd;
      final photosLoaderEnd = source.indexOf(
        'Future<List<GuidanceListItem>> listGuidanceAppointments',
        photosLoaderStart + 1,
      );
      final photosLoader = source.substring(photosLoaderStart, photosLoaderEnd);
      expect(photosLoader, contains('fetchAllSupabasePages'));
      expect(photosLoader, contains('.range(from, to)'));
    });

    test('pageSize resta sotto il tetto silenzioso di default', () {
      expect(
        kSupabaseSelectPageSize,
        lessThanOrEqualTo(kSupabaseDefaultMaxRows),
      );
      expect(kSupabaseSelectPageSize, greaterThan(0));
    });
  });
}
