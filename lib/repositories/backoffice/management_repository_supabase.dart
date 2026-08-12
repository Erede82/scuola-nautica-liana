import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/supabase_config.dart';
import '../../data/extra_bundle_catalog.dart';
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
    var query = _client.from('expenses').select(_expenseSelect);

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

  @override
  Future<void> deleteExpense(String id) async {
    await _client.from('expenses').delete().eq('id', id);
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
      'receipt_reference': receipt != null && receipt.isNotEmpty
          ? receipt
          : null,
      'notes': notes != null && notes.isNotEmpty ? notes : null,
      'instructor_id': input.instructorId,
    };
  }

  @override
  Future<List<ExtraProduct>> listExtraProducts({
    bool includeInactive = false,
  }) async {
    var query = _client
        .from('extra_products')
        .select(
          'id, title, subtitle, description, price_cents, '
          'currency_code, active, sort_order',
        );
    if (!includeInactive) {
      query = query.eq('active', true);
    }
    final rows = await query.order('sort_order');
    return (rows as List<dynamic>)
        .map((row) => _mapExtraProduct(Map<String, dynamic>.from(row as Map)))
        .toList(growable: false);
  }

  static const _videoItemSelect =
      'id, product_id, title, description, video_url, '
      'duration_seconds, sort_order, active';

  @override
  Future<List<ExtraVideoItem>> listExtraVideoItems(
    String productId, {
    bool includeInactive = false,
  }) async {
    var query = _client
        .from('extra_video_items')
        .select(_videoItemSelect)
        .eq('product_id', productId);
    if (!includeInactive) {
      query = query.eq('active', true);
    }
    final rows = await query.order('sort_order');
    return (rows as List<dynamic>)
        .map((row) => _mapExtraVideoItem(Map<String, dynamic>.from(row as Map)))
        .toList(growable: false);
  }

  @override
  Future<ExtraVideoItem> createExtraVideoItem(ExtraVideoItemInput input) async {
    _validateExtraVideoInput(input);
    final row = await _client
        .from('extra_video_items')
        .insert(_extraVideoPayload(input))
        .select(_videoItemSelect)
        .single();
    return _mapExtraVideoItem(Map<String, dynamic>.from(row));
  }

  @override
  Future<ExtraVideoItem> updateExtraVideoItem(
    String id,
    ExtraVideoItemInput input,
  ) async {
    _validateExtraVideoInput(input);
    final row = await _client
        .from('extra_video_items')
        .update(_extraVideoPayload(input))
        .eq('id', id)
        .select(_videoItemSelect)
        .single();
    return _mapExtraVideoItem(Map<String, dynamic>.from(row));
  }

  @override
  Future<void> setExtraVideoItemActive(String id, bool active) async {
    await _client
        .from('extra_video_items')
        .update(<String, dynamic>{'active': active})
        .eq('id', id);
  }

  @override
  Future<ExtraVideoItem> moveExtraVideoItemToProduct({
    required String videoId,
    required String targetProductId,
  }) async {
    if (!ExtraBundleCatalog.isValidMoveTarget(targetProductId)) {
      throw ArgumentError(
        'Destinazione non valida: $targetProductId. '
        'Usa teoria, carteggio o guida.',
      );
    }
    final row = await _client
        .from('extra_video_items')
        .update(<String, dynamic>{'product_id': targetProductId})
        .eq('id', videoId)
        .select(_videoItemSelect)
        .single();
    return _mapExtraVideoItem(Map<String, dynamic>.from(row));
  }

  void _validateExtraVideoInput(ExtraVideoItemInput input) {
    if (input.title.trim().isEmpty) {
      throw ArgumentError('Il titolo del video è obbligatorio.');
    }
    final url = input.videoUrl?.trim();
    if (url == null || url.isEmpty) {
      throw ArgumentError('L\'URL del video è obbligatorio.');
    }
  }

  Map<String, dynamic> _extraVideoPayload(ExtraVideoItemInput input) {
    final title = input.title.trim();
    final url = input.videoUrl?.trim();
    final desc = input.description?.trim();
    return <String, dynamic>{
      'product_id': input.productId,
      'title': title,
      'description': desc != null && desc.isNotEmpty ? desc : null,
      'video_url': url,
      'duration_seconds': input.durationSeconds,
      'sort_order': input.sortOrder,
      'active': input.active,
    };
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
  Future<List<StudentExtraPurchase>> listStudentExtraPurchases(
    StudentId studentId,
  ) async {
    final rows = await _client
        .from('student_extra_purchases')
        .select(
          'id, student_id, product_id, status, purchased_at, amount_cents, '
          'currency_code, payment_reference, recorded_by_staff_id',
        )
        .eq('student_id', studentId)
        .order('purchased_at', ascending: false);

    final purchases = (rows as List<dynamic>)
        .map(
          (row) =>
              _mapStudentExtraPurchase(Map<String, dynamic>.from(row as Map)),
        )
        .toList(growable: false);

    final orderIds = purchases
        .map((p) => p.paymentReference?.trim())
        .whereType<String>()
        .where((ref) => ref.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (orderIds.isEmpty) {
      return purchases;
    }

    final orderRows = await _client
        .from('online_orders')
        .select('id, order_code, product_id')
        .eq('student_id', studentId)
        .inFilter('id', orderIds);

    final orderById = <String, ({String orderCode, String? productId})>{};
    for (final raw in orderRows as List<dynamic>) {
      final map = Map<String, dynamic>.from(raw as Map);
      final id = map['id'] as String?;
      if (id == null) continue;
      orderById[id] = (
        orderCode: map['order_code'] as String? ?? '',
        productId: map['product_id'] as String?,
      );
    }

    return purchases
        .map((purchase) {
          final ref = purchase.paymentReference?.trim();
          if (ref == null || ref.isEmpty) return purchase;
          final order = orderById[ref];
          if (order == null) return purchase;
          return StudentExtraPurchase(
            id: purchase.id,
            studentId: purchase.studentId,
            productId: purchase.productId,
            status: purchase.status,
            purchasedAt: purchase.purchasedAt,
            amountCents: purchase.amountCents,
            currencyCode: purchase.currencyCode,
            paymentReference: purchase.paymentReference,
            recordedByStaffId: purchase.recordedByStaffId,
            orderCode: order.orderCode.isNotEmpty ? order.orderCode : null,
            orderProductId: order.productId,
          );
        })
        .toList(growable: false);
  }

  StudentExtraPurchase _mapStudentExtraPurchase(Map<String, dynamic> row) {
    return StudentExtraPurchase(
      id: row['id'] as String,
      studentId: row['student_id'] as String,
      productId: row['product_id'] as String,
      status: StudentExtraPurchaseStatus.values.byName(row['status'] as String),
      purchasedAt: DateTime.parse(row['purchased_at'] as String),
      amountCents: row['amount_cents'] as int?,
      currencyCode: row['currency_code'] as String? ?? 'EUR',
      paymentReference: row['payment_reference'] as String?,
      recordedByStaffId: row['recorded_by_staff_id'] as String?,
    );
  }

  @override
  Future<void> grantStudentExtraProductAccess({
    required StudentId studentId,
    required String productId,
  }) async {
    final productIds = ExtraBundleCatalog.productsToGrantOnAccess(productId);
    final staffId = _client.auth.currentUser?.id;
    final purchasedAt = DateTime.now().toUtc().toIso8601String();
    for (final id in productIds) {
      await _client.from('student_extra_purchases').upsert(<String, dynamic>{
        'student_id': studentId,
        'product_id': id,
        'status': StudentExtraPurchaseStatus.purchased.name,
        'purchased_at': purchasedAt,
        'recorded_by_staff_id': staffId,
      }, onConflict: 'student_id,product_id');
    }
  }

  @override
  Future<void> revokeStudentExtraProductAccess({
    required StudentId studentId,
    required String productId,
  }) async {
    final productIds = ExtraBundleCatalog.productsToRevokeOnAccess(productId);
    await _client
        .from('student_extra_purchases')
        .update(<String, dynamic>{
          'status': StudentExtraPurchaseStatus.revoked.name,
          'recorded_by_staff_id': _client.auth.currentUser?.id,
        })
        .eq('student_id', studentId)
        .inFilter('product_id', productIds);
  }

  @override
  Future<ExtraProductCheckoutOutcome> startExtraProductCheckout({
    required StudentId studentId,
    required String productId,
    int? amountCents,
    String currencyCode = 'EUR',
    String? paymentReference,
  }) async {
    try {
      final res = await _client.functions.invoke(
        'create-stripe-checkout-session',
        body: <String, dynamic>{
          'productId': productId,
          'successUrl': SupabaseConfig.extraCheckoutSuccessUrl(productId),
          'cancelUrl': SupabaseConfig.extraCheckoutCancelUrl(productId),
        },
      );
      final data = res.data;
      if (data is! Map) {
        return const ExtraProductCheckoutOutcome.failed(
          'Risposta checkout non valida.',
        );
      }
      final map = Map<String, dynamic>.from(data);
      if (map['success'] != true) {
        final err = map['error']?.toString() ?? 'Checkout non avviato.';
        return ExtraProductCheckoutOutcome.failed(
          _humanizeCheckoutError(err, res.status),
        );
      }
      final checkoutUrl = map['checkoutUrl']?.toString().trim();
      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        return const ExtraProductCheckoutOutcome.failed(
          'URL checkout non disponibile.',
        );
      }
      return ExtraProductCheckoutOutcome.stripeRedirect(
        checkoutUrl: checkoutUrl,
      );
    } on FunctionException catch (e) {
      return ExtraProductCheckoutOutcome.failed(
        _parseCheckoutFunctionException(e),
      );
    } catch (e, st) {
      debugPrint('startExtraProductCheckout: $e\n$st');
      return const ExtraProductCheckoutOutcome.failed(
        'Impossibile avviare il pagamento. Verifica connessione e riprova.',
      );
    }
  }

  String _humanizeCheckoutError(String raw, int? status) {
    final lower = raw.toLowerCase();
    if (status == 401 ||
        lower.contains('token') ||
        lower.contains('authentication')) {
      return 'Sessione scaduta. Accedi di nuovo e riprova.';
    }
    if (status == 403 || lower.contains('forbidden')) {
      return 'Profilo allievo non collegato. Contatta la segreteria.';
    }
    if (lower.contains('invalid redirect') || lower.contains('redirect url')) {
      return 'Configurazione redirect checkout non valida.';
    }
    if (lower.contains('not found') || lower.contains('product')) {
      return 'Prodotto non disponibile per l’acquisto online.';
    }
    if (raw.trim().isEmpty) {
      return 'Impossibile avviare il pagamento. Riprova più tardi.';
    }
    return raw;
  }

  String _parseCheckoutFunctionException(FunctionException e) {
    final details = e.details;
    if (details is Map) {
      final err = details['error'];
      if (err != null) {
        return _humanizeCheckoutError(err.toString(), e.status);
      }
    }
    if (details is String && details.isNotEmpty) {
      return _humanizeCheckoutError(details, e.status);
    }
    return _humanizeCheckoutError('', e.status);
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
    var query = _client
        .from('practice_service_templates')
        .select(_templateSelect);
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
    payload['enrolled_license_category'] = _nullableTrim(
      input.enrolledLicenseCategory,
    );
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
