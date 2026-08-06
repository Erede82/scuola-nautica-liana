import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/data/license_catalog.dart';
import 'package:scuola_nautica_liana/data/supabase/quiz_attempt_history_data_source.dart';
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

  group('PostgREST truncation regression (schede lezione)', () {
    test('catalogo motore × 20 risposte supera max-rows senza paginazione', () {
      final sheetCount = LicenseCatalog.patenteMotore.lessons
          .map((l) => l.quizSheets)
          .fold<int>(0, (sum, n) => sum + n);
      // Un passaggio completo del percorso: già oltre 1000 risposte.
      final answersOnePass = sheetCount * 20;
      expect(sheetCount, greaterThan(300));
      expect(answersOnePass, greaterThan(kSupabaseDefaultMaxRows));

      // Chunk storico da 100 result id × 20 risposte = 2000 > 1000.
      final answersPerLegacyChunk =
          QuizAttemptHistoryDataSourceSupabase.answerCountInChunkSize * 20;
      expect(answersPerLegacyChunk, greaterThan(kSupabaseDefaultMaxRows));
    });

    test('lezione 7 (36 schede) × 2 tentativi tronca senza paginazione', () {
      const sheets = 36;
      const attemptsPerSheet = 2;
      const answersPerSheet = 20;
      const answers = sheets * attemptsPerSheet * answersPerSheet;
      expect(answers, greaterThan(kSupabaseDefaultMaxRows));
    });

    test('data source Supabase pagina risultati e conteggi risposte', () {
      final source = File(
        'lib/data/supabase/quiz_attempt_history_data_source.dart',
      ).readAsStringSync();
      final completion = File(
        'lib/repositories/student_quiz_repository.dart',
      ).readAsStringSync();

      expect(source, contains('fetchAllSupabasePages'));
      expect(source, contains('.range(from, to)'));
      expect(source, contains(".order('id'"));
      expect(source, contains(".eq('user_id', userId)"));

      expect(completion, contains('fetchAllSupabasePages'));
      expect(completion, contains('fetchAnswerCountsByResultIds'));
      expect(completion, isNot(contains(".select('quiz_result_id')")));
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
