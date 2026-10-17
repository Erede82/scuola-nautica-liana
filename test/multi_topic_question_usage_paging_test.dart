import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/multi_topic_question_history_usage.dart';

void main() {
  test('51 schede A12 superano una pagina PostgREST non paginata', () {
    const sheets = 51;
    final rows = sheets * multiTopicMaxAnswersPerAttempt;
    expect(rows, 1020);
    expect(rows, greaterThan(multiTopicQuestionUsagePageSize));
  });

  test('chunk attempt resta sotto il cap di riga', () {
    expect(multiTopicQuestionUsageAttemptChunkSize, 49);
    expect(
      multiTopicQuestionUsageAttemptChunkSize * multiTopicMaxAnswersPerAttempt,
      lessThan(multiTopicQuestionUsagePageSize),
    );
    expect(multiTopicQuestionUsageMaxPages, greaterThan(1));
  });

  test('finestre range inclusive e consecutive', () {
    expect(multiTopicUsagePageRange(pageIndex: 0), (from: 0, to: 999));
    expect(multiTopicUsagePageRange(pageIndex: 1), (from: 1000, to: 1999));
    final first = multiTopicUsagePageRange(pageIndex: 0);
    final second = multiTopicUsagePageRange(pageIndex: 1);
    expect(second.from, first.to + 1);
    expect(
      () => multiTopicUsagePageRange(pageIndex: -1),
      throwsArgumentError,
    );
  });

  test('fetch usage pagina attempt e answers per id', () {
    final source = File(
      'lib/repositories/multi_topic_quiz_attempt_repository.dart',
    ).readAsStringSync();
    final method = source
        .split(
          'Future<MultiTopicQuestionHistoryUsage> fetchCurrentUserQuestionUsage',
        )
        .last
        .split('Future<MultiTopicQuizAttemptDetail> fetchAttemptDetail')
        .first;
    expect(method, contains('_fetchUsagePages'));
    expect(method, contains(".order('id')"));
    expect(method, contains('.range(from, to)'));
    expect(method, contains('multiTopicQuestionUsageAttemptChunkSize'));
    expect('.range(from, to)'.allMatches(method), hasLength(2));

    final helper = source
        .split('Future<List<dynamic>> _fetchUsagePages')
        .last
        .split('@override')
        .first;
    expect(helper, contains('multiTopicUsagePageRange'));
    expect(
      helper,
      contains('pageRows.length < multiTopicQuestionUsagePageSize'),
    );
    expect(helper, contains('MultiTopicQuizAttemptException'));
  });
}
