import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/supabase_config.dart';
import '../../domain/backoffice/backoffice.dart';
import 'management_repository.dart';

class ManagementRepositorySupabase implements ManagementRepository {
  ManagementRepositorySupabase._();

  static final ManagementRepositorySupabase instance =
      ManagementRepositorySupabase._();

  SupabaseClient get _client {
    if (!SupabaseConfig.isConfigured) {
      throw StateError('Supabase non configurato.');
    }
    return Supabase.instance.client;
  }

  @override
  Future<List<NauticalInstructor>> listInstructors() async {
    final rows = await _client
        .from('instructors')
        .select('id, display_name, slug, active')
        .eq('active', true)
        .order('display_name');
    return (rows as List<dynamic>)
        .map((row) => _mapInstructor(Map<String, dynamic>.from(row as Map)))
        .toList(growable: false);
  }

  @override
  Future<List<ExpenseCategory>> listExpenseCategories() async {
    final rows = await _client
        .from('expense_categories')
        .select('id, name, slug, sort_order, active')
        .eq('active', true)
        .order('sort_order')
        .order('name');
    return (rows as List<dynamic>)
        .map(
          (row) => _mapExpenseCategory(Map<String, dynamic>.from(row as Map)),
        )
        .toList(growable: false);
  }

  @override
  Future<List<NauticalExpense>> listExpenses({
    DateTime? from,
    DateTime? to,
  }) async {
    var query = _client
        .from('expenses')
        .select(_expenseSelect);

    if (from != null) {
      query = query.gte('expense_date', _dateOnly(from));
    }
    if (to != null) {
      query = query.lte('expense_date', _dateOnly(to));
    }

    final rows = await query.order('expense_date', ascending: false);
    return (rows as List<dynamic>)
        .map((row) => _mapExpense(Map<String, dynamic>.from(row as Map)))
        .toList(growable: false);
  }

  static const _expenseSelect =
      'id, title, amount_cents, expense_date, category_id, '
      'instructor_id, currency_code, notes, payment_method, receipt_reference';

  @override
  Future<NauticalExpense> createExpense(ExpenseCreateInput input) async {
    _validateExpenseInput(input);

    final payload = _expensePayload(input)
      ..['currency_code'] = 'EUR'
      ..['recorded_by_staff_id'] = _client.auth.currentUser?.id;

    final row = await _client
        .from('expenses')
        .insert(payload)
        .select(_expenseSelect)
        .single();

    return _mapExpense(Map<String, dynamic>.from(row));
  }

  @override
  Future<NauticalExpense> updateExpense(
    String id,
    ExpenseCreateInput input,
  ) async {
    _validateExpenseInput(input);

    final row = await _client
        .from('expenses')
        .update(_expensePayload(input))
        .eq('id', id)
        .select(_expenseSelect)
        .single();

    return _mapExpense(Map<String, dynamic>.from(row));
  }

  void _validateExpenseInput(ExpenseCreateInput input) {
    if (input.title.trim().isEmpty) {
      throw ArgumentError('Il titolo dell\'uscita è obbligatorio.');
    }
    if (input.amountCents <= 0) {
      throw ArgumentError.value(
        input.amountCents,
        'amountCents',
        'must be > 0',
      );
    }
  }

  Map<String, dynamic> _expensePayload(ExpenseCreateInput input) {
    final title = input.title.trim();
    final receipt = input.receiptReference?.trim();
    final notes = input.notes?.trim();

    return <String, dynamic>{
      'title': title,
      'amount_cents': input.amountCents,
      'expense_date': _dateOnly(input.expenseDate),
      'category_id': input.categoryId,
      'payment_method': input.paymentMethod.name,
      'receipt_reference':
          receipt != null && receipt.isNotEmpty ? receipt : null,
      'notes': notes != null && notes.isNotEmpty ? notes : null,
      'instructor_id': input.instructorId,
    };
  }

  @override
  Future<List<ExtraProduct>> listExtraProducts() async {
    final rows = await _client
        .from('extra_products')
        .select(
          'id, title, subtitle, description, price_cents, '
          'currency_code, active, sort_order',
        )
        .eq('active', true)
        .order('sort_order');
    return (rows as List<dynamic>)
        .map((row) => _mapExtraProduct(Map<String, dynamic>.from(row as Map)))
        .toList(growable: false);
  }

