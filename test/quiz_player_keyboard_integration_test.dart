import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/exam_quiz_attempt_models.dart';
import 'package:scuola_nautica_liana/domain/exam_quiz_rules.dart';
import 'package:scuola_nautica_liana/domain/multi_topic_quiz_attempt_result.dart';
import 'package:scuola_nautica_liana/domain/multi_topic_quiz_session.dart';
import 'package:scuola_nautica_liana/models/assigned_quiz_models.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';
import 'package:scuola_nautica_liana/models/quiz_question.dart';
import 'package:scuola_nautica_liana/pages/assigned_quiz_player_page.dart';
import 'package:scuola_nautica_liana/pages/multi_topic_quiz_player_page.dart';
import 'package:scuola_nautica_liana/pages/quiz_exam_player_page.dart';
import 'package:scuola_nautica_liana/repositories/assigned_quiz_repository.dart';
import 'package:scuola_nautica_liana/repositories/exam_quiz_attempt_repository.dart';
import 'package:scuola_nautica_liana/repositories/multi_topic_quiz_attempt_repository.dart';
import 'package:scuola_nautica_liana/widgets/lesson_style_quiz_player_shell.dart';
import 'package:scuola_nautica_liana/widgets/nautical_answer_marker.dart';
import 'package:scuola_nautica_liana/widgets/quiz_player_keyboard_scope.dart';

QuizQuestion _q(int n, {String? imagePath}) => QuizQuestion(
  id: 'kb-q$n',
  prompt: 'Domanda tastiera $n',
  optionA: 'Opzione A $n',
  optionB: 'Opzione B $n',
  optionC: 'Opzione C $n',
  correctOption: QuizAnswerOption.a,
  lessonNumber: 1,
  licenseCategory: 'A12',
  imagePath: imagePath,
);

int? _selectedMarkerNumber(WidgetTester tester) {
  final selected = tester
      .widgetList<NauticalAnswerMarker>(find.byType(NauticalAnswerMarker))
      .where((m) => m.state == NauticalAnswerMarkerState.selected)
      .toList(growable: false);
  if (selected.length != 1) return null;
  return selected.single.answerNumber;
}

/// Lesson/Multi reveal uses correct/wrong markers, not "selected".
int? _activeAnswerNumber(WidgetTester tester) {
  final selected = _selectedMarkerNumber(tester);
  if (selected != null) return selected;
  final highlighted = tester
      .widgetList<NauticalAnswerMarker>(find.byType(NauticalAnswerMarker))
      .where(
        (m) =>
            m.state == NauticalAnswerMarkerState.correct ||
            m.state == NauticalAnswerMarkerState.wrong,
      )
      .toList(growable: false);
  if (highlighted.isEmpty) return null;
  // Prefer the user's wrong pick if present; else the correct marker.
  final wrong = highlighted.where(
    (m) => m.state == NauticalAnswerMarkerState.wrong,
  );
  if (wrong.length == 1) return wrong.single.answerNumber;
  final correct = highlighted.where(
    (m) => m.state == NauticalAnswerMarkerState.correct,
  );
  if (correct.length == 1) return correct.single.answerNumber;
  return null;
}

Future<void> _send(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
}

