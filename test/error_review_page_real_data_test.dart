import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';
import 'package:scuola_nautica_liana/models/quiz_error_review_data.dart';
import 'package:scuola_nautica_liana/models/quiz_question.dart';
import 'package:scuola_nautica_liana/models/quiz_wrong_answer_entry.dart';
import 'package:scuola_nautica_liana/pages/error_review_page.dart';
import 'package:scuola_nautica_liana/repositories/quiz_error_review_repository.dart';
import 'package:scuola_nautica_liana/repositories/study_access_repository.dart';
import 'package:scuola_nautica_liana/services/student_area_context.dart';
import 'package:scuola_nautica_liana/widgets/statistics_recommended_review_section.dart';
import 'package:scuola_nautica_liana/services/error_review_provider.dart';
import 'package:scuola_nautica_liana/models/lesson_quiz_performance_snapshot.dart';

class FakeQuizErrorReviewRepository implements QuizErrorReviewRepository {
  FakeQuizErrorReviewRepository({
    this.result,
    this.error,
    this.unauthenticated = false,
    this.delay = Duration.zero,
    this.resultsByCategory,
    this.delaysByCategory,
    this.delaysPerCall = const [],
  });

  QuizErrorReviewData? result;
  Object? error;
  bool unauthenticated;
  Duration delay;
  Map<LicenseCategoryId, QuizErrorReviewData>? resultsByCategory;
  Map<LicenseCategoryId, Duration>? delaysByCategory;
  List<Duration> delaysPerCall;
  int fetchCount = 0;
  LicenseCategoryId? lastCategoryId;
  final List<LicenseCategoryId> fetchOrder = [];

  @override
  Future<QuizErrorReviewData> fetchCurrentUserErrors({
    required LicenseCategoryId categoryId,
    int? lessonNumber,
    QuizErrorReviewSort sort = QuizErrorReviewSort.recent,
    int? limit,
  }) async {
    fetchCount++;
    lastCategoryId = categoryId;
    fetchOrder.add(categoryId);
    final callIndex = fetchCount - 1;
    final callDelay = callIndex < delaysPerCall.length
        ? delaysPerCall[callIndex]
        : (delaysByCategory?[categoryId] ?? delay);
    await Future<void>.delayed(callDelay);
    if (unauthenticated) {
      throw const QuizErrorReviewUnauthenticatedException();
    }
    if (error != null) throw error!;
    if (resultsByCategory != null) {
      return resultsByCategory![categoryId] ??
          QuizErrorReviewData.empty(categoryId);
    }
    return result ?? QuizErrorReviewData.empty(categoryId);
  }
}

QuizWrongAnswerEntry _entry({
  String questionId = 'q1',
  String prompt = 'Qual è la risposta corretta?',
  int lessonNumber = 1,
  List<int> sheetNumbers = const [1, 3],
  QuizAnswerOption selected = QuizAnswerOption.a,
  QuizAnswerOption correct = QuizAnswerOption.b,
  int errorCount = 2,
  DateTime? lastWrongAt,
  String? explanation,
  String? imagePath,
  LicenseCategoryId licenseCategoryId = LicenseCategoryId.motore,
}) {
  final last = lastWrongAt ?? DateTime.utc(2026, 7, 12, 10);
  return QuizWrongAnswerEntry(
    questionId: questionId,
    prompt: prompt,
    optionA: 'Risposta A',
    optionB: 'Risposta B',
    optionC: 'Risposta C',
    latestSelectedOption: selected,
    correctOption: correct,
    explanation: explanation,
    imagePath: imagePath,
    lessonNumber: lessonNumber,
    sheetNumbers: sheetNumbers,
    licenseCategoryId: licenseCategoryId,
    errorCount: errorCount,
    firstWrongAt: DateTime.utc(2026, 7, 1),
    lastWrongAt: last,
  );
}

