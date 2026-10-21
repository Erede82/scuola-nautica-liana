import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/data/supabase/supabase_select_pagination.dart';
import 'package:scuola_nautica_liana/domain/exam_quiz_rules.dart';
import 'package:scuola_nautica_liana/domain/lesson_quiz_rules.dart';

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

    test('si ferma sulla prima pagina corta', () async {
      final all = await fetchAllSupabasePages((from, to) async {
        expect(from, 0);
        return [1, 2, 3];
      });
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

  test('le letture statistiche paginano sotto il tetto PostgREST', () {
    final source = File(
      'lib/data/supabase/student_quiz_statistics_data_source.dart',
    ).readAsStringSync();

    expect(source, contains('fetchAllSupabasePages'));
    expect(source, contains(".range(from, to)"));
    expect(source, contains(".order('id')"));
    expect('fetchAllSupabasePages'.allMatches(source).length, greaterThanOrEqualTo(5));

    // A12: 51 schede × 20 risposte = 1020 > 1000. Una sola IN senza range
    // tronca e il repository scarta le schede il cui conteggio non torna.
    final answersAtTrigger =
        51 * LessonQuizRules.a12.questionsPerSheet;
    expect(answersAtTrigger, greaterThan(kSupabaseDefaultMaxRows));
    expect(
      100 * LessonQuizRules.a12.questionsPerSheet,
      greaterThan(kSupabaseDefaultMaxRows),
    );
    expect(
      51 * ExamQuizRules.questionCount,
      greaterThan(kSupabaseDefaultMaxRows),
    );
  });
}
