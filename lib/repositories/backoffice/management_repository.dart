import '../../domain/backoffice/backoffice.dart';

abstract class ManagementRepository {
  Future<List<NauticalInstructor>> listInstructors();

  Future<List<ExpenseCategory>> listExpenseCategories();

  Future<List<NauticalExpense>> listExpenses({DateTime? from, DateTime? to});

  Future<NauticalExpense> createExpense(ExpenseCreateInput input);

  Future<NauticalExpense> updateExpense(String id, ExpenseCreateInput input);

  Future<void> deleteExpense(String id);

  Future<List<ExtraProduct>> listExtraProducts({bool includeInactive = false});

  Future<List<ExtraVideoItem>> listExtraVideoItems(
    String productId, {
    bool includeInactive = false,
  });

  Future<ExtraVideoItem> createExtraVideoItem(ExtraVideoItemInput input);

  Future<ExtraVideoItem> updateExtraVideoItem(
    String id,
    ExtraVideoItemInput input,
  );

  Future<void> setExtraVideoItemActive(String id, bool active);

  /// Sposta un video da un prodotto a un altro (es. legacy `ex-bundle` → `ex-theory`).
  Future<ExtraVideoItem> moveExtraVideoItemToProduct({
    required String videoId,
    required String targetProductId,
  });

  Future<Set<String>> listPurchasedExtraProductIds(StudentId studentId);

  Future<void> grantStudentExtraProductAccess({
    required StudentId studentId,
    required String productId,
  });

  Future<void> revokeStudentExtraProductAccess({
    required StudentId studentId,
    required String productId,
  });

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

  Future<void> deletePracticeServiceTemplate(String id);
}