  @override
  Future<List<ExtraVideoItem>> listExtraVideoItems(String productId) async {
    final rows = await _client
        .from('extra_video_items')
        .select(
          'id, product_id, title, description, video_url, '
          'duration_seconds, sort_order, active',
        )
        .eq('product_id', productId)
        .eq('active', true)
        .order('sort_order');
    return (rows as List<dynamic>)
        .map((row) => _mapExtraVideoItem(Map<String, dynamic>.from(row as Map)))
        .toList(growable: false);
  }

  @override
  Future<Set<String>> listPurchasedExtraProductIds(StudentId studentId) async {
    final rows = await _client
        .from('student_extra_purchases')
        .select('product_id')
        .eq('student_id', studentId)
        .eq('status', StudentExtraPurchaseStatus.purchased.name);
    return (rows as List<dynamic>)
        .map((row) => (row as Map)['product_id'] as String)
        .toSet();
  }

  @override
  Future<bool> startExtraProductCheckout({
    required StudentId studentId,
    required String productId,
    int? amountCents,
    String currencyCode = 'EUR',
    String? paymentReference,
  }) async {
    // Production safety: the app can start checkout, but only PSP webhook/server
    // side confirmation may write student_extra_purchases.
    return false;
  }

  NauticalInstructor _mapInstructor(Map<String, dynamic> row) {
    return NauticalInstructor(
      id: row['id'] as String,
      displayName: row['display_name'] as String,
      slug: row['slug'] as String,
      active: row['active'] as bool? ?? true,
    );
  }

  ExpenseCategory _mapExpenseCategory(Map<String, dynamic> row) {
    return ExpenseCategory(
      id: row['id'] as String,
      name: row['name'] as String,
      slug: row['slug'] as String,
      sortOrder: row['sort_order'] as int? ?? 0,
      active: row['active'] as bool? ?? true,
    );
  }

  NauticalExpense _mapExpense(Map<String, dynamic> row) {
    return NauticalExpense(
      id: row['id'] as String,
      title: row['title'] as String,
      amountCents: row['amount_cents'] as int,
      expenseDate: DateTime.parse(row['expense_date'] as String),
      categoryId: row['category_id'] as String?,
      instructorId: row['instructor_id'] as String?,
      currencyCode: row['currency_code'] as String? ?? 'EUR',
      notes: row['notes'] as String?,
      paymentMethod: _parsePaymentMethod(row['payment_method'] as String?),
      receiptReference: row['receipt_reference'] as String?,
    );
  }

  PaymentMethod? _parsePaymentMethod(String? raw) {
    if (raw == null) return null;
    for (final v in PaymentMethod.values) {
      if (v.name == raw) return v;
    }
    return PaymentMethod.other;
  }

  ExtraProduct _mapExtraProduct(Map<String, dynamic> row) {
    return ExtraProduct(
      id: row['id'] as String,
      title: row['title'] as String,
      subtitle: row['subtitle'] as String?,
      description: row['description'] as String?,
      priceCents: row['price_cents'] as int?,
      currencyCode: row['currency_code'] as String? ?? 'EUR',
      active: row['active'] as bool? ?? true,
      sortOrder: row['sort_order'] as int? ?? 0,
    );
  }

  ExtraVideoItem _mapExtraVideoItem(Map<String, dynamic> row) {
    return ExtraVideoItem(
      id: row['id'] as String,
      productId: row['product_id'] as String,
      title: row['title'] as String,
      description: row['description'] as String?,
      videoUrl: row['video_url'] as String?,
      durationSeconds: row['duration_seconds'] as int?,
      sortOrder: row['sort_order'] as int? ?? 0,
      active: row['active'] as bool? ?? true,
    );
  }

  String _dateOnly(DateTime value) {
    final date = value.toLocal();
    return DateTime(
      date.year,
      date.month,
      date.day,
    ).toIso8601String().split('T').first;
  }

