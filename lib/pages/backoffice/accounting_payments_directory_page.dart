import 'package:flutter/material.dart';

import '../../constants/backoffice_payment_methods.dart';
import '../../domain/backoffice/backoffice.dart';
import '../../repositories/backoffice/backoffice_registry.dart';
import '../../repositories/backoffice/management_repository_registry.dart';
import '../../widgets/backoffice/backoffice_formatters.dart';
import '../../widgets/backoffice/backoffice_ui_tokens.dart';
import '../../widgets/backoffice/accounting_expense_dialogs.dart';
import '../../widgets/backoffice/student_360_detail_view.dart';
import '../../theme/app_visual_tokens.dart';

enum _AccountingQuickFilter { none, today, thisMonth, last30 }

/// Directory contabilità (V1): incassi da `payments` e uscite da `expenses`.
class AccountingPaymentsDirectoryPage extends StatefulWidget {
  const AccountingPaymentsDirectoryPage({
    super.key,
    this.embedded = false,
    required this.onOpenStudent360,
  });

  final bool embedded;

  /// Apre Scheda 360; dalla directory Contabilità si passa [Student360DetailView.tabIndexContabilita].
  final Future<void> Function(StudentId studentId, {int initialTabIndex})
      onOpenStudent360;

  @override
  State<AccountingPaymentsDirectoryPage> createState() =>
      _AccountingPaymentsDirectoryPageState();
}

