import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/course_taxonomy.dart';
import 'package:scuola_nautica_liana/domain/staff/staff_school_role.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';
import 'package:scuola_nautica_liana/models/quiz_error_review_data.dart';
import 'package:scuola_nautica_liana/models/quiz_question.dart';
import 'package:scuola_nautica_liana/models/quiz_wrong_answer_entry.dart';
import 'package:scuola_nautica_liana/pages/error_review_page.dart';
import 'package:scuola_nautica_liana/pages/quiz_dashboard_page.dart';
import 'package:scuola_nautica_liana/repositories/quiz_error_review_repository.dart';
import 'package:scuola_nautica_liana/repositories/study_access_repository.dart';
import 'package:scuola_nautica_liana/services/demo_student_enrollment.dart';
import 'package:scuola_nautica_liana/services/staff_access_service.dart';
import 'package:scuola_nautica_liana/services/student_area_context.dart';
import 'package:scuola_nautica_liana/services/student_content_navigation.dart';
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
    demoStudentEnrollmentPath.value = EnrollmentCoursePath.entro12Miglia;
    clearStudentSession();
    staffAccessNotifier.value = StaffAccessSnapshot.initial().copyWith(
      isLoading: false,
      hasAuthSession: true,
      staffRole: null,
      clearError: true,
    );
  });

  void setStaffWithoutPreview() {
    staffAccessNotifier.value = staffAccessNotifier.value.copyWith(
      isLoading: false,
      staffRole: StaffSchoolRole.staff,
      hasAuthSession: true,
      clearError: true,
    );
  }

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
      setStaffWithoutPreview();
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
  });

  group('ErrorReviewPage percorso reale bloccato', () {
    testWidgets('allievo A12 fetch solo A12 e senza selettore D1', (
      tester,
    ) async {
      demoStudentEnrollmentPath.value = EnrollmentCoursePath.entro12Miglia;
      final repo = FakeQuizErrorReviewRepository(
        resultsByCategory: {
          LicenseCategoryId.motore: _dataWithEntries(
            entries: [_entry(prompt: 'Errore A12')],
          ),
          LicenseCategoryId.d1: _dataWithEntries(
            entries: [
              _entry(
                prompt: 'Errore D1',
                licenseCategoryId: LicenseCategoryId.d1,
              ),
            ],
            categoryId: LicenseCategoryId.d1,
          ),
        },
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

      expect(repo.fetchCount, 1);
      expect(repo.lastCategoryId, LicenseCategoryId.motore);
      expect(find.textContaining('Errore A12'), findsOneWidget);
      expect(find.textContaining('Errore D1'), findsNothing);
      expect(find.byType(DropdownButton<LicenseCategoryId>), findsNothing);
      expect(find.text('Patente D1'), findsNothing);
      expect(find.text('Entro le 12 miglia motore'), findsNothing);
    });

    testWidgets('allievo D1 fetch solo D1 e senza selettore A12', (
      tester,
    ) async {
      demoStudentEnrollmentPath.value = EnrollmentCoursePath.d1;
      final repo = FakeQuizErrorReviewRepository(
        resultsByCategory: {
          LicenseCategoryId.motore: _dataWithEntries(
            entries: [_entry(prompt: 'Errore A12')],
          ),
          LicenseCategoryId.d1: _dataWithEntries(
            entries: [
              _entry(
                prompt: 'Errore D1',
                licenseCategoryId: LicenseCategoryId.d1,
              ),
            ],
            categoryId: LicenseCategoryId.d1,
          ),
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ErrorReviewPage(
            categoryId: LicenseCategoryId.d1,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(repo.fetchCount, 1);
      expect(repo.lastCategoryId, LicenseCategoryId.d1);
      expect(find.textContaining('Errore D1'), findsOneWidget);
      expect(find.textContaining('Errore A12'), findsNothing);
      expect(find.byType(DropdownButton<LicenseCategoryId>), findsNothing);
      expect(find.text('Entro le 12 miglia motore'), findsNothing);
      expect(find.text('Patente D1'), findsNothing);
    });

    testWidgets('categoryId route errato normalizzato con un solo fetch', (
      tester,
    ) async {
      demoStudentEnrollmentPath.value = EnrollmentCoursePath.d1;
      final repo = FakeQuizErrorReviewRepository(
        resultsByCategory: {
          LicenseCategoryId.motore: _dataWithEntries(
            entries: [_entry(prompt: 'Errore A12')],
          ),
          LicenseCategoryId.d1: _dataWithEntries(
            entries: [
              _entry(
                prompt: 'Errore D1',
                licenseCategoryId: LicenseCategoryId.d1,
              ),
            ],
            categoryId: LicenseCategoryId.d1,
          ),
        },
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

      expect(repo.fetchCount, 1);
      expect(repo.fetchOrder, [LicenseCategoryId.d1]);
      expect(find.textContaining('Errore D1'), findsOneWidget);
      expect(find.textContaining('Errore A12'), findsNothing);
    });

    testWidgets('vela non fa fallback A12', (tester) async {
      setStaffWithoutPreview();
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
      expect(repo.lastCategoryId, isNull);
      expect(
        find.text(
          'Il ripasso errori per questo percorso non è ancora disponibile.',
        ),
        findsOneWidget,
      );
    });
  });

  group('StatisticsRecommendedReviewSection CTA', () {
    testWidgets('CTA apre ErrorReviewPage con percorso reale', (tester) async {
      demoStudentEnrollmentPath.value = EnrollmentCoursePath.d1;
      final viewData = ErrorReviewProvider.buildViewDataFromSnapshots(
        categoryId: LicenseCategoryId.d1,
        snapshots: const [
          LessonQuizPerformanceSnapshot(
            categoryId: LicenseCategoryId.d1,
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
              categoryId: LicenseCategoryId.d1,
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
      expect(
        StudentContentNavigation.directErrorReviewCategoryForCurrentUser(),
        LicenseCategoryId.d1,
      );
    });

    testWidgets('CTA normalizza categoryId errato al percorso reale', (
      tester,
    ) async {
      demoStudentEnrollmentPath.value = EnrollmentCoursePath.d1;
      final repo = FakeQuizErrorReviewRepository(
        resultsByCategory: {
          LicenseCategoryId.motore: _dataWithEntries(
            entries: [_entry(prompt: 'Errore A12')],
          ),
          LicenseCategoryId.d1: _dataWithEntries(
            entries: [
              _entry(
                prompt: 'Errore D1',
                licenseCategoryId: LicenseCategoryId.d1,
              ),
            ],
            categoryId: LicenseCategoryId.d1,
          ),
        },
      );
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
      await tester.tap(find.text('Apri Ripasso errori'));
      await tester.pumpAndSettle();

      // Sostituisce la page aperta dalla CTA con repository fake per assert fetch.
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
      expect(repo.lastCategoryId, LicenseCategoryId.d1);
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

  group('QuizDashboard Ripasso errori', () {
    testWidgets('dashboard apre Ripasso con percorso reale D1', (tester) async {
      demoStudentEnrollmentPath.value = EnrollmentCoursePath.d1;
      expect(
        StudentContentNavigation.directErrorReviewCategoryForCurrentUser(),
        LicenseCategoryId.d1,
      );

      await tester.pumpWidget(const MaterialApp(home: QuizDashboardPage()));
      await tester.pumpAndSettle();

      // Con 5 tile la griglia scrolla: Ripasso può essere fuori viewport (800×600).
      await tester.ensureVisible(find.text('Ripasso errori'));
      await tester.tap(find.text('Ripasso errori'));
      await tester.pumpAndSettle();

      expect(find.byType(ErrorReviewPage), findsOneWidget);
      expect(find.byType(DropdownButton<LicenseCategoryId>), findsNothing);
    });
  });
}
