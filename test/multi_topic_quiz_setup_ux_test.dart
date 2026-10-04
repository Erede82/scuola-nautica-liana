import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/models/lesson_quiz_sheet_content.dart';
import 'package:scuola_nautica_liana/models/lesson_sheet_completion_snapshot.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';
import 'package:scuola_nautica_liana/models/quiz_question.dart';
import 'package:scuola_nautica_liana/domain/multi_topic_question_history_usage.dart';
import 'package:scuola_nautica_liana/domain/multi_topic_quiz_attempt_exception.dart';
import 'package:scuola_nautica_liana/domain/multi_topic_quiz_attempt_result.dart';
import 'package:scuola_nautica_liana/domain/multi_topic_quiz_history_models.dart';
import 'package:scuola_nautica_liana/pages/multi_topic_quiz_player_page.dart';
import 'package:scuola_nautica_liana/pages/multi_topic_quiz_setup_page.dart';
import 'package:scuola_nautica_liana/repositories/multi_topic_quiz_attempt_repository.dart';
import 'package:scuola_nautica_liana/repositories/student_quiz_repository.dart';
import 'package:scuola_nautica_liana/repositories/study_access_repository.dart';

QuizQuestion _q(String id, {required int lesson}) => QuizQuestion(
  id: id,
  prompt: 'Prompt $id',
  optionA: 'A',
  optionB: 'B',
  optionC: 'C',
  correctOption: QuizAnswerOption.a,
  lessonNumber: lesson,
  licenseCategory: 'A12',
);

class _FakeQuizRepo implements StudentQuizRepository {
  _FakeQuizRepo({
    required this.sheetNumbersByLesson,
    required this.poolByLesson,
    this.throwOnSheetNumbers = false,
  });

  final Map<int, List<int>> sheetNumbersByLesson;
  final Map<int, List<QuizQuestion>> poolByLesson;
  final bool throwOnSheetNumbers;

  @override
  Future<LessonQuizSheetContent?> fetchLessonSheetContent({
    required LicenseCategoryId categoryId,
    required int lessonNumber,
    required int sheetNumber,
  }) async => null;

  @override
  Future<List<QuizQuestion>> fetchLessonSheetQuestions({
    required LicenseCategoryId categoryId,
    required int lessonNumber,
    required int sheetNumber,
    int? limit,
  }) async => const [];

  @override
  Future<LessonSheetCompletionSnapshot> fetchLessonSheetCompletion({
    required LicenseCategoryId categoryId,
    required int lessonNumber,
  }) async => LessonSheetCompletionSnapshot.empty;

  @override
  Future<Map<String, List<QuizQuestion>>> fetchExamQuestionsByTopic({
    required LicenseCategoryId categoryId,
  }) async => {};

  @override
  Future<Map<int, List<QuizQuestion>>> fetchQuestionsForLessons({
    required LicenseCategoryId categoryId,
    required List<int> lessonNumbers,
  }) async {
    return {
      for (final lesson in lessonNumbers)
        lesson: List<QuizQuestion>.from(
          poolByLesson[lesson] ?? const <QuizQuestion>[],
        ),
    };
  }

  @override
  Future<Map<int, List<int>>> fetchLessonSheetNumbersByLesson({
    required LicenseCategoryId categoryId,
  }) async {
    if (throwOnSheetNumbers) {
      throw StateError('catalog fetch failed');
    }
    return {
      for (final entry in sheetNumbersByLesson.entries)
        entry.key: List<int>.from(entry.value),
    };
  }
}

void _unlockSheets({required int lessonNumber, required Iterable<int> sheets}) {
  for (final sheet in sheets) {
    studyAccessWritableRepository.applyLessonQuizSheetUnlock(
      categoryId: LicenseCategoryId.motore,
      lessonNumber: lessonNumber,
      sheetNumber: sheet,
      unlocked: true,
    );
  }
}

MultiTopicQuizAttemptSummary _completedAttempt({
  required String id,
  required String sessionId,
  required List<int> lessons,
  required int sheetIndex,
}) {
  return MultiTopicQuizAttemptSummary(
    id: id,
    sessionId: sessionId,
    licenseCategory: LicenseCategoryId.motore,
    lessonNumbers: lessons,
    sheetIndex: sheetIndex,
    totalSheets: 45,
    completedAt: DateTime.utc(2026, 10, 3),
    durationSeconds: 90,
    totalQuestions: 20,
    correctCount: 12,
    wrongCount: 8,
    unansweredCount: 0,
  );
}

