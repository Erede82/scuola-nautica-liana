import '../../domain/backoffice/backoffice.dart';

abstract class ManagementRepository {
  Future<List<NauticalInstructor>> listInstructors();

  Future<List<ExpenseCategory>> listExpenseCategories();

  Future<List<NauticalExpense>> listExpenses({DateTime? from, DateTime? to});

  Future<List<ExtraProduct>> listExtraProducts();

  Future<List<ExtraVideoItem>> listExtraVideoItems(String productId);

  Future<Set<String>> listPurchasedExtraProductIds(StudentId studentId);

  /// Starts the Extra checkout flow.
  ///
  /// Returns true only when the local/dev implementation can unlock immediately.
  /// Supabase production must never unlock from the client: purchases are read
  /// from student_extra_purchases after PSP webhook/RPC confirmation.
  Future<bool> startExtraProductCheckout({
    required StudentId studentId,
    required String productId,
    int? amountCents,
    String currencyCode = 'EUR',
    String? paymentReference,
  });

  Future<List<PracticeServiceTemplate>> listPracticeServiceTemplates({
    bool includeInactive = true,
  });

  Future<PracticeServiceTemplate> createPracticeServiceTemplate(
    PracticeServiceTemplateInput input,
  );

  Future<PracticeServiceTemplate> updatePracticeServiceTemplate(
    String id,
    PracticeServiceTemplateInput input,
  );

  Future<void> setPracticeServiceTemplateActive(String id, bool active);
}
