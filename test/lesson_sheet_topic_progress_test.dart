import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/student_quiz_statistics_aggregator.dart';
import 'package:scuola_nautica_liana/domain/student_quiz_statistics_models.dart';
import 'package:scuola_nautica_liana/domain/student_stats_source.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';

StudentStatsAnswerEvent _seen(int lesson) => StudentStatsAnswerEvent(
  source: StudentStatsSource.study,
  lessonNumber: lesson,
  isCorrect: true,
  isUnanswered: false,
  completedAt: DateTime.utc(2026, 10, 23, 10),
);

void main() {
  const lesson = 2;
  final catalogIds = [for (var i = 1; i <= 15; i++) 'sheet-$i'];

  StudentQuizStatistics build({
    required List<StudentStatsCompletedLessonSheet> completed,
    List<StudentStatsAnswerEvent> extraAnswers = const [],
  }) {
    return buildStudentQuizStatistics(
      categoryId: LicenseCategoryId.motore,
      studySheets: const [],
      examAttempts: const [],
      answerEvents: [_seen(lesson), ...extraAnswers],
      catalog: [
        StudentStatsTopicCatalogEntry(
          lessonNumber: lesson,
          title: 'COLREGs 2',
          lessonSheetIds: catalogIds,
        ),
      ],
      completedLessonSheets: completed,
    );
  }

  TopicStatistics topicOf(StudentQuizStatistics stats) =>
      stats.topicsStudy.single;

  test('2 unique of 15 with duplicates → 2/15 and 13%', () {
    final stats = build(
      completed: [
        const StudentStatsCompletedLessonSheet(
          quizSetId: 'sheet-5',
          lessonNumber: lesson,
        ),
        const StudentStatsCompletedLessonSheet(
          quizSetId: 'sheet-5',
          lessonNumber: lesson,
        ),
        const StudentStatsCompletedLessonSheet(
          quizSetId: 'sheet-5',
          lessonNumber: lesson,
        ),
        const StudentStatsCompletedLessonSheet(
          quizSetId: 'sheet-8',
          lessonNumber: lesson,
        ),
      ],
    );
    final topic = topicOf(stats);
    expect(topic.lessonSheetsCompleted, 2);
    expect(topic.lessonSheetsTotal, 15);
    expect(topic.lessonSheetProgressPercent, 13);
  });

  test('15/15 stays 100% when attempts repeat', () {
    final stats = build(
      completed: [
        for (final id in catalogIds) ...[
          StudentStatsCompletedLessonSheet(quizSetId: id, lessonNumber: lesson),
          StudentStatsCompletedLessonSheet(quizSetId: id, lessonNumber: lesson),
        ],
      ],
    );
    final topic = topicOf(stats);
    expect(topic.lessonSheetsCompleted, 15);
    expect(topic.lessonSheetsTotal, 15);
    expect(topic.lessonSheetProgressPercent, 100);
  });

  test('sheet not in the completed set does not count', () {
    final stats = build(
      completed: const [
        StudentStatsCompletedLessonSheet(
          quizSetId: 'sheet-1',
          lessonNumber: lesson,
        ),
      ],
    );
    expect(topicOf(stats).lessonSheetsCompleted, 1);
    expect(topicOf(stats).lessonSheetProgressPercent, 7);
  });

  test('ids outside the topic catalog do not inflate progress', () {
    final stats = build(
      completed: const [
        StudentStatsCompletedLessonSheet(
          quizSetId: 'sheet-1',
          lessonNumber: lesson,
        ),
        StudentStatsCompletedLessonSheet(
          quizSetId: 'assigned-or-other',
          lessonNumber: lesson,
        ),
        StudentStatsCompletedLessonSheet(
          quizSetId: 'sheet-1',
          lessonNumber: 99,
        ),
      ],
    );
    expect(topicOf(stats).lessonSheetsCompleted, 1);
    expect(topicOf(stats).lessonSheetsTotal, 15);
  });

  test('multi answer events do not change lesson sheet progress', () {
    final completed = const [
      StudentStatsCompletedLessonSheet(
        quizSetId: 'sheet-1',
        lessonNumber: lesson,
      ),
    ];
    final withoutMulti = build(completed: completed);
    final withMulti = build(
      completed: completed,
      extraAnswers: [
        for (var i = 0; i < 20; i++)
          StudentStatsAnswerEvent(
            source: StudentStatsSource.study,
            lessonNumber: lesson,
            isCorrect: false,
            isUnanswered: false,
            completedAt: DateTime.utc(2026, 10, 23, 12),
          ),
      ],
    );
    expect(topicOf(withMulti).lessonSheetsCompleted, 1);
    expect(
      topicOf(withMulti).lessonSheetsCompleted,
      topicOf(withoutMulti).lessonSheetsCompleted,
    );
    expect(
      topicOf(withMulti).accuracyPercentage,
      isNot(topicOf(withoutMulti).accuracyPercentage),
    );
  });

  test('zero catalog sheets → no progress percent', () {
    final stats = buildStudentQuizStatistics(
      categoryId: LicenseCategoryId.motore,
      studySheets: const [],
      examAttempts: const [],
      answerEvents: [_seen(lesson)],
      catalog: const [
        StudentStatsTopicCatalogEntry(
          lessonNumber: lesson,
          title: 'COLREGs 2',
        ),
      ],
      completedLessonSheets: const [
        StudentStatsCompletedLessonSheet(
          quizSetId: 'sheet-1',
          lessonNumber: lesson,
        ),
      ],
    );
    expect(topicOf(stats).lessonSheetsTotal, 0);
    expect(topicOf(stats).lessonSheetsCompleted, 0);
    expect(topicOf(stats).lessonSheetProgressPercent, isNull);
  });
}
