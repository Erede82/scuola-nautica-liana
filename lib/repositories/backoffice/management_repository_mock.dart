import '../../constants/extra_content_ids.dart';
import '../../data/extra_bundle_catalog.dart';
import '../../domain/backoffice/backoffice.dart';
import 'management_repository.dart';

class ManagementRepositoryMock implements ManagementRepository {
  final Set<String> _purchasedExtraProductIds = <String>{};
  final List<StudentExtraPurchase> _studentExtraPurchases =
      List<StudentExtraPurchase>.from(_seedStudentExtraPurchases);
  final List<ExtraVideoItem> _extraVideoItems = <ExtraVideoItem>[];
  static int _mockVideoIdSeq = 0;
  final List<PracticeServiceTemplate> _practiceServiceTemplates =
      List<PracticeServiceTemplate>.from(_seedPracticeServiceTemplates);
  final List<NauticalExpense> _expenses = List<NauticalExpense>.from(
    _demoExpensesSeed(),
  );

  static int _mockIdSeq = 0;
  static int _mockExpenseIdSeq = 0;

  static String _nextMockId() {
    _mockIdSeq += 1;
    return 'mock-practice-template-$_mockIdSeq';
  }

  static final List<StudentExtraPurchase> _seedStudentExtraPurchases = [
    StudentExtraPurchase(
      id: 'mock-purchase-theory',
      studentId: 'demo-student',
      productId: ExtraContentIds.extraTeoria,
      status: StudentExtraPurchaseStatus.purchased,
      purchasedAt: DateTime.utc(2026, 3, 10, 14, 30),
      amountCents: 4900,
      paymentReference: '59113d81-67f6-407a-a8c0-7788bb2176e0',
      orderCode: 'ONL-2026-00004',
      orderProductId: ExtraContentIds.extraTeoria,
    ),
    StudentExtraPurchase(
      id: 'mock-purchase-chart-staff',
      studentId: 'demo-student',
      productId: ExtraContentIds.extraCarteggio,
      status: StudentExtraPurchaseStatus.purchased,
      purchasedAt: DateTime.utc(2026, 3, 12, 9, 15),
      recordedByStaffId: 'mock-staff-user',
    ),
  ];

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
      internalNotes:
          'Da configurare: verificare percorso iscrizione e importi.',
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
      description:
          'Prestazione generica non classificata nel catalogo standard.',
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
        paymentMethod: PaymentMethod.card,
        receiptReference: 'SCN-2026-0142',
        notes: 'Demo locale — benzina',
      ),
      NauticalExpense(
        id: 'mock-expense-istruttore-1',
        title: 'Compenso guida maggio',
        amountCents: 18000,
        expenseDate: today.subtract(const Duration(days: 8)),
        categoryId: 'mock-expense-pagamento-istruttori',
        paymentMethod: PaymentMethod.cash,
      ),
      NauticalExpense(
        id: 'mock-expense-pontile-1',
        title: 'Canone pontile mensile',
        amountCents: 45000,
        expenseDate: DateTime(now.year, now.month, 5),
        categoryId: 'mock-expense-affitto-pontile',
        paymentMethod: PaymentMethod.other,
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
      paymentMethod: input.paymentMethod,
      receiptReference: input.receiptReference?.trim().isEmpty ?? true
          ? null
          : input.receiptReference!.trim(),
      notes: input.notes?.trim().isEmpty ?? true ? null : input.notes!.trim(),
    );
    _expenses.add(expense);
    return expense;
  }

  @override
  Future<NauticalExpense> updateExpense(
    String id,
    ExpenseCreateInput input,
  ) async {
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

    final index = _expenses.indexWhere((e) => e.id == id);
    if (index < 0) {
      throw StateError('Uscita non trovata: $id');
    }

    final previous = _expenses[index];
    final updated = NauticalExpense(
      id: previous.id,
      title: title,
      amountCents: input.amountCents,
      expenseDate: DateTime(
        input.expenseDate.year,
        input.expenseDate.month,
        input.expenseDate.day,
      ),
      categoryId: input.categoryId,
      instructorId: input.instructorId,
      currencyCode: previous.currencyCode,
      paymentMethod: input.paymentMethod,
      receiptReference: input.receiptReference?.trim().isEmpty ?? true
          ? null
          : input.receiptReference!.trim(),
      notes: input.notes?.trim().isEmpty ?? true ? null : input.notes!.trim(),
    );
    _expenses[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteExpense(String id) async {
    final index = _expenses.indexWhere((e) => e.id == id);
    if (index < 0) {
      throw StateError('Uscita non trovata: $id');
    }
    _expenses.removeAt(index);
  }

  @override
  Future<List<ExtraProduct>> listExtraProducts({
    bool includeInactive = false,
  }) async {
    final list = includeInactive
        ? _extraProducts
        : _extraProducts.where((p) => p.active);
    return List<ExtraProduct>.unmodifiable(list);
  }

  static String _nextVideoId() {
    _mockVideoIdSeq += 1;
    return 'mock-extra-video-$_mockVideoIdSeq';
  }

  @override
  Future<List<ExtraVideoItem>> listExtraVideoItems(
    String productId, {
    bool includeInactive = false,
  }) async {
    final list = _extraVideoItems.where((v) => v.productId == productId);
    final filtered = includeInactive ? list : list.where((v) => v.active);
    final sorted = filtered.toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return List<ExtraVideoItem>.unmodifiable(sorted);
  }

  @override
  Future<ExtraVideoItem> createExtraVideoItem(ExtraVideoItemInput input) async {
    final item = ExtraVideoItem(
      id: _nextVideoId(),
      productId: input.productId,
      title: input.title.trim(),
      description: input.description?.trim(),
      videoUrl: input.videoUrl?.trim(),
      durationSeconds: input.durationSeconds,
      sortOrder: input.sortOrder,
      active: input.active,
    );
    _extraVideoItems.add(item);
    return item;
  }

  @override
  Future<ExtraVideoItem> updateExtraVideoItem(
    String id,
    ExtraVideoItemInput input,
  ) async {
    final index = _extraVideoItems.indexWhere((v) => v.id == id);
    if (index < 0) {
      throw StateError('Video non trovato: $id');
    }
    final updated = ExtraVideoItem(
      id: id,
      productId: input.productId,
      title: input.title.trim(),
      description: input.description?.trim(),
      videoUrl: input.videoUrl?.trim(),
      durationSeconds: input.durationSeconds,
      sortOrder: input.sortOrder,
      active: input.active,
    );
    _extraVideoItems[index] = updated;
    return updated;
  }

  @override
  Future<void> setExtraVideoItemActive(String id, bool active) async {
    final index = _extraVideoItems.indexWhere((v) => v.id == id);
    if (index < 0) {
      throw StateError('Video non trovato: $id');
    }
    final current = _extraVideoItems[index];
    _extraVideoItems[index] = ExtraVideoItem(
      id: current.id,
      productId: current.productId,
      title: current.title,
      description: current.description,
      videoUrl: current.videoUrl,
      durationSeconds: current.durationSeconds,
      sortOrder: current.sortOrder,
      active: active,
    );
  }

  @override
  Future<ExtraVideoItem> moveExtraVideoItemToProduct({
    required String videoId,
    required String targetProductId,
  }) async {
    if (!ExtraBundleCatalog.isValidMoveTarget(targetProductId)) {
      throw ArgumentError('Destinazione non valida: $targetProductId');
    }
    final index = _extraVideoItems.indexWhere((v) => v.id == videoId);
    if (index < 0) {
      throw StateError('Video non trovato: $videoId');
    }
    final current = _extraVideoItems[index];
    final moved = ExtraVideoItem(
      id: current.id,
      productId: targetProductId,
      title: current.title,
      description: current.description,
      videoUrl: current.videoUrl,
      durationSeconds: current.durationSeconds,
      sortOrder: current.sortOrder,
      active: current.active,
    );
    _extraVideoItems[index] = moved;
    return moved;
  }

  @override
  Future<Set<String>> listPurchasedExtraProductIds(StudentId studentId) async {
    return Set<String>.unmodifiable(_purchasedExtraProductIds);
  }

  @override
  Future<List<StudentExtraPurchase>> listStudentExtraPurchases(
    StudentId studentId,
  ) async {
    return List<StudentExtraPurchase>.unmodifiable(
      _studentExtraPurchases
          .where((p) => p.studentId == studentId)
          .toList(growable: false),
    );
  }

  @override
  Future<void> grantStudentExtraProductAccess({
    required StudentId studentId,
    required String productId,
  }) async {
    for (final id in ExtraBundleCatalog.productsToGrantOnAccess(productId)) {
      _purchasedExtraProductIds.add(id);
    }
  }

  @override
  Future<void> revokeStudentExtraProductAccess({
    required StudentId studentId,
    required String productId,
  }) async {
    _purchasedExtraProductIds.remove(productId);
  }

  @override
  Future<ExtraProductCheckoutOutcome> startExtraProductCheckout({
    required StudentId studentId,
    required String productId,
    int? amountCents,
    String currencyCode = 'EUR',
    String? paymentReference,
  }) async {
    _purchasedExtraProductIds.add(productId);
    return const ExtraProductCheckoutOutcome.demoUnlocked();
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
    _practiceServiceTemplates[index] = _practiceServiceTemplates[index]
        .copyWith(active: active);
  }

  @override
  Future<void> deletePracticeServiceTemplate(String id) async {
    final removed = _practiceServiceTemplates
        .where((t) => t.id == id)
        .toList(growable: false);
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