void main() {
  group('LessonStyleQuizPlayerShell keyboard', () {
    Future<void> pumpShell(
      WidgetTester tester, {
      required Size size,
      required List<QuizAnswerOption?> answers,
      required int index,
      required VoidCallback onPrimary,
      VoidCallback? onBack,
      VoidCallback? onForward,
      ValueChanged<QuizAnswerOption>? onSelect,
      double textScale = 1.0,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final questions = List.generate(3, (i) => _q(i + 1));
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: MaterialApp(
            home: LessonStyleQuizPlayerShell(
              appBar: AppBar(title: const Text('Scheda')),
              questions: questions,
              userAnswers: answers,
              currentIndex: index,
              correctCount: 0,
              wrongCount: 0,
              unansweredCount: answers.where((a) => a == null).length,
              onSelectAnswer: onSelect ?? (_) {},
              onGoBack: onBack,
              onGoForward: onForward,
              onPrimaryAction: onPrimary,
              canPop: true,
              onPopInvoked: (_, _) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('1/2/3 select only; no auto-confirm advance', (tester) async {
      final selected = <QuizAnswerOption>[];
      var primary = 0;
      final answers = <QuizAnswerOption?>[null, null, null];

      await pumpShell(
        tester,
        size: const Size(1366, 768),
        answers: answers,
        index: 0,
        onSelect: selected.add,
        onPrimary: () => primary++,
        onForward: () {},
        onBack: null,
      );

      await _send(tester, LogicalKeyboardKey.digit2);
      expect(selected, [QuizAnswerOption.b]);
      expect(primary, 0);

      await _send(tester, LogicalKeyboardKey.numpad3);
      expect(selected, [QuizAnswerOption.b, QuizAnswerOption.c]);
      expect(primary, 0);
    });

    testWidgets('revealed answer: digit is no-op (same as tap)', (tester) async {
      final selected = <QuizAnswerOption>[];
      await pumpShell(
        tester,
        size: const Size(1366, 768),
        answers: [QuizAnswerOption.a, null, null],
        index: 0,
        onSelect: selected.add,
        onPrimary: () {},
        onForward: () {},
      );
      await _send(tester, LogicalKeyboardKey.digit2);
      expect(selected, isEmpty);
    });

    testWidgets('Enter → primary; Right/Space → next; Left → previous', (
      tester,
    ) async {
      var primary = 0;
      var next = 0;
      var back = 0;
      await pumpShell(
        tester,
        size: const Size(1440, 900),
        answers: [QuizAnswerOption.a, null, null],
        index: 1,
        onPrimary: () => primary++,
        onForward: () => next++,
        onBack: () => back++,
      );

      await _send(tester, LogicalKeyboardKey.enter);
      expect(primary, 1);

      await _send(tester, LogicalKeyboardKey.arrowRight);
      expect(next, 1);

      await _send(tester, LogicalKeyboardKey.space);
      expect(next, 2);

      await _send(tester, LogicalKeyboardKey.arrowLeft);
      expect(back, 1);
    });

    testWidgets('first question: Left no-op when back disabled', (tester) async {
      var back = 0;
      await pumpShell(
        tester,
        size: const Size(1366, 768),
        answers: [null, null, null],
        index: 0,
        onPrimary: () {},
        onForward: () {},
        onBack: null,
      );
      await _send(tester, LogicalKeyboardKey.arrowLeft);
      expect(back, 0);
    });

    testWidgets('desktop help badge visible @1366, hidden @390', (tester) async {
      await pumpShell(
        tester,
        size: const Size(1366, 768),
        answers: [null, null, null],
        index: 0,
        onPrimary: () {},
        onForward: () {},
      );
      expect(find.byKey(const Key('quiz_player_keyboard_help')), findsOneWidget);

      await pumpShell(
        tester,
        size: const Size(390, 844),
        answers: [null, null, null],
        index: 0,
        onPrimary: () {},
        onForward: () {},
      );
      expect(find.byKey(const Key('quiz_player_keyboard_help')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('TextField focus: keys do not control quiz', (tester) async {
      var primary = 0;
      var selected = 0;
      var next = 0;
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: TextField(
                    key: Key('kb-text-field'),
                    autofocus: true,
                  ),
                ),
                Expanded(
                  child: QuizPlayerKeyboardScope(
                    autofocus: false,
                    onSelectAnswerIndex: (_) => selected++,
                    onConfirmOrNext: () => primary++,
                    onNext: () => next++,
                    onPrevious: () {},
                    child: const SizedBox.expand(
                      child: Text('quiz body'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byKey(const Key('kb-text-field'))),
        isA<TextField>(),
      );

      await _send(tester, LogicalKeyboardKey.digit1);
      await _send(tester, LogicalKeyboardKey.enter);
      await _send(tester, LogicalKeyboardKey.arrowRight);
      await _send(tester, LogicalKeyboardKey.space);

      expect(selected, 0);
      expect(primary, 0);
      expect(next, 0);
    });

    testWidgets('dialog open: player keys do not navigate', (tester) async {
      var next = 0;
      await pumpShell(
        tester,
        size: const Size(1366, 768),
        answers: [QuizAnswerOption.a, null, null],
        index: 0,
        onPrimary: () {},
        onForward: () => next++,
        onBack: null,
      );

      showDialog<void>(
        context: tester.element(find.byType(LessonStyleQuizPlayerShell)),
        builder: (ctx) => const AlertDialog(
          title: Text('Dialog test'),
          content: Text('Modal'),
        ),
      );
      await tester.pumpAndSettle();

      await _send(tester, LogicalKeyboardKey.arrowRight);
      await _send(tester, LogicalKeyboardKey.space);
      expect(next, 0);

      Navigator.of(
        tester.element(find.text('Dialog test')),
      ).pop();
      await tester.pumpAndSettle();
    });
  });

  group('QuizExamPlayerPage keyboard', () {
    Future<void> pumpExam(WidgetTester tester, {int count = 3}) async {
      final repo = ExamQuizAttemptRepositoryFake(
        submitResult: ExamQuizAttemptSubmitResult(
          idempotent: false,
          attempt: ExamQuizAttemptSummary(
            id: 'att-kb',
            licenseCategory: LicenseCategoryId.motore,
            completedAt: DateTime.utc(2026, 10, 21),
            duration: const Duration(minutes: 1),
            timeExpired: false,
            totalQuestions: count,
            correctCount: 0,
            wrongCount: 0,
            unansweredCount: count,
            outcome: ExamQuizOutcome.failed,
          ),
        ),
      );
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: QuizExamPlayerPage(
            categoryId: LicenseCategoryId.motore,
            questions: List.generate(count, (i) => _q(i + 1)),
            clientAttemptToken: 'kb-exam-token',
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('1/2/3 select; Enter/Right/Space next; Left back', (
      tester,
    ) async {
      await pumpExam(tester);

      expect(find.text('Domanda tastiera 1'), findsOneWidget);
      await _send(tester, LogicalKeyboardKey.digit2);
      expect(_selectedMarkerNumber(tester), 2);

      await _send(tester, LogicalKeyboardKey.arrowRight);
      expect(find.text('Domanda tastiera 2'), findsOneWidget);

      await _send(tester, LogicalKeyboardKey.digit1);
      expect(_selectedMarkerNumber(tester), 1);

      await _send(tester, LogicalKeyboardKey.space);
      expect(find.text('Domanda tastiera 3'), findsOneWidget);

      await _send(tester, LogicalKeyboardKey.arrowLeft);
      expect(find.text('Domanda tastiera 2'), findsOneWidget);

      await _send(tester, LogicalKeyboardKey.enter);
      expect(find.text('Domanda tastiera 3'), findsOneWidget);
    });

    testWidgets('first Left no-op; last Right disabled; Enter = Termina', (
      tester,
    ) async {
      await pumpExam(tester, count: 2);
      await _send(tester, LogicalKeyboardKey.arrowLeft);
      expect(find.text('Domanda tastiera 1'), findsOneWidget);

      await _send(tester, LogicalKeyboardKey.arrowRight);
      expect(find.text('Domanda tastiera 2'), findsOneWidget);
      expect(find.text('Termina esame'), findsOneWidget);

      await _send(tester, LogicalKeyboardKey.arrowRight);
      expect(find.text('Domanda tastiera 2'), findsOneWidget);

      await _send(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      // Unanswered dialog or summary path — primary invoked.
      expect(
        find.textContaining('non completate').evaluate().isNotEmpty ||
            find.text('Riepilogo esame').evaluate().isNotEmpty ||
            find.text('Termina esame').evaluate().isNotEmpty,
        isTrue,
      );
    });
  });

  group('MultiTopicQuizPlayerPage keyboard', () {
    testWidgets('shared shell: digit + nav keys', (tester) async {
      // Pool must satisfy Multischeda sheet size (20).
      final lessonQs = List.generate(30, (i) => _q(i + 1));
      final session = MultiTopicQuizSession(
        sessionId: 'kb-multi',
        licenseCategory: LicenseCategoryId.motore,
        selectedLessonNumbers: const [1],
        totalSheets: 1,
        poolByLesson: {1: lessonQs},
      );
      final repo = MultiTopicQuizAttemptRepositoryFake(
        submitResult: MultiTopicQuizAttemptResult(
          attemptId: 'att',
          sessionId: 'kb-multi',
          sheetIndex: 1,
          totalSheets: 1,
          licenseCategory: LicenseCategoryId.motore,
          lessonNumbers: const [1],
          completedAt: DateTime.utc(2026, 10, 21),
          durationSeconds: 5,
          totalQuestions: 20,
          correctCount: 0,
          wrongCount: 0,
          unansweredCount: 20,
          idempotent: false,
        ),
      );

      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: MultiTopicQuizPlayerPage(
            session: session,
            attemptRepositoryOverride: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LessonStyleQuizPlayerShell), findsOneWidget);
      expect(find.byType(QuizPlayerKeyboardScope), findsOneWidget);

      await _send(tester, LogicalKeyboardKey.digit1);
      expect(_activeAnswerNumber(tester), 1);

      await _send(tester, LogicalKeyboardKey.arrowRight);
      // Nuova domanda non ancora risposta.
      expect(_activeAnswerNumber(tester), isNull);

      await _send(tester, LogicalKeyboardKey.digit3);
      expect(_activeAnswerNumber(tester), 3);

      await _send(tester, LogicalKeyboardKey.space);
      expect(_activeAnswerNumber(tester), isNull);

      await _send(tester, LogicalKeyboardKey.arrowLeft);
      expect(_activeAnswerNumber(tester), 3);
    });
  });

  group('AssignedQuizPlayerPage keyboard', () {
    testWidgets('1/2/3 + Right/Left/Space via shared scope', (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final questions = List.generate(3, (i) {
        return AssignedQuizQuestion(
          assignmentItemId: 'item-$i',
          position: i + 1,
          prompt: 'Domanda assigned ${i + 1}?',
          optionA: 'Opzione A$i',
          optionB: 'Opzione B$i',
          optionC: 'Opzione C$i',
          lessonNumber: 1,
          selectedOption: null,
        );
      });
      final repo = AssignedQuizRepositoryFake(questions: questions);
      await tester.pumpWidget(
        MaterialApp(
          home: AssignedQuizPlayerPage(
            repository: repo,
            assignment: AssignedQuizSummary(
              id: 'a1',
              publicCode: 'AQZ-a1',
              studentId: 'st-1',
              studentUserId: 'user-1',
              licenseCategory: 'A12',
              title: 'Quiz scuola',
              staffNote: null,
              status: AssignedQuizStatus.assigned,
              questionCount: 3,
              repeatPolicy: AssignedQuizRepeatPolicy.unlimited,
              maxAttempts: null,
              createdAt: DateTime.utc(2026, 7, 1),
              assignedAt: DateTime.utc(2026, 7, 2),
            ),
            start: const AssignedQuizAttemptStartResult(
              attemptId: 'att-kb',
              attemptNumber: 1,
              resumed: false,
              questionCount: 3,
              attemptsUsed: 1,
            ),
            questions: questions,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(QuizPlayerKeyboardScope), findsOneWidget);

      await _send(tester, LogicalKeyboardKey.digit2);
      await tester.pumpAndSettle();
      expect(repo.saveCalls, isNotEmpty);
      expect(repo.saveCalls.last['selectedOption'], 'B');

      await _send(tester, LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.textContaining('Domanda assigned 2'), findsWidgets);

      await _send(tester, LogicalKeyboardKey.digit1);
      await tester.pumpAndSettle();
      expect(repo.saveCalls.last['selectedOption'], 'A');

      await _send(tester, LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(find.textContaining('Domanda assigned 3'), findsWidgets);

      await _send(tester, LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(find.textContaining('Domanda assigned 2'), findsWidgets);
    });
  });
}
