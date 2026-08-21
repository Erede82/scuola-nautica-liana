import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/data/backoffice_mock/backoffice_demo_store.dart';
import 'package:scuola_nautica_liana/data/backoffice_mock/school_backoffice_demo_data.dart';
import 'package:scuola_nautica_liana/domain/backoffice/backoffice.dart';
import 'package:scuola_nautica_liana/repositories/backoffice/backoffice_repository_mock.dart';
import 'package:scuola_nautica_liana/widgets/backoffice/student_backoffice_dialogs.dart';

class _SpyPaymentRepo extends BackofficeRepositoryMock {
  _SpyPaymentRepo({
    required BackofficeDemoStore store,
    this.throwAfterFirstCommit = false,
    this.refreshError,
  }) : super(store: store);

  final bool throwAfterFirstCommit;
  final Object? refreshError;

  final List<String?> idempotencyKeys = [];
  int addCalls = 0;
  final Set<String> _committedKeys = {};
  bool _failRefresh = false;

  @override
  Future<void> addPayment({
    required StudentId studentId,
    required int amountCents,
    required PaymentMethod method,
    required DateTime receivedAt,
    String? notes,
    String? receiptReference,
    String? idempotencyKey,
  }) async {
    addCalls++;
    idempotencyKeys.add(idempotencyKey);
    final key = idempotencyKey?.trim();
    if (key != null && key.isNotEmpty && _committedKeys.contains(key)) {
      return;
    }
    await super.addPayment(
      studentId: studentId,
      amountCents: amountCents,
      method: method,
      receivedAt: receivedAt,
      notes: notes,
      receiptReference: receiptReference,
      idempotencyKey: idempotencyKey,
    );
    if (key != null && key.isNotEmpty) {
      _committedKeys.add(key);
    }
    if (refreshError != null) {
      _failRefresh = true;
    }
    if (throwAfterFirstCommit && addCalls == 1) {
      throw StateError('timeout');
    }
  }

  @override
  Future<StudentAdmin360View?> getStudentAdmin360(StudentId studentId) async {
    if (_failRefresh && refreshError != null) {
      throw refreshError!;
    }
    return super.getStudentAdmin360(studentId);
  }
}

Future<StudentAdmin360View> _openPaymentDialog(
  WidgetTester tester, {
  required _SpyPaymentRepo repo,
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 900));
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });

  final view = await repo.getStudentAdmin360(
    SchoolBackofficeDemoData.demoStudentLucia,
  );
  expect(view, isNotNull);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAddPaymentDialog(
              context,
              view: view!,
              repository: repo,
              onRefreshDetail: ([updated]) async {},
            ),
            child: const Text('Apri pagamento'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Apri pagamento'));
  await tester.pumpAndSettle();
  expect(find.text('Aggiungi pagamento'), findsOneWidget);
  return view!;
}

Future<void> _confirmAmount(WidgetTester tester, String amount) async {
  await tester.enterText(find.byKey(const ValueKey('add-payment-amount')), amount);
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('add-payment-save')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Conferma'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'retry after timeout-after-commit reuses the same payment idempotency key',
    (tester) async {
      final store = BackofficeDemoStore.initial();
      final repo = _SpyPaymentRepo(store: store, throwAfterFirstCommit: true);
      final before = await repo.getStudentAdmin360(
        SchoolBackofficeDemoData.demoStudentLucia,
      );
      final beforeCount = before!.payments.length;

      await _openPaymentDialog(tester, repo: repo);
      await _confirmAmount(tester, '250');

      expect(repo.addCalls, 1);
      expect(find.text('Aggiungi pagamento'), findsOneWidget);
      expect(find.textContaining('Errore:'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('add-payment-save')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Conferma'));
      await tester.pumpAndSettle();

      expect(repo.addCalls, 2);
      expect(repo.idempotencyKeys, hasLength(2));
      expect(repo.idempotencyKeys[0], isNotNull);
      expect(repo.idempotencyKeys[0], isNotEmpty);
      expect(repo.idempotencyKeys[0], repo.idempotencyKeys[1]);

      final after = await repo.getStudentAdmin360(
        SchoolBackofficeDemoData.demoStudentLucia,
      );
      expect(after!.payments.length, beforeCount + 1);
      expect(find.text('Pagamento registrato.'), findsOneWidget);
    },
  );

  testWidgets(
    'refresh failure after successful write still reports payment recorded',
    (tester) async {
      final store = BackofficeDemoStore.initial();
      final repo = _SpyPaymentRepo(
        store: store,
        refreshError: StateError('refresh failed'),
      );
      final before = await BackofficeRepositoryMock(store: store)
          .getStudentAdmin360(SchoolBackofficeDemoData.demoStudentLucia);
      final beforeCount = before!.payments.length;

      await _openPaymentDialog(tester, repo: repo);
      await _confirmAmount(tester, '80');

      expect(repo.addCalls, 1);
      expect(find.text('Aggiungi pagamento'), findsNothing);
      expect(find.text('Pagamento registrato.'), findsOneWidget);
      expect(find.textContaining('Errore:'), findsNothing);

      final after = await BackofficeRepositoryMock(store: store)
          .getStudentAdmin360(SchoolBackofficeDemoData.demoStudentLucia);
      expect(after!.payments.length, beforeCount + 1);
    },
  );
}
