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
        .select(
          'id, title, amount_cents, expense_date, category_id, '
          'instructor_id, currency_code, notes',
        );

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
    );
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
}