/// Fake history che può fallire N volte e poi riuscire (per retry tests).
class _FlakyHistoryRepo implements MultiTopicQuizAttemptRepository {
  _FlakyHistoryRepo({required this.history, this.failuresRemaining = 0});

  List<MultiTopicQuizAttemptSummary> history;
  int failuresRemaining;
  Duration delay = Duration.zero;
  int fetchCount = 0;

  @override
  Future<List<MultiTopicQuizAttemptSummary>> fetchCurrentUserAttempts({
    required LicenseCategoryId category,
  }) async {
    fetchCount++;
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    if (failuresRemaining > 0) {
      failuresRemaining--;
      throw const MultiTopicQuizAttemptException(
        code: MultiTopicQuizAttemptErrorCode.repositoryUnavailable,
        message: 'history unavailable for test',
      );
    }
    return history
        .where((a) => a.licenseCategory == category)
        .toList(growable: false);
  }

  @override
  Future<MultiTopicQuizAttemptResult> submitAttempt(submission) async {
    throw UnsupportedError('not used');
  }

  @override
  Future<MultiTopicQuestionHistoryUsage> fetchCurrentUserQuestionUsage({
    required LicenseCategoryId category,
  }) async {
    // Attempts già fallito → usage non chiamato. Qui empty = success path.
    return MultiTopicQuestionHistoryUsage.empty;
  }

  @override
  Future<MultiTopicQuizAttemptDetail> fetchAttemptDetail(
    String attemptId,
  ) async {
    throw UnsupportedError('not used');
  }
}

