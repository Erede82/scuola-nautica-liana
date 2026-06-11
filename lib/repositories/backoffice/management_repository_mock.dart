import '../../constants/extra_content_ids.dart';
import '../../domain/backoffice/backoffice.dart';
import 'management_repository.dart';

class ManagementRepositoryMock implements ManagementRepository {
  final Set<String> _purchasedExtraProductIds = <String>{};
  final List<PracticeServiceTemplate> _practiceServiceTemplates =
      List<PracticeServiceTemplate>.from(_seedPracticeServiceTemplates);
  final List<NauticalExpense> _expenses =
      List<NauticalExpense>.from(_demoExpensesSeed());

  static int _mockIdSeq = 0;
  static int _mockExpenseIdSeq = 0;

  static String _nextMockId() {
    _mockIdSeq += 1;
    return 'mock-practice-template-$_mockIdSeq';
  }

  static const List<PracticeServiceTemplate> _seedPracticeServiceTemplates = [
    PracticeServiceTemplate(
      id: 'mock-template-entro-12-motore',
      slug: 'patente-entro-12-motore',
      title: 'Patente nautica entro 12 miglia motore',
      description: 'Percorso standard patente entro 12 miglia — modulo motore.',
      practiceType: 'new_license',
      enrolledCoursePath: 'entro_12_miglia',
      enrolledLicenseCategory: 'motore',
      defaultRegistrationFeeCents: 0,
      suggestedDepositCents: 0,
      internalNotes: 'Da configurare: importo totale e acconto consigliato.',
      sortOrder: 10,
    ),
    PracticeServiceTemplate(
      id: 'mock-template-oltre-12-motore',
      slug: 'patente-oltre-12-motore',
      title: 'Patente nautica oltre 12 miglia motore',
      description:
          'Percorso oltre 12 miglia con focus operativo motore (catalogo vela/motore).',
      practiceType: 'new_license',
      enrolledCoursePath: 'entro_12_miglia_vela',
      enrolledLicenseCategory: 'motore',
      defaultRegistrationFeeCents: 0,
      suggestedDepositCents: 0,
      internalNotes: 'Da configurare: verificare percorso iscrizione e importi.',
      sortOrder: 20,
    ),
    PracticeServiceTemplate(
      id: 'mock-template-d1',
      slug: 'patente-d1',
      title: 'Patente nautica D1',
      description: 'Percorso patente D1.',
      practiceType: 'new_license',
      enrolledCoursePath: 'd1',
      enrolledLicenseCategory: 'd1',
      defaultRegistrationFeeCents: 0,
      suggestedDepositCents: 0,
      internalNotes: 'Da configurare: importo totale e acconto consigliato.',
      sortOrder: 30,
    ),
    PracticeServiceTemplate(
      id: 'mock-template-rinnovo',
      slug: 'rinnovo-patente-nautica',
      title: 'Rinnovo patente nautica',
      description: 'Pratica di rinnovo patente nautica.',
      practiceType: 'renewal',
      defaultRegistrationFeeCents: 0,
      suggestedDepositCents: 0,
      internalNotes: 'Da configurare: importo e note operative rinnovo.',
      sortOrder: 40,
    ),
    PracticeServiceTemplate(
      id: 'mock-template-duplicato',
      slug: 'duplicato-patente-nautica',
      title: 'Duplicato patente nautica',
      description: 'Richiesta duplicato documento di patente nautica.',
      practiceType: 'duplicate',
      defaultRegistrationFeeCents: 0,
      suggestedDepositCents: 0,
      internalNotes: 'Da configurare: importo e documenti richiesti.',
      sortOrder: 50,
    ),
    PracticeServiceTemplate(
      id: 'mock-template-integrazione',
      slug: 'integrazione-estensione-patente',
      title: 'Integrazione / estensione patente nautica',
      description: 'Pratica di integrazione o estensione titolo nautico.',
      practiceType: 'other',
      defaultRegistrationFeeCents: 0,
      suggestedDepositCents: 0,
      internalNotes: 'Da configurare: tipologia e importo.',
      sortOrder: 60,
    ),
    PracticeServiceTemplate(
      id: 'mock-template-generica',
      slug: 'pratica-nautica-generica',
      title: 'Pratica nautica generica',
      description: 'Prestazione generica non classificata nel catalogo standard.',
      practiceType: 'other',
      defaultRegistrationFeeCents: 0,
      suggestedDepositCents: 0,
      internalNotes: 'Da configurare.',
      sortOrder: 70,
    ),
    PracticeServiceTemplate(
      id: 'mock-template-altro',
      slug: 'altro-servizio-nautico',
      title: 'Altro servizio nautico',
      description: 'Altre prestazioni o servizi nautici della scuola.',
      practiceType: 'other',
      defaultRegistrationFeeCents: 0,
      suggestedDepositCents: 0,
      internalNotes: 'Da configurare.',
      sortOrder: 80,
    ),
  ];

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

