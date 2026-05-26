import '../../constants/extra_content_ids.dart';
import '../../domain/backoffice/backoffice.dart';
import 'management_repository.dart';

class ManagementRepositoryMock implements ManagementRepository {
  final Set<String> _purchasedExtraProductIds = <String>{};

  static const List<NauticalInstructor> _instructors = [
    NauticalInstructor(
      id: 'mock-instructor-vincenzo-scibile',
      displayName: 'Vincenzo Scibile',
      slug: 'vincenzo-scibile',
    ),
    NauticalInstructor(
      id: 'mock-instructor-vincenzo-lomiento',
      displayName: 'Vincenzo Lomiento',
      slug: 'vincenzo-lomiento',
    ),
    NauticalInstructor(
      id: 'mock-instructor-luigi-visalli',
      displayName: 'Luigi Visalli',
      slug: 'luigi-visalli',
    ),
  ];

  static const List<ExpenseCategory> _expenseCategories = [
    ExpenseCategory(
      id: 'mock-expense-benzina',
      name: 'benzina',
      slug: 'benzina',
      sortOrder: 10,
    ),
    ExpenseCategory(
      id: 'mock-expense-pagamento-istruttori',
      name: 'pagamento istruttori',
      slug: 'pagamento-istruttori',
      sortOrder: 20,
    ),
    ExpenseCategory(
      id: 'mock-expense-affitto-pontile',
      name: 'affitto pontile',
      slug: 'affitto-pontile',
      sortOrder: 30,
    ),
    ExpenseCategory(
      id: 'mock-expense-tagliando',
      name: 'tagliando',
      slug: 'tagliando',
      sortOrder: 40,
    ),
    ExpenseCategory(
      id: 'mock-expense-manutenzione',
      name: 'manutenzione',
      slug: 'manutenzione',
      sortOrder: 50,
    ),
    ExpenseCategory(
      id: 'mock-expense-altro-manuale',
      name: 'altro manuale',
      slug: 'altro-manuale',
      sortOrder: 60,
    ),
  ];

  static const List<ExtraProduct> _extraProducts = [
    ExtraProduct(
      id: ExtraContentIds.extraTeoria,
      title: 'Video corso lezioni teoriche',
      subtitle: 'Corso video dedicato alla preparazione teorica nautica.',
      description:
          'Lezioni teoriche in video per affiancare corso in aula e ripasso.',
      priceCents: 4900,
      sortOrder: 10,
    ),
    ExtraProduct(
      id: ExtraContentIds.extraGuida,
      title: 'Video preparazione esame di guida',
      subtitle:
          'Contenuti video dedicati alla preparazione della prova pratica/guida.',
      description:
          "Esercitazione e approccio all'esame pratico e alla guida in mare.",
      priceCents: 3900,
      sortOrder: 20,
    ),
    ExtraProduct(
      id: ExtraContentIds.extraCarteggio,
      title: 'Video corso carteggio',
      subtitle:
          'Percorso video dedicato al carteggio nautico e agli esercizi pratici.',
      description: 'Carteggio: strumenti, tracciamento, lettura carta.',
      priceCents: 3500,
      sortOrder: 30,
    ),
    ExtraProduct(
      id: ExtraContentIds.extraPacchetto,
      title: 'Pacchetto completo',
      subtitle: 'Comprende teoria, guida e carteggio.',
      description: "Accesso a tutti i percorsi video in un'unica offerta.",
      priceCents: 9900,
      sortOrder: 40,
    ),
  ];

  @override
  Future<List<NauticalInstructor>> listInstructors() async {
    return List<NauticalInstructor>.unmodifiable(_instructors);
  }

  @override
  Future<List<ExpenseCategory>> listExpenseCategories() async {
    return List<ExpenseCategory>.unmodifiable(_expenseCategories);
  }

  @override
  Future<List<NauticalExpense>> listExpenses({
    DateTime? from,
    DateTime? to,
  }) async {
    return const <NauticalExpense>[];
  }

  @override
  Future<List<ExtraProduct>> listExtraProducts() async {
    return List<ExtraProduct>.unmodifiable(_extraProducts);
  }

  @override
  Future<List<ExtraVideoItem>> listExtraVideoItems(String productId) async {
    return const <ExtraVideoItem>[];
  }

  @override
  Future<Set<String>> listPurchasedExtraProductIds(StudentId studentId) async {
    return Set<String>.unmodifiable(_purchasedExtraProductIds);
  }

  @override
  Future<bool> startExtraProductCheckout({
    required StudentId studentId,
    required String productId,
    int? amountCents,
    String currencyCode = 'EUR',
    String? paymentReference,
  }) async {
    _purchasedExtraProductIds.add(productId);
    return true;
  }
}