Future<void> _pumpSetup(
  WidgetTester tester, {
  required StudentQuizRepository repo,
  void Function()? unlockBeforeLoad,
  List<MultiTopicQuizAttemptSummary> history = const [],
  MultiTopicQuizAttemptRepository? attemptRepo,
  Size viewport = const Size(1100, 1600),
}) async {
  MutableMockStudyAccessRepository.debugAllowDemoAccessSeedOverride = false;
  studyAccessWritableRepository.resetDemoAssignments();
  unlockBeforeLoad?.call();
  await tester.binding.setSurfaceSize(viewport);
  addTearDown(() async {
    MutableMockStudyAccessRepository.debugAllowDemoAccessSeedOverride = null;
    studyAccessWritableRepository.resetDemoAssignments();
    await tester.binding.setSurfaceSize(null);
  });

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: viewport),
      child: MaterialApp(
        home: MultiTopicQuizSetupPage(
          categoryId: LicenseCategoryId.motore,
          studentQuizRepositoryOverride: repo,
          attemptRepositoryOverride:
              attemptRepo ??
              MultiTopicQuizAttemptRepositoryFake(history: history),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _lessonTile(int lessonNumber) => find.text('Lezione $lessonNumber');

Future<void> _toggleLesson(WidgetTester tester, int lessonNumber) async {
  final tile = _lessonTile(lessonNumber);
  expect(tile, findsOneWidget);
  await tester.ensureVisible(tile);
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

void _unlockStandard() {
  _unlockSheets(lessonNumber: 2, sheets: [1, 2, 3, 4, 5, 6]);
  _unlockSheets(lessonNumber: 4, sheets: [1, 2, 3, 4, 5, 6, 7]);
  _unlockSheets(lessonNumber: 6, sheets: [1, 2, 3, 4, 5]);
}

void main() {
  group('STUDIO.SCHEDE.UX.2 — MultiTopicQuizSetupPage live total', () {
    late _FakeQuizRepo repo;

    setUp(() {
      repo = _FakeQuizRepo(
        sheetNumbersByLesson: {
          2: [1, 2, 3, 4, 5, 6],
          4: [1, 2, 3, 4, 5, 6, 7],
          6: [1, 2, 3, 4, 5],
          9: [1, 2, 3],
        },
        poolByLesson: {
          2: List.generate(40, (i) => _q('l2-$i', lesson: 2)),
          4: List.generate(40, (i) => _q('l4-$i', lesson: 4)),
          6: List.generate(40, (i) => _q('l6-$i', lesson: 6)),
          9: List.generate(40, (i) => _q('l9-$i', lesson: 9)),
        },
      );
    });

    testWidgets('L2 only → <2 argomenti, start disabled', (tester) async {
      await _pumpSetup(tester, repo: repo, unlockBeforeLoad: _unlockStandard);

      await _toggleLesson(tester, 2);
      expect(find.textContaining('Seleziona almeno 2 argomenti'), findsWidgets);
      final start = tester.widget<FilledButton>(
        find.byKey(const Key('multi_topic_start_button')),
      );
      expect(start.onPressed, isNull);
    });

    testWidgets('L2+L4 → 13 schede da svolgere e session.totalSheets=13', (
      tester,
    ) async {
      await _pumpSetup(tester, repo: repo, unlockBeforeLoad: _unlockStandard);

      await _toggleLesson(tester, 2);
      await _toggleLesson(tester, 4);
      expect(
        find.byKey(const Key('multi_topic_total_sheets_value_13')),
        findsOneWidget,
      );
      expect(find.text('13 schede da svolgere'), findsOneWidget);

      await tester.tap(find.byKey(const Key('multi_topic_start_button')));
      await tester.pumpAndSettle();

      final player = tester.widget<MultiTopicQuizPlayerPage>(
        find.byType(MultiTopicQuizPlayerPage),
      );
      expect(player.session.totalSheets, 13);
      expect(find.text('Scheda 1 di 13'), findsWidgets);
    });

    testWidgets('completed relevant 3 → remaining 10; add L6 → 15', (
      tester,
    ) async {
      await _pumpSetup(
        tester,
        repo: repo,
        unlockBeforeLoad: _unlockStandard,
        history: [
          for (var i = 1; i <= 3; i++)
            _completedAttempt(
              id: 'c$i',
              sessionId: 'sess-a',
              lessons: const [2, 4],
              sheetIndex: i,
            ),
        ],
      );

      await _toggleLesson(tester, 2);
      await _toggleLesson(tester, 4);
      // catalog 13 - completed 3 = 10
      expect(
        find.byKey(const Key('multi_topic_total_sheets_value_10')),
        findsOneWidget,
      );
      expect(find.text('10 schede da svolgere'), findsOneWidget);

      await _toggleLesson(tester, 6);
      // catalog 18 - completed 3 (still relevant) = 15
      expect(
        find.byKey(const Key('multi_topic_total_sheets_value_15')),
        findsOneWidget,
      );
    });

    testWidgets('remaining 0 → Start disabled + completed feedback', (
      tester,
    ) async {
      await _pumpSetup(
        tester,
        repo: repo,
        unlockBeforeLoad: _unlockStandard,
        history: [
          for (var i = 1; i <= 13; i++)
            _completedAttempt(
              id: 'done$i',
              sessionId: 'sess-full',
              lessons: const [2, 4],
              sheetIndex: i,
            ),
        ],
      );

      await _toggleLesson(tester, 2);
      await _toggleLesson(tester, 4);
      expect(
        find.byKey(const Key('multi_topic_total_sheets_value_0')),
        findsOneWidget,
      );
      expect(
        find.text('Hai completato tutte le schede disponibili.'),
        findsOneWidget,
      );
      final start = tester.widget<FilledButton>(
        find.byKey(const Key('multi_topic_start_button')),
      );
      expect(start.onPressed, isNull);
    });

    testWidgets('add L6 → 18; remove L4 → 11', (tester) async {
      await _pumpSetup(tester, repo: repo, unlockBeforeLoad: _unlockStandard);

      await _toggleLesson(tester, 2);
      await _toggleLesson(tester, 4);
      expect(
        find.byKey(const Key('multi_topic_total_sheets_value_13')),
        findsOneWidget,
      );

      await _toggleLesson(tester, 6);
      expect(
        find.byKey(const Key('multi_topic_total_sheets_value_18')),
        findsOneWidget,
      );

      await _toggleLesson(tester, 4);
      expect(
        find.byKey(const Key('multi_topic_total_sheets_value_11')),
        findsOneWidget,
      );
    });

    testWidgets('0 actionable sheets → lesson not selectable', (tester) async {
      await _pumpSetup(
        tester,
        repo: repo,
        unlockBeforeLoad: () {
          _unlockSheets(lessonNumber: 2, sheets: [1, 2, 3, 4, 5, 6]);
          _unlockSheets(lessonNumber: 4, sheets: [1, 2, 3, 4, 5, 6, 7]);
        },
      );

      expect(_lessonTile(2), findsOneWidget);
      expect(_lessonTile(4), findsOneWidget);
      expect(_lessonTile(9), findsNothing);
    });

    testWidgets('rapid toggle non lascia stale total', (tester) async {
      await _pumpSetup(tester, repo: repo, unlockBeforeLoad: _unlockStandard);

      await _toggleLesson(tester, 2);
      await _toggleLesson(tester, 4);
      await _toggleLesson(tester, 6);
      await _toggleLesson(tester, 6);
      await _toggleLesson(tester, 4);
      await _toggleLesson(tester, 4);
      expect(
        find.byKey(const Key('multi_topic_total_sheets_value_13')),
        findsOneWidget,
      );
    });

    testWidgets('fetch error → Start disabled / empty retry', (tester) async {
      final failing = _FakeQuizRepo(
        sheetNumbersByLesson: const {},
        poolByLesson: const {},
        throwOnSheetNumbers: true,
      );
      await _pumpSetup(tester, repo: failing);
      expect(find.text('Errore'), findsOneWidget);
      expect(find.text('INIZIA MULTISCHEDA'), findsNothing);
    });

    testWidgets('locked subset of sheets reduces Multischeda count', (
      tester,
    ) async {
      await _pumpSetup(
        tester,
        repo: repo,
        unlockBeforeLoad: () {
          _unlockSheets(lessonNumber: 2, sheets: [1, 2, 3, 4]);
          _unlockSheets(lessonNumber: 4, sheets: [1, 2, 3, 4, 5, 6, 7]);
        },
      );

      expect(find.textContaining('4 schede'), findsWidgets);
      await _toggleLesson(tester, 2);
      await _toggleLesson(tester, 4);
      expect(
        find.byKey(const Key('multi_topic_total_sheets_value_11')),
        findsOneWidget,
      );
    });
  });

  group('PROGRESS.3 — history failure / retry', () {
    late _FakeQuizRepo repo;

    setUp(() {
      repo = _FakeQuizRepo(
        sheetNumbersByLesson: {
          2: [1, 2, 3, 4, 5, 6],
          4: [1, 2, 3, 4, 5, 6, 7],
          6: [1, 2, 3, 4, 5],
        },
        poolByLesson: {
          2: List.generate(40, (i) => _q('l2-$i', lesson: 2)),
          4: List.generate(40, (i) => _q('l4-$i', lesson: 4)),
          6: List.generate(40, (i) => _q('l6-$i', lesson: 6)),
        },
      );
    });

    testWidgets('A. history success empty → remaining = catalog, Start ok', (
      tester,
    ) async {
      await _pumpSetup(tester, repo: repo, unlockBeforeLoad: _unlockStandard);
      await _toggleLesson(tester, 2);
      await _toggleLesson(tester, 4);
      expect(find.text('13 schede da svolgere'), findsOneWidget);
      final start = tester.widget<FilledButton>(
        find.byKey(const Key('multi_topic_start_button')),
      );
      expect(start.onPressed, isNotNull);
    });

    testWidgets('B. history success 3 relevant → 10 residue', (tester) async {
      await _pumpSetup(
        tester,
        repo: repo,
        unlockBeforeLoad: _unlockStandard,
        history: [
          for (var i = 1; i <= 3; i++)
            _completedAttempt(
              id: 'c$i',
              sessionId: 's',
              lessons: const [2, 4],
              sheetIndex: i,
            ),
        ],
      );
      await _toggleLesson(tester, 2);
      await _toggleLesson(tester, 4);
      expect(find.text('10 schede da svolgere'), findsOneWidget);
    });

    testWidgets('C. history failure → no remaining number, Start off, Retry', (
      tester,
    ) async {
      final flaky = _FlakyHistoryRepo(history: const [], failuresRemaining: 99);
      await _pumpSetup(
        tester,
        repo: repo,
        unlockBeforeLoad: _unlockStandard,
        attemptRepo: flaky,
      );

      await _toggleLesson(tester, 2);
      await _toggleLesson(tester, 4);

      expect(find.textContaining('schede da svolgere'), findsNothing);
      expect(
        find.byKey(const Key('multi_topic_total_sheets_unavailable')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('multi_topic_history_error')),
        findsOneWidget,
      );
      expect(
        find.text('Impossibile preparare una nuova scheda. Riprova.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('multi_topic_history_retry')),
        findsOneWidget,
      );
      final start = tester.widget<FilledButton>(
        find.byKey(const Key('multi_topic_start_button')),
      );
      expect(start.onPressed, isNull);
    });

    testWidgets(
      'CONTINUITY.4 H. question usage fetch failure → Start off + Retry',
      (tester) async {
        final attemptRepo = MultiTopicQuizAttemptRepositoryFake(
          history: const [],
          throwOnQuestionUsageFetch: const MultiTopicQuizAttemptException(
            code: MultiTopicQuizAttemptErrorCode.repositoryUnavailable,
            message: 'question usage unavailable',
          ),
        );
        await _pumpSetup(
          tester,
          repo: repo,
          unlockBeforeLoad: _unlockStandard,
          attemptRepo: attemptRepo,
        );
        await _toggleLesson(tester, 2);
        await _toggleLesson(tester, 4);

        expect(
          find.text('Impossibile preparare una nuova scheda. Riprova.'),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('multi_topic_history_retry')),
          findsOneWidget,
        );
        final start = tester.widget<FilledButton>(
          find.byKey(const Key('multi_topic_start_button')),
        );
        expect(start.onPressed, isNull);
      },
    );

    testWidgets('D. failure → retry success → 10 residue + Start', (
      tester,
    ) async {
      final flaky = _FlakyHistoryRepo(
        history: [
          for (var i = 1; i <= 3; i++)
            _completedAttempt(
              id: 'c$i',
              sessionId: 's',
              lessons: const [2, 4],
              sheetIndex: i,
            ),
        ],
        failuresRemaining: 1,
      );
      await _pumpSetup(
        tester,
        repo: repo,
        unlockBeforeLoad: _unlockStandard,
        attemptRepo: flaky,
      );
      await _toggleLesson(tester, 2);
      await _toggleLesson(tester, 4);
      expect(
        find.byKey(const Key('multi_topic_history_retry')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('multi_topic_history_retry')));
      await tester.pumpAndSettle();

      expect(find.text('10 schede da svolgere'), findsOneWidget);
      expect(find.byKey(const Key('multi_topic_history_error')), findsNothing);
      final start = tester.widget<FilledButton>(
        find.byKey(const Key('multi_topic_start_button')),
      );
      expect(start.onPressed, isNotNull);
    });

    testWidgets('E. success → subsequent refresh failure → Start off', (
      tester,
    ) async {
      final flaky = _FlakyHistoryRepo(
        history: [
          for (var i = 1; i <= 3; i++)
            _completedAttempt(
              id: 'c$i',
              sessionId: 's',
              lessons: const [2, 4],
              sheetIndex: i,
            ),
        ],
      );
      await _pumpSetup(
        tester,
        repo: repo,
        unlockBeforeLoad: _unlockStandard,
        attemptRepo: flaky,
      );
      await _toggleLesson(tester, 2);
      await _toggleLesson(tester, 4);
      expect(find.text('10 schede da svolgere'), findsOneWidget);

      // Forza un refresh che fallisce (simula reload post-sessione).
      flaky.failuresRemaining = 1;
      await tester.tap(find.byKey(const Key('multi_topic_start_button')));
      await tester.pumpAndSettle();
      // Pop player without completing — then setup reloads via finally.
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('multi_topic_history_error')),
        findsOneWidget,
      );
      expect(find.textContaining('10 schede da svolgere'), findsNothing);
      final start = tester.widget<FilledButton>(
        find.byKey(const Key('multi_topic_start_button')),
      );
      expect(start.onPressed, isNull);
    });

    testWidgets(
      'F. history failure + toggle → still unavailable, not 0-completed',
      (tester) async {
        final flaky = _FlakyHistoryRepo(
          history: const [],
          failuresRemaining: 5,
        );
        await _pumpSetup(
          tester,
          repo: repo,
          unlockBeforeLoad: _unlockStandard,
          attemptRepo: flaky,
        );
        await _toggleLesson(tester, 2);
        await _toggleLesson(tester, 4);
        await _toggleLesson(tester, 6);
        expect(find.textContaining('schede da svolgere'), findsNothing);
        expect(
          find.byKey(const Key('multi_topic_total_sheets_unavailable')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('multi_topic_total_sheets_value_18')),
          findsNothing,
        );
      },
    );

    testWidgets('G. stale slow failure discarded after newer success', (
      tester,
    ) async {
      final flaky = _FlakyHistoryRepo(
        history: [
          for (var i = 1; i <= 3; i++)
            _completedAttempt(
              id: 'c$i',
              sessionId: 's',
              lessons: const [2, 4],
              sheetIndex: i,
            ),
        ],
        failuresRemaining: 1,
      );
      await _pumpSetup(
        tester,
        repo: repo,
        unlockBeforeLoad: _unlockStandard,
        attemptRepo: flaky,
      );
      final retry = find.byKey(const Key('multi_topic_history_retry'));
      expect(retry, findsOneWidget);

      // Slow failure in-flight…
      flaky.failuresRemaining = 1;
      flaky.delay = const Duration(milliseconds: 250);
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pump(const Duration(milliseconds: 30));

      // …poi richiesta più recente che riesce (invalida la precedente).
      flaky.failuresRemaining = 0;
      flaky.delay = Duration.zero;
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();

      await _toggleLesson(tester, 2);
      await _toggleLesson(tester, 4);
      expect(find.text('10 schede da svolgere'), findsOneWidget);
      expect(find.byKey(const Key('multi_topic_history_error')), findsNothing);
    });
  });
}