class _AccountingPaymentsDirectoryPageState
    extends State<AccountingPaymentsDirectoryPage> {
  final _searchCtrl = TextEditingController();
  final _expenseSearchCtrl = TextEditingController();

  List<AccountingPaymentListItem>? _items;
  List<NauticalExpense>? _expenses;
  List<ExpenseCategory>? _expenseCategories;
  Object? _error;
  bool _loading = true;

  PaymentMethod? _methodFilter;
  String? _expenseCategoryFilter;
  PaymentMethod? _expenseMethodFilter;
  _AccountingQuickFilter _quick = _AccountingQuickFilter.none;
  DateTime? _fromDay;
  DateTime? _toDay;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _expenseSearchCtrl.dispose();
    super.dispose();
  }

  void _clearFilters() {
    setState(() {
      _searchCtrl.clear();
      _expenseSearchCtrl.clear();
      _methodFilter = null;
      _expenseCategoryFilter = null;
      _expenseMethodFilter = null;
      _quick = _AccountingQuickFilter.none;
      _fromDay = null;
      _toDay = null;
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final payments = await backofficeRepository.listAccountingPayments();
      var categories = const <ExpenseCategory>[];
      var expenses = const <NauticalExpense>[];
      try {
        categories = await managementRepository.listExpenseCategories();
      } catch (e, st) {
        debugPrint(
          'AccountingPaymentsDirectoryPage expense categories: $e\n$st',
        );
      }
      try {
        expenses = await managementRepository.listExpenses();
      } catch (e, st) {
        debugPrint('AccountingPaymentsDirectoryPage expenses: $e\n$st');
      }
      if (!mounted) return;
      setState(() {
        _items = payments;
        _expenseCategories = categories;
        _expenses = expenses;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('AccountingPaymentsDirectoryPage load: $e\n$st');
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
        _items = null;
        _expenses = null;
        _expenseCategories = null;
      });
    }
  }

  DateTime _localDateOnly(DateTime d) {
    final l = d.toLocal();
    return DateTime(l.year, l.month, l.day);
  }

  bool _matchesQuick(DateTime localDay) {
    switch (_quick) {
      case _AccountingQuickFilter.none:
        return true;
      case _AccountingQuickFilter.today:
        final n = DateTime.now();
        return localDay == DateTime(n.year, n.month, n.day);
      case _AccountingQuickFilter.thisMonth:
        final n = DateTime.now();
        return localDay.year == n.year && localDay.month == n.month;
      case _AccountingQuickFilter.last30:
        final n = DateTime.now();
        final cutoff = n.subtract(const Duration(days: 30));
        final c0 = DateTime(cutoff.year, cutoff.month, cutoff.day);
        return !localDay.isBefore(c0);
    }
  }

  bool _matchesCustomRange(DateTime localDay) {
    if (_fromDay != null) {
      final f = DateTime(_fromDay!.year, _fromDay!.month, _fromDay!.day);
      if (localDay.isBefore(f)) return false;
    }
    if (_toDay != null) {
      final t = DateTime(_toDay!.year, _toDay!.month, _toDay!.day);
      if (localDay.isAfter(t)) return false;
    }
    return true;
  }

  bool _matchesSearch(AccountingPaymentListItem p) {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return true;
    final hay = [
      p.studentFullName,
      p.studentEmail ?? '',
      p.studentPhone ?? '',
      p.receiptReference ?? '',
      p.fiscalReceiptNumber ?? '',
      p.notes ?? '',
    ].join(' ').toLowerCase();
    for (final token in q.split(RegExp(r'\s+'))) {
      if (token.isEmpty) continue;
      if (!hay.contains(token)) return false;
    }
    return true;
  }

  Future<void> _openRegisterExpense(BuildContext context) async {
    final categories = _expenseCategories;
    if (categories == null || categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nessuna categoria uscite disponibile.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final saved = await showCreateExpenseDialog(
      context,
      categories: categories,
    );
    if (!context.mounted || !saved) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Uscita registrata'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    await _load();
  }

  Future<void> _openEditExpense(
    BuildContext context,
    NauticalExpense expense,
  ) async {
    final categories = _expenseCategories;
    if (categories == null || categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nessuna categoria uscite disponibile.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final saved = await showEditExpenseDialog(
      context,
      categories: categories,
      expense: expense,
    );
    if (!context.mounted || !saved) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Uscita aggiornata'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    await _load();
  }

  Future<void> _openDeleteExpense(
    BuildContext context,
    NauticalExpense expense,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina uscita'),
        content: Text(
          'Eliminare l\'uscita «${expense.title}» di '
          '${BackofficeFormatters.moneyEur(expense.amountCents)} '
          '(${BackofficeFormatters.dateUi(expense.expenseDate)})? '
          'L\'operazione non potrà essere annullata.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppVisual.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await managementRepository.deleteExpense(expense.id);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossibile eliminare l\'uscita: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Uscita eliminata'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    await _load();
  }

  Future<void> _openStudent360(StudentId studentId) async {
    await widget.onOpenStudent360(
      studentId,
      initialTabIndex: Student360DetailView.tabIndexContabilita,
    );
  }

  Iterable<AccountingPaymentListItem> _filtered(
    List<AccountingPaymentListItem> raw,
  ) sync* {
    for (final p in raw) {
      if (_methodFilter != null && p.method != _methodFilter) continue;
      final day = _localDateOnly(p.receivedAt);
      if (!_matchesQuick(day)) continue;
      if (!_matchesCustomRange(day)) continue;
      if (!_matchesSearch(p)) continue;
      yield p;
    }
  }

  bool _paymentFiltersActive() {
    return _methodFilter != null || _searchCtrl.text.trim().isNotEmpty;
  }

  bool _expenseFiltersActive() {
    return _expenseCategoryFilter != null ||
        _expenseMethodFilter != null ||
        _expenseSearchCtrl.text.trim().isNotEmpty;
  }

  bool _dateFiltersActive() {
    return _quick != _AccountingQuickFilter.none ||
        _fromDay != null ||
        _toDay != null;
  }

  bool _anyFiltersActive() {
    return _paymentFiltersActive() ||
        _expenseFiltersActive() ||
        _dateFiltersActive();
  }

  bool _matchesExpenseSearch(NauticalExpense e) {
    final q = _expenseSearchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return true;
    final hay = [
      e.title,
      e.notes ?? '',
      e.receiptReference ?? '',
    ].join(' ').toLowerCase();
    for (final token in q.split(RegExp(r'\s+'))) {
      if (token.isEmpty) continue;
      if (!hay.contains(token)) return false;
    }
    return true;
  }

  Iterable<NauticalExpense> _filteredExpensesByDate(
    List<NauticalExpense> raw,
  ) sync* {
    for (final e in raw) {
      final day = _localDateOnly(e.expenseDate);
      if (!_matchesQuick(day)) continue;
      if (!_matchesCustomRange(day)) continue;
      yield e;
    }
  }

  Iterable<NauticalExpense> _filteredExpenses(
    List<NauticalExpense> raw,
  ) sync* {
    for (final e in raw) {
      final day = _localDateOnly(e.expenseDate);
      if (!_matchesQuick(day)) continue;
      if (!_matchesCustomRange(day)) continue;
      if (_expenseCategoryFilter != null &&
          e.categoryId != _expenseCategoryFilter) {
        continue;
      }
      if (_expenseMethodFilter != null &&
          e.paymentMethod != _expenseMethodFilter) {
        continue;
      }
      if (!_matchesExpenseSearch(e)) continue;
      yield e;
    }
  }

  ({int sumToday, int sumMonth, int sumFiltered, int count}) _expenseSummaryFor(
    List<NauticalExpense> filtered,
  ) {
    final now = DateTime.now();
    final t0 = DateTime(now.year, now.month, now.day);
    var sumToday = 0;
    var sumMonth = 0;
    var sumFiltered = 0;
    for (final e in filtered) {
      sumFiltered += e.amountCents;
      final d = _localDateOnly(e.expenseDate);
      if (d == t0) sumToday += e.amountCents;
      if (d.year == now.year && d.month == now.month) {
        sumMonth += e.amountCents;
      }
    }
    return (
      sumToday: sumToday,
      sumMonth: sumMonth,
      sumFiltered: sumFiltered,
      count: filtered.length,
    );
  }

  Map<String, String> _categoryNameById() {
    final cats = _expenseCategories;
    if (cats == null) return const {};
    return {for (final c in cats) c.id: c.name};
  }

  ({int sumToday, int sumMonth, int sumFiltered, int count}) _summaryFor(
    List<AccountingPaymentListItem> filtered,
  ) {
    final now = DateTime.now();
    final t0 = DateTime(now.year, now.month, now.day);
    var sumToday = 0;
    var sumMonth = 0;
    var sumFiltered = 0;
    for (final p in filtered) {
      sumFiltered += p.amountCents;
      final d = _localDateOnly(p.receivedAt);
      if (d == t0) sumToday += p.amountCents;
      if (d.year == now.year && d.month == now.month) {
        sumMonth += p.amountCents;
      }
    }
    return (
      sumToday: sumToday,
      sumMonth: sumMonth,
      sumFiltered: sumFiltered,
      count: filtered.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final raw = _items;
    final filtered = raw == null
        ? const <AccountingPaymentListItem>[]
        : _filtered(raw).toList(growable: false);
    final summary = _summaryFor(filtered);
    final paymentFiltersActive = _paymentFiltersActive();
    final expenseFiltersActive = _expenseFiltersActive();
    final dateFiltersActive = _dateFiltersActive();
    final anyFiltersActive = _anyFiltersActive();
    final expenseRaw = _expenses ?? const <NauticalExpense>[];
    final dateFilteredExpenses =
        _filteredExpensesByDate(expenseRaw).toList(growable: false);
    final filteredExpenses = _filteredExpenses(expenseRaw).toList(growable: false);
    final expenseSummary = _expenseSummaryFor(filteredExpenses);
    final netToday = summary.sumToday - expenseSummary.sumToday;
    final netMonth = summary.sumMonth - expenseSummary.sumMonth;
    final netFiltered = summary.sumFiltered - expenseSummary.sumFiltered;
    final categoryById = _categoryNameById();

    return ColoredBox(
      color: AppVisual.canvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.embedded)
            Material(
              color: AppVisual.logoBlue,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Text(
                  'Contabilità',
                  style: textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: _AccountingSummaryRow(
              sumToday: summary.sumToday,
              sumMonth: summary.sumMonth,
              sumFiltered: summary.sumFiltered,
              count: summary.count,
              paymentFiltersActive: paymentFiltersActive,
              expenseFiltersActive: expenseFiltersActive,
              dateFiltersActive: dateFiltersActive,
              anyFiltersActive: anyFiltersActive,
              sumExpensesMonth: expenseSummary.sumMonth,
              sumExpensesToday: expenseSummary.sumToday,
              sumExpensesFiltered: expenseSummary.sumFiltered,
              netToday: netToday,
              netMonth: netMonth,
              netFiltered: netFiltered,
              expensesLoading: _loading && _expenses == null,
              loading: _loading && raw == null,
              onRefresh: _load,
              refreshDisabled: _loading,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: _buildFiltersPanel(context),
          ),
          Expanded(
            child: _buildBody(
              textTheme,
              filteredPayments: filtered,
              filteredExpenses: filteredExpenses,
              dateFilteredExpenses: dateFilteredExpenses,
              expenseFiltersActive: expenseFiltersActive,
              categoryById: categoryById,
              paymentsRawEmpty: raw?.isEmpty ?? true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersPanel(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final anyFiltersActive = _anyFiltersActive();
    final categories = _expenseCategories ?? const <ExpenseCategory>[];
    final sortedCategories = List<ExpenseCategory>.from(categories)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    InputDecoration fieldDecoration(String label) => InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );

    Widget paymentMethodField() => DropdownButtonFormField<PaymentMethod?>(
      key: ValueKey(_methodFilter?.name ?? 'all_payment_methods'),
      initialValue: _methodFilter,
      decoration: fieldDecoration('Metodo incassi'),
      isExpanded: true,
      items: [
        const DropdownMenuItem<PaymentMethod?>(
          value: null,
          child: Text('Tutti'),
        ),
        ...BackofficePaymentMethods.selectableForNewPayment.map(
          (m) => DropdownMenuItem(
            value: m,
            child: Text(
              BackofficeFormatters.paymentMethod(m),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      onChanged: (v) => setState(() => _methodFilter = v),
    );

    Widget expenseCategoryField() => DropdownButtonFormField<String?>(
      key: ValueKey(_expenseCategoryFilter ?? 'all_expense_categories'),
      initialValue: _expenseCategoryFilter,
      decoration: fieldDecoration('Categoria uscite'),
      isExpanded: true,
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('Tutte'),
        ),
        ...sortedCategories.map(
          (c) => DropdownMenuItem(
            value: c.id,
            child: Text(c.name, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: (v) => setState(() => _expenseCategoryFilter = v),
    );

    Widget expenseMethodField() => DropdownButtonFormField<PaymentMethod?>(
      key: ValueKey(_expenseMethodFilter?.name ?? 'all_expense_methods'),
      initialValue: _expenseMethodFilter,
      decoration: fieldDecoration('Metodo uscite'),
      isExpanded: true,
      items: [
        const DropdownMenuItem<PaymentMethod?>(
          value: null,
          child: Text('Tutti'),
        ),
        ...BackofficePaymentMethods.selectableForNewExpense.map(
          (m) => DropdownMenuItem(
            value: m,
            child: Text(
              BackofficeFormatters.paymentMethod(m),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      onChanged: (v) => setState(() => _expenseMethodFilter = v),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FilterPanelSection(
          title: 'Incassi',
          child: LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 720;
              if (wide) {
                return Row(
                  children: [
                    SizedBox(width: 180, child: paymentMethodField()),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (_) => setState(() {}),
                        decoration: fieldDecoration(
                          'Cerca allievo, ricevuta…',
                        ),
                      ),
                    ),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  paymentMethodField(),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: fieldDecoration('Cerca allievo, ricevuta…'),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        _FilterPanelSection(
          title: 'Periodo',
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilterChip(
                label: const Text('Oggi'),
                visualDensity: VisualDensity.compact,
                selected: _quick == _AccountingQuickFilter.today,
                onSelected: (v) => setState(() {
                  _quick =
                      v ? _AccountingQuickFilter.today : _AccountingQuickFilter.none;
                }),
              ),
              FilterChip(
                label: const Text('Questo mese'),
                visualDensity: VisualDensity.compact,
                selected: _quick == _AccountingQuickFilter.thisMonth,
                onSelected: (v) => setState(() {
                  _quick = v
                      ? _AccountingQuickFilter.thisMonth
                      : _AccountingQuickFilter.none;
                }),
              ),
              FilterChip(
                label: const Text('Ultimi 30 giorni'),
                visualDensity: VisualDensity.compact,
                selected: _quick == _AccountingQuickFilter.last30,
                onSelected: (v) => setState(() {
                  _quick = v
                      ? _AccountingQuickFilter.last30
                      : _AccountingQuickFilter.none;
                }),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _fromDay ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) setState(() => _fromDay = d);
                },
                child: Text(
                  _fromDay == null
                      ? 'Data da'
                      : 'Da ${BackofficeFormatters.dateUi(_fromDay)}',
                  style: textTheme.labelLarge,
                ),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _toDay ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) setState(() => _toDay = d);
                },
                child: Text(
                  _toDay == null
                      ? 'Data a'
                      : 'A ${BackofficeFormatters.dateUi(_toDay)}',
                  style: textTheme.labelLarge,
                ),
              ),
              if (anyFiltersActive)
                Chip(
                  label: const Text('Filtri attivi'),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: AppVisual.logoBlue.withValues(alpha: 0.1),
                  labelStyle: textTheme.labelSmall?.copyWith(
                    color: AppVisual.logoBlueDeep,
                    fontWeight: FontWeight.w700,
                  ),
                  side: BorderSide(
                    color: AppVisual.logoBlue.withValues(alpha: 0.35),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              TextButton(
                onPressed: _clearFilters,
                child: const Text('Reimposta filtri'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _FilterPanelSection(
          title: 'Uscite',
          child: LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 720;
              if (wide) {
                return Row(
                  children: [
                    SizedBox(width: 180, child: expenseCategoryField()),
                    const SizedBox(width: 8),
                    SizedBox(width: 160, child: expenseMethodField()),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _expenseSearchCtrl,
                        onChanged: (_) => setState(() {}),
                        decoration: fieldDecoration(
                          'Cerca titolo, ricevuta, note…',
                        ),
                      ),
                    ),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  expenseCategoryField(),
                  const SizedBox(height: 8),
                  expenseMethodField(),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _expenseSearchCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: fieldDecoration(
                      'Cerca titolo, ricevuta, note…',
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBody(
    TextTheme textTheme, {
    required List<AccountingPaymentListItem> filteredPayments,
    required List<NauticalExpense> filteredExpenses,
    required List<NauticalExpense> dateFilteredExpenses,
    required bool expenseFiltersActive,
    required Map<String, String> categoryById,
    required bool paymentsRawEmpty,
  }) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Impossibile caricare gli incassi.\n$_error',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text(
              'Incassi',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: BackofficeUiTokens.text,
              ),
            ),
            const SizedBox(height: 8),
            if (filteredPayments.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  paymentsRawEmpty
                      ? 'Nessun pagamento in elenco.'
                      : 'Nessun risultato con i filtri correnti.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppVisual.inkMuted,
                  ),
                ),
              )
            else
              ...filteredPayments.map(
                (p) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _PaymentRowCard(
                    item: p,
                    wide: wide,
                    onOpen360: () => _openStudent360(p.studentId),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Uscite recenti',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: BackofficeUiTokens.text,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _loading ? null : () => _openRegisterExpense(context),
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('Registra uscita'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (filteredExpenses.isEmpty)
              Text(
                expenseFiltersActive && dateFilteredExpenses.isNotEmpty
                    ? 'Nessuna uscita con i filtri correnti.'
                    : 'Nessuna uscita registrata nel periodo selezionato.',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppVisual.inkMuted,
                ),
              )
            else
              ...filteredExpenses.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _ExpenseRowCard(
                    expense: e,
                    categoryName: e.categoryId == null
                        ? null
                        : categoryById[e.categoryId],
                    wide: wide,
                    onEdit: () => _openEditExpense(context, e),
                    onDelete: () => _openDeleteExpense(context, e),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AccountingSummaryRow extends StatelessWidget {
  const _AccountingSummaryRow({
    required this.sumToday,
    required this.sumMonth,
    required this.sumFiltered,
    required this.count,
    required this.paymentFiltersActive,
    required this.expenseFiltersActive,
    required this.dateFiltersActive,
    required this.anyFiltersActive,
    required this.sumExpensesMonth,
    required this.sumExpensesToday,
    required this.sumExpensesFiltered,
    required this.netToday,
    required this.netMonth,
    required this.netFiltered,
    required this.expensesLoading,
    required this.loading,
    required this.onRefresh,
    required this.refreshDisabled,
  });

  final int sumToday;
  final int sumMonth;
  final int sumFiltered;
  final int count;
  final bool paymentFiltersActive;
  final bool expenseFiltersActive;
  final bool dateFiltersActive;
  final bool anyFiltersActive;
  final int sumExpensesMonth;
  final int sumExpensesToday;
  final int sumExpensesFiltered;
  final int netToday;
  final int netMonth;
  final int netFiltered;
  final bool expensesLoading;
  final bool loading;
  final VoidCallback onRefresh;
  final bool refreshDisabled;

  static const double _tileWidth = 168;

  static String? _expenseAggregateSubtitle({
    required bool loading,
    required bool expenseFiltersActive,
    required bool dateFiltersActive,
    required bool emptyFiltered,
  }) {
    if (loading) return null;
    if (expenseFiltersActive && dateFiltersActive) {
      return 'Selezione corrente';
    }
    if (expenseFiltersActive) return 'Uscite filtrate';
    if (dateFiltersActive) return 'Uscite per periodo';
    if (emptyFiltered) return 'Nessuna uscita';
    return null;
  }

  static String? _netBalanceSubtitle({
    required bool loading,
    required bool paymentFiltersActive,
    required bool expenseFiltersActive,
    required bool dateFiltersActive,
  }) {
    if (loading) return null;
    if (paymentFiltersActive && expenseFiltersActive) {
      return 'Selezione corrente';
    }
    if (paymentFiltersActive && dateFiltersActive) {
      return 'Incassi filtrati · periodo';
    }
    if (expenseFiltersActive && dateFiltersActive) {
      return 'Uscite filtrate · periodo';
    }
    if (paymentFiltersActive && expenseFiltersActive && dateFiltersActive) {
      return 'Selezione corrente';
    }
    if (paymentFiltersActive) return 'Incassi filtrati';
    if (expenseFiltersActive) return 'Uscite filtrate';
    if (dateFiltersActive) return 'Periodo selezionato';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final todayValue = loading
        ? '—'
        : BackofficeFormatters.moneyEur(sumToday);
    final monthValue = loading
        ? '—'
        : BackofficeFormatters.moneyEur(sumMonth);
    final countValue = loading ? '—' : '$count';
    final filteredValue = loading
        ? '—'
        : BackofficeFormatters.moneyEur(sumFiltered);
    final filteredSubtitle = anyFiltersActive && !loading
        ? 'Selezione corrente'
        : null;
    final incomeFilterHint = paymentFiltersActive && !loading
        ? 'Incassi filtrati'
        : null;
    final expenseSummaryUsesFiltered =
        dateFiltersActive || expenseFiltersActive;
    final expensesValueCents = expenseSummaryUsesFiltered
        ? sumExpensesFiltered
        : sumExpensesMonth;
    final expensesValue = expensesLoading
        ? '—'
        : BackofficeFormatters.moneyEur(expensesValueCents);
    final expensesTodayValue = expensesLoading
        ? '—'
        : BackofficeFormatters.moneyEur(sumExpensesToday);
    final expensesTitle =
        expenseSummaryUsesFiltered ? 'Totale uscite' : 'Uscite nel mese';
    final expensesSubtitle = _expenseAggregateSubtitle(
      loading: expensesLoading,
      expenseFiltersActive: expenseFiltersActive,
      dateFiltersActive: dateFiltersActive,
      emptyFiltered: sumExpensesFiltered == 0,
    );
    final expensesTodaySubtitle = expensesLoading
        ? null
        : expenseFiltersActive
        ? 'Uscite filtrate'
        : (dateFiltersActive ? 'Uscite per periodo' : null);
    final netLoading = loading || expensesLoading;
    final netScopeHint = _netBalanceSubtitle(
      loading: netLoading,
      paymentFiltersActive: paymentFiltersActive,
      expenseFiltersActive: expenseFiltersActive,
      dateFiltersActive: dateFiltersActive,
    );
    final netTodayDisplay = _netTileDisplay(
      netToday,
      netLoading,
      extraSubtitle: netScopeHint,
    );
    final netMonthDisplay = _netTileDisplay(
      netMonth,
      netLoading,
      extraSubtitle: netScopeHint,
    );
    final netFilteredDisplay = _netTileDisplay(
      netFiltered,
      netLoading,
      extraSubtitle: 'Selezione corrente',
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const _SummarySectionMark(title: 'Incassi'),
          SizedBox(
            width: _tileWidth,
            child: _SummaryTile(
              title: 'Incassato oggi',
              value: todayValue,
              icon: Icons.today_outlined,
              subtitle: incomeFilterHint,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: _tileWidth,
            child: _SummaryTile(
              title: 'Incassato nel mese',
              value: monthValue,
              icon: Icons.calendar_month_outlined,
              subtitle: incomeFilterHint,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: _tileWidth,
            child: _SummaryTile(
              title: 'Movimenti',
              value: countValue,
              icon: Icons.view_list_outlined,
              subtitle: incomeFilterHint,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: _tileWidth,
            child: _SummaryTile(
              title: 'Totale filtrato',
              value: filteredValue,
              icon: Icons.filter_alt_outlined,
              subtitle: filteredSubtitle,
            ),
          ),
          const SizedBox(width: 8),
          const _SummarySectionMark(title: 'Uscite'),
          SizedBox(
            width: _tileWidth,
            child: _SummaryTile(
              title: 'Uscite oggi',
              value: expensesTodayValue,
              icon: Icons.today_outlined,
              subtitle: expensesTodaySubtitle,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: _tileWidth,
            child: _SummaryTile(
              title: expensesTitle,
              value: expensesValue,
              icon: Icons.arrow_outward_rounded,
              subtitle: expensesSubtitle,
            ),
          ),
          const SizedBox(width: 8),
          const _SummarySectionMark(title: 'Saldo netto'),
          SizedBox(
            width: _tileWidth,
            child: _SummaryTile(
              title: 'Saldo oggi',
              value: netTodayDisplay.value,
              icon: Icons.account_balance_wallet_outlined,
              valueColor: netTodayDisplay.valueColor,
              subtitle: netTodayDisplay.subtitle,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: _tileWidth,
            child: _SummaryTile(
              title: 'Saldo mese',
              value: netMonthDisplay.value,
              icon: Icons.savings_outlined,
              valueColor: netMonthDisplay.valueColor,
              subtitle: netMonthDisplay.subtitle,
            ),
          ),
          if (anyFiltersActive) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: _tileWidth,
              child: _SummaryTile(
                title: 'Saldo filtrato',
                value: netFilteredDisplay.value,
                icon: Icons.balance_outlined,
                valueColor: netFilteredDisplay.valueColor,
                subtitle: netFilteredDisplay.subtitle,
              ),
            ),
          ],
          const SizedBox(width: 6),
          IconButton.filledTonal(
            onPressed: refreshDisabled ? null : onRefresh,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Aggiorna elenco',
          ),
        ],
      ),
    );
  }

  static ({String value, Color? valueColor, String? subtitle}) _netTileDisplay(
    int cents,
    bool loading, {
    String? extraSubtitle,
  }) {
    if (loading) {
      return (value: '—', valueColor: null, subtitle: null);
    }
    final value = BackofficeFormatters.moneyEur(cents);
    if (cents < 0) {
      return (
        value: value,
        valueColor: AppVisual.error.withValues(alpha: 0.88),
        subtitle: 'In negativo',
      );
    }
    return (value: value, valueColor: null, subtitle: extraSubtitle);
  }
}

class _SummarySectionMark extends StatelessWidget {
  const _SummarySectionMark({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(left: 2, right: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 3,
            height: 52,
            decoration: BoxDecoration(
              color: AppVisual.logoBlue.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            title,
            style: textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppVisual.inkMuted,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterPanelSection extends StatelessWidget {
  const _FilterPanelSection({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppVisual.inkMuted,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.title,
    required this.value,
    required this.icon,
    this.subtitle,
    this.valueColor,
  });

  final String title;
  final String value;
  final IconData icon;
  final String? subtitle;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: AppVisual.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppVisual.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppVisual.logoBlue.withValues(alpha: 0.85)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: textTheme.labelSmall?.copyWith(
                      color: AppVisual.inkMuted,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    value,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: valueColor ?? BackofficeUiTokens.text,
                      height: 1.15,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: textTheme.labelSmall?.copyWith(
                        color: valueColor ?? AppVisual.inkMuted,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentRowCard extends StatelessWidget {
  const _PaymentRowCard({
    required this.item,
    required this.wide,
    required this.onOpen360,
  });

  final AccountingPaymentListItem item;
  final bool wide;
  final VoidCallback onOpen360;

  Widget _methodChip(TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: BackofficeUiTokens.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        BackofficeFormatters.paymentMethod(item.method),
        style: textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: BackofficeUiTokens.primary,
        ),
      ),
    );
  }

  String? _receiptLine() {
    final ref = item.receiptReference?.trim();
    final fiscal = item.fiscalReceiptNumber?.trim();
    final parts = <String>[
      if (ref != null && ref.isNotEmpty) ref,
      if (fiscal != null && fiscal.isNotEmpty) 'Fisc. $fiscal',
    ];
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final contact = [
      if (item.studentEmail != null && item.studentEmail!.trim().isNotEmpty)
        item.studentEmail,
      if (item.studentPhone != null && item.studentPhone!.trim().isNotEmpty)
        item.studentPhone,
    ].join(' · ');
    final receiptLine = _receiptLine();
    final notes = item.notes?.trim();

    return Material(
      color: AppVisual.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppVisual.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        hoverColor: AppVisual.logoBlue.withValues(alpha: 0.04),
        onTap: onOpen360,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 88,
                      child: Text(
                        BackofficeFormatters.dateUi(item.receivedAt),
                        style: textTheme.labelSmall?.copyWith(
                          color: BackofficeUiTokens.text.withValues(alpha: 0.72),
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.studentFullName,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: BackofficeUiTokens.text,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (contact.isNotEmpty)
                            Text(
                              contact,
                              style: textTheme.bodySmall?.copyWith(
                                color: AppVisual.inkMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                BackofficeFormatters.moneyEur(item.amountCents),
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppVisual.logoBlueDeep,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _methodChip(textTheme),
                            ],
                          ),
                          if (receiptLine != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Ricevuta: $receiptLine',
                              style: textTheme.bodySmall?.copyWith(
                                color: BackofficeUiTokens.text.withValues(
                                  alpha: 0.78,
                                ),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (notes != null && notes.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              notes,
                              style: textTheme.bodySmall?.copyWith(
                                color: BackofficeUiTokens.text.withValues(
                                  alpha: 0.68,
                                ),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: onOpen360,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      child: const Text('Apri Scheda 360'),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 72,
                          child: Text(
                            BackofficeFormatters.dateUi(item.receivedAt),
                            style: textTheme.labelSmall?.copyWith(
                              color: BackofficeUiTokens.text.withValues(
                                alpha: 0.72,
                              ),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.studentFullName,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (contact.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          contact,
                          style: textTheme.bodySmall?.copyWith(
                            color: AppVisual.inkMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          Text(
                            BackofficeFormatters.moneyEur(item.amountCents),
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppVisual.logoBlueDeep,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _methodChip(textTheme),
                        ],
                      ),
                    ),
                    if (receiptLine != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Ricevuta: $receiptLine',
                          style: textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (notes != null && notes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          notes,
                          style: textTheme.bodySmall?.copyWith(
                            color: BackofficeUiTokens.text.withValues(alpha: 0.68),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: onOpen360,
                        child: const Text('Apri Scheda 360'),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ExpenseRowCard extends StatelessWidget {
  const _ExpenseRowCard({
    required this.expense,
    required this.categoryName,
    required this.wide,
    required this.onEdit,
    required this.onDelete,
  });

  final NauticalExpense expense;
  final String? categoryName;
  final bool wide;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final notes = expense.notes?.trim();
    final categoryLabel = categoryName?.trim();
    final receipt = expense.receiptReference?.trim();

    Widget categoryChip() {
      if (categoryLabel == null || categoryLabel.isEmpty) {
        return const SizedBox.shrink();
      }
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppVisual.warmBeige.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          categoryLabel,
          style: textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppVisual.logoBlueDeep,
          ),
        ),
      );
    }

    Widget methodChip() {
      final method = expense.paymentMethod;
      if (method == null) return const SizedBox.shrink();
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: BackofficeUiTokens.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          BackofficeFormatters.paymentMethod(method),
          style: textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: BackofficeUiTokens.primary,
          ),
        ),
      );
    }

    Widget amountRow() {
      return Row(
        children: [
          Text(
            BackofficeFormatters.moneyEur(expense.amountCents),
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppVisual.logoBlueDeep,
            ),
          ),
          if (expense.paymentMethod != null) ...[
            const SizedBox(width: 8),
            methodChip(),
          ],
          if (categoryLabel != null && categoryLabel.isNotEmpty) ...[
            const SizedBox(width: 8),
            categoryChip(),
          ],
        ],
      );
    }

    return Material(
      color: AppVisual.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppVisual.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 88,
                    child: Text(
                      BackofficeFormatters.dateUi(expense.expenseDate),
                      style: textTheme.labelSmall?.copyWith(
                        color: BackofficeUiTokens.text.withValues(alpha: 0.72),
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          expense.title,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: BackofficeUiTokens.text,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        amountRow(),
                        if (receipt != null && receipt.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Ricevuta: $receipt',
                            style: textTheme.bodySmall?.copyWith(
                              color: BackofficeUiTokens.text.withValues(
                                alpha: 0.78,
                              ),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (notes != null && notes.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            notes,
                            style: textTheme.bodySmall?.copyWith(
                              color: BackofficeUiTokens.text.withValues(
                                alpha: 0.68,
                              ),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: onEdit,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        child: const Text('Modifica'),
                      ),
                      TextButton(
                        onPressed: onDelete,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          foregroundColor: AppVisual.error.withValues(
                            alpha: 0.82,
                          ),
                        ),
                        child: const Text('Elimina'),
                      ),
                    ],
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 72,
                        child: Text(
                          BackofficeFormatters.dateUi(expense.expenseDate),
                          style: textTheme.labelSmall?.copyWith(
                            color: BackofficeUiTokens.text.withValues(
                              alpha: 0.72,
                            ),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          expense.title,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: amountRow(),
                  ),
                  if (receipt != null && receipt.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Ricevuta: $receipt',
                        style: textTheme.bodySmall?.copyWith(
                          color: BackofficeUiTokens.text.withValues(
                            alpha: 0.78,
                          ),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (notes != null && notes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        notes,
                        style: textTheme.bodySmall?.copyWith(
                          color: BackofficeUiTokens.text.withValues(alpha: 0.68),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      spacing: 4,
                      children: [
                        TextButton(
                          onPressed: onEdit,
                          child: const Text('Modifica'),
                        ),
                        TextButton(
                          onPressed: onDelete,
                          style: TextButton.styleFrom(
                            foregroundColor: AppVisual.error.withValues(
                              alpha: 0.82,
                            ),
                          ),
                          child: const Text('Elimina'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