  static List<NauticalExpense> _demoExpensesSeed() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return [
      NauticalExpense(
        id: 'mock-expense-benzina-1',
        title: 'Rifornimento barca scuola',
        amountCents: 12500,
        expenseDate: today.subtract(const Duration(days: 2)),
        categoryId: 'mock-expense-benzina',
        notes: 'Demo locale — benzina',
      ),
      NauticalExpense(
        id: 'mock-expense-istruttore-1',
        title: 'Compenso guida maggio',
        amountCents: 18000,
        expenseDate: today.subtract(const Duration(days: 8)),
        categoryId: 'mock-expense-pagamento-istruttori',
      ),
      NauticalExpense(
        id: 'mock-expense-pontile-1',
        title: 'Canone pontile mensile',
        amountCents: 45000,
        expenseDate: DateTime(now.year, now.month, 5),
        categoryId: 'mock-expense-affitto-pontile',
        notes: 'Demo locale — affitto pontile',
      ),
    ];
  }

  @override
  Future<List<NauticalExpense>> listExpenses({
    DateTime? from,
    DateTime? to,
  }) async {
    var list = List<NauticalExpense>.from(_expenses);
    if (from != null) {
      final f = DateTime(from.year, from.month, from.day);
      list = list
          .where((e) => !e.expenseDate.isBefore(f))
          .toList(growable: false);
    }
    if (to != null) {
      final t = DateTime(to.year, to.month, to.day);
      list = list
          .where((e) => !e.expenseDate.isAfter(t))
          .toList(growable: false);
    }
    list.sort((a, b) => b.expenseDate.compareTo(a.expenseDate));
    return List<NauticalExpense>.unmodifiable(list);
  }

  @override
  Future<NauticalExpense> createExpense(ExpenseCreateInput input) async {
    final title = input.title.trim();
    if (title.isEmpty) {
      throw ArgumentError('Il titolo dell\'uscita è obbligatorio.');
    }
    if (input.amountCents <= 0) {
      throw ArgumentError.value(
        input.amountCents,
        'amountCents',
        'must be > 0',
      );
    }

    _mockExpenseIdSeq += 1;
    final expense = NauticalExpense(
      id: 'mock-expense-$_mockExpenseIdSeq',
      title: title,
      amountCents: input.amountCents,
      expenseDate: DateTime(
        input.expenseDate.year,
        input.expenseDate.month,
        input.expenseDate.day,
      ),
      categoryId: input.categoryId,
      instructorId: input.instructorId,
      notes: input.notes?.trim().isEmpty ?? true ? null : input.notes!.trim(),
    );
    _expenses.add(expense);
    return expense;
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

  @override
  Future<List<PracticeServiceTemplate>> listPracticeServiceTemplates({
    bool includeInactive = true,
  }) async {
    final list = includeInactive
        ? _practiceServiceTemplates
        : _practiceServiceTemplates.where((t) => t.active);
    final sorted = list.toList()
      ..sort((a, b) {
        final c = a.sortOrder.compareTo(b.sortOrder);
        if (c != 0) return c;
        return a.title.compareTo(b.title);
      });
    return List<PracticeServiceTemplate>.unmodifiable(sorted);
  }

  @override
  Future<PracticeServiceTemplate> createPracticeServiceTemplate(
    PracticeServiceTemplateInput input,
  ) async {
    final created = PracticeServiceTemplate(
      id: _nextMockId(),
      slug: input.slug.trim(),
      title: input.title.trim(),
      description: input.description?.trim(),
      practiceType: input.practiceType,
      enrolledCoursePath: _nullableTrim(input.enrolledCoursePath),
      enrolledLicenseCategory: _nullableTrim(input.enrolledLicenseCategory),
      defaultRegistrationFeeCents: input.defaultRegistrationFeeCents,
      suggestedDepositCents: input.suggestedDepositCents,
      internalNotes: input.internalNotes?.trim(),
      active: input.active,
      sortOrder: input.sortOrder,
    );
    _practiceServiceTemplates.add(created);
    return created;
  }

  @override
  Future<PracticeServiceTemplate> updatePracticeServiceTemplate(
    String id,
    PracticeServiceTemplateInput input,
  ) async {
    final index = _practiceServiceTemplates.indexWhere((t) => t.id == id);
    if (index < 0) {
      throw StateError('Prestazione non trovata.');
    }
    final updated = PracticeServiceTemplate(
      id: id,
      slug: input.slug.trim(),
      title: input.title.trim(),
      description: input.description?.trim(),
      practiceType: input.practiceType,
      enrolledCoursePath: _nullableTrim(input.enrolledCoursePath),
      enrolledLicenseCategory: _nullableTrim(input.enrolledLicenseCategory),
      defaultRegistrationFeeCents: input.defaultRegistrationFeeCents,
      suggestedDepositCents: input.suggestedDepositCents,
      internalNotes: input.internalNotes?.trim(),
      active: input.active,
      sortOrder: input.sortOrder,
    );
    _practiceServiceTemplates[index] = updated;
    return updated;
  }

  @override
  Future<void> setPracticeServiceTemplateActive(String id, bool active) async {
    final index = _practiceServiceTemplates.indexWhere((t) => t.id == id);
    if (index < 0) {
      throw StateError('Prestazione non trovata.');
    }
    _practiceServiceTemplates[index] =
        _practiceServiceTemplates[index].copyWith(active: active);
  }

  @override
  Future<void> deletePracticeServiceTemplate(String id) async {
    final removed =
        _practiceServiceTemplates.where((t) => t.id == id).toList(growable: false);
    if (removed.isEmpty) {
      throw StateError('Prestazione non trovata.');
    }
    _practiceServiceTemplates.removeWhere((t) => t.id == id);
  }

  String? _nullableTrim(String? value) {
    final t = value?.trim();
    if (t == null || t.isEmpty) return null;
    return t;
  }
}