QuizErrorReviewData _dataWithEntries({
  List<QuizWrongAnswerEntry>? entries,
  int ignored = 0,
  LicenseCategoryId categoryId = LicenseCategoryId.motore,
}) {
  final list =
      entries ??
      [
        _entry(),
        _entry(
          questionId: 'q2',
          prompt: 'Seconda domanda',
          lessonNumber: 2,
          lastWrongAt: DateTime.utc(2026, 7, 8),
          errorCount: 3,
        ),
      ];
  final lessonCounts = <int, int>{};
  var totalOccurrences = 0;
  for (final e in list) {
    lessonCounts[e.lessonNumber] = (lessonCounts[e.lessonNumber] ?? 0) + 1;
    totalOccurrences += e.errorCount;
  }
  return QuizErrorReviewData(
    categoryId: categoryId,
    entries: list,
    totalUniqueQuestions: list.length,
    totalWrongOccurrences: totalOccurrences,
    lessonCounts: lessonCounts,
    lastWrongAt: list
        .map((e) => e.lastWrongAt)
        .reduce((a, b) => a.isAfter(b) ? a : b),
    ignoredMalformedRows: ignored,
  );
}

void main() {
  tearDown(() {
    studentAreaPreviewActiveMode.value = null;
    studyAccessWritableRepository.resetDemoAssignments();
  });

  group('ErrorReviewPage real data', () {
    testWidgets('loading iniziale', (tester) async {
      final repo = FakeQuizErrorReviewRepository(
        result: _dataWithEntries(),
        delay: const Duration(milliseconds: 200),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ErrorReviewPage(
            categoryId: LicenseCategoryId.motore,
            repository: repo,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Caricamento errori da ripassare…'), findsOneWidget);
      expect(repo.fetchCount, 1);

      await tester.pumpAndSettle();
      expect(find.text('Caricamento errori da ripassare…'), findsNothing);
    });

    testWidgets('dati reali e riepilogo', (tester) async {
      final repo = FakeQuizErrorReviewRepository(result: _dataWithEntries());

      await tester.pumpWidget(
        MaterialApp(
          home: ErrorReviewPage(
            categoryId: LicenseCategoryId.motore,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Domande da ripassare'), findsOneWidget);
      expect(find.text('Errori registrati'), findsOneWidget);
      expect(find.text('Lezioni coinvolte'), findsOneWidget);
      expect(
        find.textContaining('Qual è la risposta corretta'),
        findsOneWidget,
      );
      expect(find.textContaining('Seconda domanda'), findsOneWidget);
    });

    testWidgets('storico vuoto', (tester) async {
      final repo = FakeQuizErrorReviewRepository(
        result: QuizErrorReviewData.empty(LicenseCategoryId.motore),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ErrorReviewPage(
            categoryId: LicenseCategoryId.motore,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nessun errore da ripassare'), findsOneWidget);
      expect(find.text('Vai alle schede'), findsOneWidget);
    });

    testWidgets('ignored-only', (tester) async {
      final repo = FakeQuizErrorReviewRepository(
        result: QuizErrorReviewData(
          categoryId: LicenseCategoryId.motore,
          entries: const [],
          totalUniqueQuestions: 0,
          totalWrongOccurrences: 0,
          lessonCounts: const {},
          lastWrongAt: null,
          ignoredMalformedRows: 4,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ErrorReviewPage(
            categoryId: LicenseCategoryId.motore,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Alcuni errori non possono essere mostrati.'),
        findsOneWidget,
      );
    });

    testWidgets('dati validi + ignored note', (tester) async {
      final repo = FakeQuizErrorReviewRepository(
        result: _dataWithEntries(ignored: 2),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ErrorReviewPage(
            categoryId: LicenseCategoryId.motore,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('2 risposte non incluse'), findsOneWidget);
      expect(
        find.textContaining('Qual è la risposta corretta'),
        findsOneWidget,
      );
    });

    testWidgets('errore repository', (tester) async {
      final repo = FakeQuizErrorReviewRepository(error: Exception('net'));

      await tester.pumpWidget(
        MaterialApp(
          home: ErrorReviewPage(
            categoryId: LicenseCategoryId.motore,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Non è stato possibile caricare il ripasso errori.'),
        findsOneWidget,
      );
    });

    testWidgets('non autenticato', (tester) async {
      final repo = FakeQuizErrorReviewRepository(unauthenticated: true);

      await tester.pumpWidget(
        MaterialApp(
          home: ErrorReviewPage(
            categoryId: LicenseCategoryId.motore,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('La sessione non è disponibile. Accedi nuovamente.'),
        findsOneWidget,
      );
    });

    testWidgets('vela non disponibile', (tester) async {
      final repo = FakeQuizErrorReviewRepository(result: _dataWithEntries());

      await tester.pumpWidget(
        MaterialApp(
          home: ErrorReviewPage(
            categoryId: LicenseCategoryId.vela,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(repo.fetchCount, 0);
      expect(
        find.text(
          'Il ripasso errori per questo percorso non è ancora disponibile.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('preview staff non invoca repository', (tester) async {
      final repo = FakeQuizErrorReviewRepository(result: _dataWithEntries());
      studentAreaPreviewActiveMode.value = StudentAreaMode.staffPreview;

      await tester.pumpWidget(
        MaterialApp(
          home: StudentAreaContext(
            mode: StudentAreaMode.staffPreview,
            readOnly: true,
            child: ErrorReviewPage(
              categoryId: LicenseCategoryId.motore,
              repository: repo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(repo.fetchCount, 0);
      expect(find.text('Ripasso errori allievo'), findsOneWidget);
    });

    testWidgets('filtro lezione senza nuovo fetch', (tester) async {
      final repo = FakeQuizErrorReviewRepository(result: _dataWithEntries());

      await tester.pumpWidget(
        MaterialApp(
          home: ErrorReviewPage(
            categoryId: LicenseCategoryId.motore,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.fetchCount, 1);

      await tester.tap(find.text('Tutte le lezioni'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('2. Motori').last);
      await tester.pumpAndSettle();

      expect(repo.fetchCount, 1);
      expect(find.text('Seconda domanda'), findsOneWidget);
      expect(find.textContaining('Qual è la risposta corretta'), findsNothing);
    });

    testWidgets('filtro senza risultati', (tester) async {
      final repo = FakeQuizErrorReviewRepository(
        result: _dataWithEntries(entries: [_entry(lessonNumber: 1)]),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ErrorReviewPage(
            categoryId: LicenseCategoryId.motore,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tutte le lezioni'));
      await tester.pumpAndSettle();
      // Select lesson 2 which has no errors in this dataset
      final lesson2 = find.textContaining('2. Motori');
      if (lesson2.evaluate().isNotEmpty) {
        await tester.tap(lesson2.last);
        await tester.pumpAndSettle();
        expect(find.text('Nessun errore per questa lezione.'), findsOneWidget);
      }
    });

    testWidgets('refresh invoca repository', (tester) async {
      final repo = FakeQuizErrorReviewRepository(result: _dataWithEntries());

      await tester.pumpWidget(
        MaterialApp(
          home: ErrorReviewPage(
            categoryId: LicenseCategoryId.motore,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.fetchCount, 1);

      await tester.tap(find.byIcon(Icons.refresh_rounded));
      await tester.pumpAndSettle();
      expect(repo.fetchCount, 2);
    });

    testWidgets('ordinamento più sbagliate', (tester) async {
      final repo = FakeQuizErrorReviewRepository(result: _dataWithEntries());

      await tester.pumpWidget(
        MaterialApp(
          home: ErrorReviewPage(
            categoryId: LicenseCategoryId.motore,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Più recenti'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Più sbagliate').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('Seconda domanda'), findsOneWidget);
    });

    testWidgets(
      'cambio categoria invalida dati precedenti e ignora risposte tardive',
      (tester) async {
        const a12Prompt = 'Prompt specifico A12';
        const d1Prompt = 'Prompt specifico D1';
        const tardyA12Prompt = 'Prompt tardivo A12';

        final repo = FakeQuizErrorReviewRepository(
          resultsByCategory: {
            LicenseCategoryId.motore: _dataWithEntries(
              entries: [_entry(prompt: a12Prompt)],
            ),
            LicenseCategoryId.d1: _dataWithEntries(
              entries: [
                _entry(
                  prompt: d1Prompt,
                  licenseCategoryId: LicenseCategoryId.d1,
                ),
              ],
              categoryId: LicenseCategoryId.d1,
            ),
          },
          delaysPerCall: const [Duration.zero, Duration(milliseconds: 200)],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ErrorReviewPage(
              categoryId: LicenseCategoryId.motore,
              repository: repo,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining(a12Prompt), findsOneWidget);
        expect(repo.fetchCount, 1);
        expect(repo.fetchOrder, [LicenseCategoryId.motore]);

        await tester.tap(find.byType(DropdownButton<LicenseCategoryId>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Patente D1').last);
        await tester.pump();

        expect(find.textContaining(a12Prompt), findsNothing);
        expect(find.text('Domande da ripassare'), findsNothing);
        expect(find.text('Tutte le lezioni'), findsNothing);
        expect(find.text('Caricamento errori da ripassare…'), findsOneWidget);
        expect(repo.fetchCount, 2);
        expect(repo.fetchOrder, [
          LicenseCategoryId.motore,
          LicenseCategoryId.d1,
        ]);

        await tester.pumpAndSettle();

        expect(find.textContaining(d1Prompt), findsOneWidget);
        expect(find.textContaining(a12Prompt), findsNothing);
        expect(find.text('Caricamento errori da ripassare…'), findsNothing);
        expect(repo.fetchCount, 2);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();

        final staleRepo = FakeQuizErrorReviewRepository(
          resultsByCategory: {
            LicenseCategoryId.motore: _dataWithEntries(
              entries: [_entry(prompt: tardyA12Prompt)],
            ),
            LicenseCategoryId.d1: _dataWithEntries(
              entries: [
                _entry(
                  prompt: d1Prompt,
                  licenseCategoryId: LicenseCategoryId.d1,
                ),
              ],
              categoryId: LicenseCategoryId.d1,
            ),
          },
          delaysPerCall: const [
            Duration.zero,
            Duration(milliseconds: 500),
            Duration(milliseconds: 100),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ErrorReviewPage(
              categoryId: LicenseCategoryId.motore,
              repository: staleRepo,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining(tardyA12Prompt), findsOneWidget);

        await tester.tap(find.byIcon(Icons.refresh_rounded));
        await tester.pump();

        await tester.tap(find.byType(DropdownButton<LicenseCategoryId>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Patente D1').last);
        await tester.pump();

        expect(find.textContaining(tardyA12Prompt), findsNothing);
        expect(find.text('Caricamento errori da ripassare…'), findsOneWidget);
        expect(staleRepo.fetchCount, 3);

        await tester.pumpAndSettle();

        expect(find.textContaining(d1Prompt), findsOneWidget);
        expect(find.textContaining(tardyA12Prompt), findsNothing);

        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump();

        expect(find.textContaining(d1Prompt), findsOneWidget);
        expect(find.textContaining(tardyA12Prompt), findsNothing);
        expect(staleRepo.fetchOrder, [
          LicenseCategoryId.motore,
          LicenseCategoryId.motore,
          LicenseCategoryId.d1,
        ]);
      },
    );
  });

  group('StatisticsRecommendedReviewSection CTA', () {
    testWidgets('CTA apre ErrorReviewPage con categoryId', (tester) async {
      final viewData = ErrorReviewProvider.buildViewDataFromSnapshots(
        categoryId: LicenseCategoryId.motore,
        snapshots: const [
          LessonQuizPerformanceSnapshot(
            categoryId: LicenseCategoryId.motore,
            lessonNumber: 1,
            lessonTitle: '1. Teoria dello scafo',
            totalAttempts: 3,
            averageErrorPercentage: 50,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatisticsRecommendedReviewSection(
              categoryId: LicenseCategoryId.motore,
              viewData: viewData,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Apri Ripasso errori'), findsOneWidget);
      await tester.tap(find.text('Apri Ripasso errori'));
      await tester.pumpAndSettle();
      expect(find.byType(ErrorReviewPage), findsOneWidget);
    });

    testWidgets('CTA assente in preview staff', (tester) async {
      final viewData = ErrorReviewProvider.buildViewDataFromSnapshots(
        categoryId: LicenseCategoryId.motore,
        snapshots: const [
          LessonQuizPerformanceSnapshot(
            categoryId: LicenseCategoryId.motore,
            lessonNumber: 1,
            lessonTitle: '1. Teoria dello scafo',
            totalAttempts: 3,
            averageErrorPercentage: 50,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StudentAreaContext(
            mode: StudentAreaMode.staffPreview,
            readOnly: true,
            child: Scaffold(
              body: StatisticsRecommendedReviewSection(
                categoryId: LicenseCategoryId.motore,
                viewData: viewData,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Apri Ripasso errori'), findsNothing);
    });
  });
}