  static const _templateSelect =
      'id, slug, title, description, practice_type, enrolled_course_path, '
      'enrolled_license_category, default_registration_fee_cents, '
      'suggested_deposit_cents, internal_notes, active, sort_order';

  @override
  Future<List<PracticeServiceTemplate>> listPracticeServiceTemplates({
    bool includeInactive = true,
  }) async {
    var query = _client.from('practice_service_templates').select(_templateSelect);
    if (!includeInactive) {
      query = query.eq('active', true);
    }
    final rows = await query.order('sort_order').order('title');
    return (rows as List<dynamic>)
        .map((row) => _mapTemplate(Map<String, dynamic>.from(row as Map)))
        .toList(growable: false);
  }

  @override
  Future<PracticeServiceTemplate> createPracticeServiceTemplate(
    PracticeServiceTemplateInput input,
  ) async {
    final row = await _client
        .from('practice_service_templates')
        .insert(_templatePayload(input))
        .select(_templateSelect)
        .single();
    return _mapTemplate(Map<String, dynamic>.from(row));
  }

  @override
  Future<PracticeServiceTemplate> updatePracticeServiceTemplate(
    String id,
    PracticeServiceTemplateInput input,
  ) async {
    final row = await _client
        .from('practice_service_templates')
        .update(_templatePayload(input))
        .eq('id', id)
        .select(_templateSelect)
        .single();
    return _mapTemplate(Map<String, dynamic>.from(row));
  }

  @override
  Future<void> setPracticeServiceTemplateActive(String id, bool active) async {
    await _client
        .from('practice_service_templates')
        .update(<String, dynamic>{'active': active})
        .eq('id', id);
  }

  @override
  Future<void> deletePracticeServiceTemplate(String id) async {
    try {
      await _client.from('practice_service_templates').delete().eq('id', id);
    } on PostgrestException catch (e) {
      final code = e.code ?? '';
      if (code == '23503' ||
          e.message.toLowerCase().contains('foreign key') ||
          e.message.toLowerCase().contains('violates')) {
        throw StateError(
          'Impossibile eliminare: la prestazione è collegata ad altri dati.',
        );
      }
      throw StateError(e.message);
    }
  }

  Map<String, dynamic> _templatePayload(PracticeServiceTemplateInput input) {
    final payload = <String, dynamic>{
      'slug': input.slug.trim(),
      'title': input.title.trim(),
      'practice_type': input.practiceType,
      'default_registration_fee_cents': input.defaultRegistrationFeeCents,
      'suggested_deposit_cents': input.suggestedDepositCents,
      'active': input.active,
      'sort_order': input.sortOrder,
    };
    final desc = input.description?.trim();
    if (desc != null && desc.isNotEmpty) {
      payload['description'] = desc;
    } else {
      payload['description'] = null;
    }
    final notes = input.internalNotes?.trim();
    if (notes != null && notes.isNotEmpty) {
      payload['internal_notes'] = notes;
    } else {
      payload['internal_notes'] = null;
    }
    payload['enrolled_course_path'] = _nullableTrim(input.enrolledCoursePath);
    payload['enrolled_license_category'] =
        _nullableTrim(input.enrolledLicenseCategory);
    return payload;
  }

  String? _nullableTrim(String? value) {
    final t = value?.trim();
    if (t == null || t.isEmpty) return null;
    return t;
  }

  PracticeServiceTemplate _mapTemplate(Map<String, dynamic> row) {
    return PracticeServiceTemplate(
      id: row['id'] as String,
      slug: row['slug'] as String,
      title: row['title'] as String,
      description: row['description'] as String?,
      practiceType: row['practice_type'] as String,
      enrolledCoursePath: row['enrolled_course_path'] as String?,
      enrolledLicenseCategory: row['enrolled_license_category'] as String?,
      defaultRegistrationFeeCents:
          (row['default_registration_fee_cents'] as num?)?.toInt() ?? 0,
      suggestedDepositCents:
          (row['suggested_deposit_cents'] as num?)?.toInt() ?? 0,
      internalNotes: row['internal_notes'] as String?,
      active: row['active'] as bool? ?? true,
      sortOrder: row['sort_order'] as int? ?? 0,
    );
  }
}
