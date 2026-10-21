import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/student_quiz_statistics_aggregator.dart';
import 'package:scuola_nautica_liana/domain/student_quiz_statistics_models.dart';
import 'package:scuola_nautica_liana/domain/student_stats_source.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';

void main() {
  final catalog = [
    for (var i = 1; i <= 14; i++)
      StudentStatsTopicCatalogEntry(lessonNumber: i, title: 'Lezione $i'),
  ];

  final catalogD1Ten = [
    for (var i = 1; i <= 10; i++)
      StudentStatsTopicCatalogEntry(lessonNumber: i, title: 'D1 L$i'),
  ];

  group('accuracy & unanswered', () {
    test('A. accuracy = correct / total_seen', () {
      expect(
        studentStatsAccuracy(correct: 7, wrong: 2, unanswered: 1),
        0.7,
      );
    });

    test('B. unanswered counts as error', () {
      expect(
        studentStatsErrorCount(wrong: 2, unanswered: 3),
        5,
      );
    });

    test('C. zero seen → accuracy 0', () {
      expect(
        studentStatsAccuracy(correct: 0, wrong: 0, unanswered: 0),
        0,
      );
    });
  });

  group('source aggregation', () {
    test('D/E/F. Studio = normal+multi; Exam separate; All union', () {
      final at = DateTime.utc(2026, 10, 1);
      final stats = buildStudentQuizStatistics(
        categoryId: LicenseCategoryId.motore,
        studySheets: [
          StudentStatsSheetEvent(
            completedAt: at,
            correct: 10,
            wrong: 5,
            unanswered: 5,
          ),
          StudentStatsSheetEvent(
            completedAt: at,
            correct: 8,
            wrong: 2,
            unanswered: 0,
          ),
        ],
        examAttempts: [
          StudentStatsExamAttemptEvent(
            attemptId: 'e1',
            completedAt: at,
            passed: true,
            correct: 18,
            wrong: 1,
            unanswered: 1,
          ),
        ],
        answerEvents: [
          for (var i = 0; i < 10; i++)
            StudentStatsAnswerEvent(
              source: StudentStatsSource.study,
              lessonNumber: 1,
              isCorrect: true,
              isUnanswered: false,
              completedAt: at,
            ),
          for (var i = 0; i < 5; i++)
            StudentStatsAnswerEvent(
              source: StudentStatsSource.study,
              lessonNumber: 1,
              isCorrect: false,
              isUnanswered: false,
              completedAt: at,
            ),
          for (var i = 0; i < 5; i++)
            StudentStatsAnswerEvent(
              source: StudentStatsSource.study,
              lessonNumber: 1,
              isCorrect: false,
              isUnanswered: true,
              completedAt: at,
            ),
          for (var i = 0; i < 8; i++)
            StudentStatsAnswerEvent(
              source: StudentStatsSource.study,
              lessonNumber: 2,
              isCorrect: true,
              isUnanswered: false,
              completedAt: at,
            ),
          for (var i = 0; i < 2; i++)
            StudentStatsAnswerEvent(
              source: StudentStatsSource.study,
              lessonNumber: 2,
              isCorrect: false,
              isUnanswered: false,
              completedAt: at,
            ),
          for (var i = 0; i < 15; i++)
            StudentStatsAnswerEvent(
              source: StudentStatsSource.exam,
              lessonNumber: 3,
              isCorrect: true,
              isUnanswered: false,
              completedAt: at,
            ),
          for (var i = 0; i < 5; i++)
            StudentStatsAnswerEvent(
              source: StudentStatsSource.exam,
              lessonNumber: 3,
              isCorrect: false,
              isUnanswered: false,
              completedAt: at,
            ),
        ],
        catalog: catalog,
      );

      expect(stats.study.sheetsCompleted, 2);
      expect(stats.study.correct, 18);
      expect(stats.study.wrong, 7);
      expect(stats.study.unanswered, 5);
      expect(stats.exam.simulationsCount, 1);
      expect(stats.exam.passedCount, 1);

      expect(stats.topicsStudy.map((t) => t.lessonNumber), [1, 2]);
      expect(stats.topicsExam.map((t) => t.lessonNumber), [3]);
      expect(stats.topicsAll.map((t) => t.lessonNumber), [1, 2, 3]);
    });
  });

  group('Top 3 Laplace', () {
    TopicStatistics topic({
      required int n,
      required int correct,
      required int wrong,
      required int unanswered,
      DateTime? last,
    }) {
      return TopicStatistics(
        lessonNumber: n,
        title: 'L$n',
        counts: TopicAnswerCounts(
          correct: correct,
          wrong: wrong,
          unanswered: unanswered,
          lastActivity: last ?? DateTime.utc(2026, 1, n),
        ),
      );
    }

    test('G. Laplace score (errors+1)/(seen+2)', () {
      expect(
        studentStatsLaplaceErrorScore(errors: 3, seen: 8),
        (3 + 1) / (8 + 2),
      );
    });

    test('H. primary min sample >= 8; seen < 5 never eligible', () {
      final review = selectStudentStatsReviewTopics([
        topic(n: 1, correct: 1, wrong: 3, unanswered: 0), // seen 4 < 5
        topic(n: 2, correct: 2, wrong: 6, unanswered: 0), // seen 8
      ]);
      expect(review.map((r) => r.topic.lessonNumber), [2]);
    });

    test('I. fallback >= 5 when fewer than limit primary', () {
      final review = selectStudentStatsReviewTopics(
        [
          topic(n: 1, correct: 1, wrong: 7, unanswered: 0), // 8
          topic(n: 2, correct: 1, wrong: 4, unanswered: 0), // 5 fallback
          topic(n: 3, correct: 0, wrong: 4, unanswered: 0), // 4 excluded
        ],
        limit: kStudentStatsTop3Limit,
      );
      expect(review.map((r) => r.topic.lessonNumber).toList(), [1, 2]);
    });

    test('A. 5 eligible → ranked list provides 5', () {
      final review = selectStudentStatsReviewTopics([
        for (var i = 1; i <= 5; i++)
          topic(
            n: i,
            correct: 2,
            wrong: 6 + (5 - i), // distinct laplace / errors
            unanswered: 0,
          ),
      ]);
      expect(review, hasLength(5));
      expect(review.map((r) => r.rank).toList(), [1, 2, 3, 4, 5]);
    });

    test('B. 4 eligible → 4 real (no filler)', () {
      final review = selectStudentStatsReviewTopics([
        for (var i = 1; i <= 4; i++)
          topic(n: i, correct: 2, wrong: 6, unanswered: 0),
      ]);
      expect(review, hasLength(4));
    });

    test('C. 2 eligible → 2 real', () {
      final review = selectStudentStatsReviewTopics([
        topic(n: 1, correct: 2, wrong: 6, unanswered: 0),
        topic(n: 2, correct: 3, wrong: 5, unanswered: 0),
      ]);
      expect(review, hasLength(2));
    });

    test('D. formula/ranking unchanged with limit 5 vs 3 prefix', () {
      final topics = [
        for (var i = 1; i <= 6; i++)
          topic(
            n: i,
            correct: 2,
            wrong: 8 - i,
            unanswered: 0,
            last: DateTime.utc(2026, 1, i),
          ),
      ];
      final top5 = selectStudentStatsReviewTopics(topics);
      final top3 = selectStudentStatsReviewTopics(
        topics,
        limit: kStudentStatsTop3Limit,
      );
      expect(top5.take(3).map((r) => r.topic.lessonNumber).toList(),
          top3.map((r) => r.topic.lessonNumber).toList());
      expect(
        studentStatsLaplaceErrorScore(
          errors: top5.first.topic.errors,
          seen: top5.first.topic.questionsSeen,
        ),
        (top5.first.topic.errors + 1) / (top5.first.topic.questionsSeen + 2),
      );
    });

    test('J. tie-break absolute errors desc', () {
      // same laplace for both: errors 4 seen 8 → (5)/(10)=0.5
      final review = selectStudentStatsReviewTopics([
        topic(n: 1, correct: 4, wrong: 4, unanswered: 0),
        topic(n: 2, correct: 4, wrong: 3, unanswered: 1), // errors still 4
        topic(n: 3, correct: 2, wrong: 6, unanswered: 0), // errors 6 → wins
      ]);
      expect(review.first.topic.lessonNumber, 3);
    });

    test('K. tie-break recency desc after errors', () {
      final older = DateTime.utc(2026, 1, 1);
      final newer = DateTime.utc(2026, 2, 1);
      final review = selectStudentStatsReviewTopics([
        topic(
          n: 1,
          correct: 4,
          wrong: 4,
          unanswered: 0,
          last: older,
        ),
        topic(
          n: 2,
          correct: 4,
          wrong: 4,
          unanswered: 0,
          last: newer,
        ),
      ]);
      expect(review.first.topic.lessonNumber, 2);
    });

    test('empty Top 3 when insufficient data', () {
      final review = selectStudentStatsReviewTopics([
        topic(n: 1, correct: 2, wrong: 1, unanswered: 0), // seen 3
      ]);
      expect(review, isEmpty);
    });
  });

  group('Exam null lesson', () {
    test('L. null lesson excluded from topics but in exam summary', () {
      final at = DateTime.utc(2026, 10, 2);
      final stats = buildStudentQuizStatistics(
        categoryId: LicenseCategoryId.motore,
        studySheets: const [],
        examAttempts: [
          StudentStatsExamAttemptEvent(
            attemptId: 'e1',
            completedAt: at,
            passed: false,
            correct: 10,
            wrong: 5,
            unanswered: 5,
          ),
        ],
        answerEvents: [
          for (var i = 0; i < 10; i++)
            StudentStatsAnswerEvent(
              source: StudentStatsSource.exam,
              lessonNumber: 1,
              isCorrect: true,
              isUnanswered: false,
              completedAt: at,
            ),
          for (var i = 0; i < 10; i++)
            StudentStatsAnswerEvent(
              source: StudentStatsSource.exam,
              lessonNumber: null,
              isCorrect: false,
              isUnanswered: i < 5,
              completedAt: at,
            ),
        ],
        catalog: catalog,
      );

      expect(stats.exam.simulationsCount, 1);
      expect(stats.exam.averageErrors, 10);
      expect(stats.exam.answersExcludedFromTopics, 10);
      expect(stats.topicsExam, hasLength(1));
      expect(stats.topicsExam.single.lessonNumber, 1);
      expect(stats.topicsExam.single.questionsSeen, 10);
    });
  });

  group('recent exam tie-break', () {
    test('same completed_at → attemptId DESC deterministic', () {
      final at = DateTime.utc(2026, 10, 5);
      final stats = buildStudentQuizStatistics(
        categoryId: LicenseCategoryId.motore,
        studySheets: const [],
        examAttempts: [
          StudentStatsExamAttemptEvent(
            attemptId: 'e-aaa',
            completedAt: at,
            passed: true,
            correct: 18,
            wrong: 1,
            unanswered: 1,
          ),
          StudentStatsExamAttemptEvent(
            attemptId: 'e-zzz',
            completedAt: at,
            passed: false,
            correct: 10,
            wrong: 5,
            unanswered: 5,
          ),
        ],
        answerEvents: const [],
        catalog: catalog,
      );
      expect(
        stats.exam.recentResults.map((r) => r.attemptId).toList(),
        ['e-zzz', 'e-aaa'],
      );
    });
  });

  group('catalog denominator', () {
    test('M. D1 denominator from catalog mock, not constant 14', () {
      final stats = buildStudentQuizStatistics(
        categoryId: LicenseCategoryId.d1,
        studySheets: const [],
        examAttempts: const [],
        answerEvents: const [],
        catalog: catalogD1Ten,
      );
      expect(stats.study.topicsTotal, 10);
      expect(stats.study.topicsTotal, isNot(14));
    });

    test('A12 denominator from 14 catalog entries', () {
      final stats = buildStudentQuizStatistics(
        categoryId: LicenseCategoryId.motore,
        studySheets: const [],
        examAttempts: const [],
        answerEvents: const [],
        catalog: catalog,
      );
      expect(stats.study.topicsTotal, 14);
    });
  });
}
