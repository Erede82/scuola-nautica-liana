import 'package:flutter/material.dart';
import 'package:postgrest/postgrest.dart';

import '../../constants/backoffice_payment_methods.dart';
import '../../domain/backoffice/backoffice.dart';
import '../../repositories/backoffice/management_repository_registry.dart';
import 'backoffice_formatters.dart';
import 'backoffice_ui_tokens.dart';
import 'student_backoffice_dialogs.dart';

const _instructorCategorySlug = 'pagamento-istruttori';

String _formatWriteError(Object e) {
  if (e is PostgrestException) return e.message;
  return e.toString();
}

void _accountingSnack(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}

List<ExpenseCategory> _sortedCategories(List<ExpenseCategory> categories) {
  return List<ExpenseCategory>.from(categories)
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
}

/// Dialog per registrare una nuova uscita in `expenses`.
///
/// Restituisce `true` se l'uscita è stata salvata con successo.
Future<bool> showCreateExpenseDialog(
  BuildContext context, {
  required List<ExpenseCategory> categories,
}) async {
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _ExpenseFormDialog(categories: _sortedCategories(categories)),
      ) ??
      false;
}

/// Dialog per modificare un'uscita esistente in `expenses`.
///
/// Restituisce `true` se l'uscita è stata aggiornata con successo.
Future<bool> showEditExpenseDialog(
  BuildContext context, {
  required List<ExpenseCategory> categories,
  required NauticalExpense expense,
}) async {
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _ExpenseFormDialog(
          categories: _sortedCategories(categories),
          existing: expense,
        ),
      ) ??
      false;
}

class _ExpenseFormDialog extends StatefulWidget {
  const _ExpenseFormDialog({
    required this.categories,
    this.existing,
  });

  final List<ExpenseCategory> categories;
  final NauticalExpense? existing;

  @override
  State<_ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends State<_ExpenseFormDialog> {
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  late DateTime _expenseDate;
  ExpenseCategory? _category;
  late PaymentMethod _paymentMethod;
  String? _instructorId;

  List<NauticalInstructor> _instructors = const [];
  bool _instructorsLoading = true;
  bool _instructorsUnavailable = false;
  bool _busy = false;

  bool get _isEdit => widget.existing != null;

  bool get _showInstructorField =>
      _category?.slug == _instructorCategorySlug;

  @override
  void initState() {
    super.initState();
    _prefillFromExisting();
    _loadInstructors();
  }

  void _prefillFromExisting() {
    final existing = widget.existing;
    if (existing == null) {
      _expenseDate = DateTime.now();
      _paymentMethod = BackofficePaymentMethods.selectableForNewExpense.first;
      return;
    }

    _amountCtrl.text = (existing.amountCents / 100)
        .toStringAsFixed(2)
        .replaceAll('.', ',');
    _notesCtrl.text = existing.notes ?? '';
    _expenseDate = DateTime(
      existing.expenseDate.year,
      existing.expenseDate.month,
      existing.expenseDate.day,
    );
    for (final c in widget.categories) {
      if (c.id == existing.categoryId) {
        _category = c;
        break;
      }
    }
    final method = existing.paymentMethod;
    _paymentMethod =
        method != null &&
            BackofficePaymentMethods.selectableForNewExpense.contains(method)
        ? method
        : BackofficePaymentMethods.selectableForNewExpense.first;
    _instructorId = existing.instructorId;
  }

  Future<void> _loadInstructors() async {
    try {
      final list = await managementRepository.listInstructors();
      if (!mounted) return;
      setState(() {
        _instructors = list;
        _instructorsLoading = false;
        _instructorsUnavailable = list.isEmpty;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _instructorsLoading = false;
        _instructorsUnavailable = true;
      });
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String? _preservedReceiptReference() {
    if (!_isEdit) return null;
    final ref = widget.existing!.receiptReference?.trim();
    if (ref == null || ref.isEmpty) return null;
    return ref;
  }

  String _titleForCategory(ExpenseCategory category) => category.name.trim();

  Future<void> _pickDate() async {
    if (_busy) return;
    final picked = await showBackofficeDatePicker(
      context,
      initialDate: _expenseDate,
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _expenseDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  ExpenseCreateInput _buildInput({
    required String title,
    required int cents,
    required ExpenseCategory category,
  }) {
    return ExpenseCreateInput(
      title: title,
      amountCents: cents,
      expenseDate: _expenseDate,
      categoryId: category.id,
      paymentMethod: _paymentMethod,
      receiptReference: _preservedReceiptReference(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      instructorId: _showInstructorField ? _instructorId : null,
    );
  }

  Future<void> _submit() async {
    final category = _category;
    if (category == null) {
      _accountingSnack(context, 'Seleziona una categoria.');
      return;
    }

    final title = _titleForCategory(category);
    if (title.isEmpty) {
      _accountingSnack(context, 'Categoria non valida.');
      return;
    }

    final cents = parseEuroInputToCents(_amountCtrl.text);
    if (cents == null) {
      _accountingSnack(context, 'Importo non valido.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c2) => AlertDialog(
        title: Text(_isEdit ? 'Conferma modifiche' : 'Conferma registrazione'),
        content: Text(
          _isEdit
              ? 'Salvare modifiche all\'uscita «$title» per '
                    '${BackofficeFormatters.moneyEur(cents)} '
                    '(${BackofficeFormatters.paymentMethod(_paymentMethod)})?'
              : 'Registrare uscita «$title» per '
                    '${BackofficeFormatters.moneyEur(cents)} '
                    '(${BackofficeFormatters.paymentMethod(_paymentMethod)})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c2, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c2, true),
            child: const Text('Conferma'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final input = _buildInput(title: title, cents: cents, category: category);

    setState(() => _busy = true);
    try {
      if (_isEdit) {
        await managementRepository.updateExpense(widget.existing!.id, input);
      } else {
        await managementRepository.createExpense(input);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      _accountingSnack(context, _formatWriteError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      title: Text(_isEdit ? 'Modifica uscita' : 'Registra uscita'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEdit
                    ? 'Aggiorna categoria, metodo, importo e data. Importo in euro (es. 125,50).'
                    : 'Registra una spesa della scuola. Importo in euro (es. 125,50).',
                style: textTheme.bodySmall?.copyWith(
                  color: BackofficeUiTokens.text.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ExpenseCategory>(
                key: ValueKey(_category?.id),
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Categoria',
                  border: OutlineInputBorder(),
                ),
                isExpanded: true,
                items: widget.categories
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(c.name, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(growable: false),
                onChanged: _busy
                    ? null
                    : (v) => setState(() {
                        _category = v;
                        if (v?.slug != _instructorCategorySlug) {
                          _instructorId = null;
                        }
                      }),
              ),
              const SizedBox(height: 12),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Metodo pagamento',
                  border: OutlineInputBorder(),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<PaymentMethod>(
                    isExpanded: true,
                    value: _paymentMethod,
                    items: BackofficePaymentMethods.selectableForNewExpense
                        .map(
                          (m) => DropdownMenuItem(
                            value: m,
                            child: Text(BackofficeFormatters.paymentMethod(m)),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: _busy
                        ? null
                        : (v) {
                            if (v != null) setState(() => _paymentMethod = v);
                          },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amountCtrl,
                enabled: !_busy,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Importo (€)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Data',
                  border: OutlineInputBorder(),
                ),
                child: InkWell(
                  onTap: _busy ? null : _pickDate,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(BackofficeFormatters.dateUi(_expenseDate)),
                  ),
                ),
              ),
              if (_showInstructorField) ...[
                const SizedBox(height: 12),
                if (_instructorsLoading)
                  Text(
                    'Caricamento istruttori…',
                    style: textTheme.bodySmall?.copyWith(
                      color: BackofficeUiTokens.text.withValues(alpha: 0.68),
                    ),
                  )
                else if (_instructorsUnavailable)
                  Text(
                    'Elenco istruttori non disponibile. '
                    'Puoi salvare l\'uscita senza istruttore.',
                    style: textTheme.bodySmall?.copyWith(
                      color: BackofficeUiTokens.text.withValues(alpha: 0.68),
                    ),
                  )
                else
                  DropdownButtonFormField<String?>(
                    key: ValueKey(_instructorId),
                    initialValue: _instructorId,
                    decoration: const InputDecoration(
                      labelText: 'Istruttore (opzionale)',
                      border: OutlineInputBorder(),
                    ),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Nessuno'),
                      ),
                      ..._instructors.map(
                        (i) => DropdownMenuItem(
                          value: i.id,
                          child: Text(
                            i.displayName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _instructorId = v),
                  ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _notesCtrl,
                enabled: !_busy,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Note (opzionale)',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isEdit ? 'Salva modifiche' : 'Registra'),
        ),
      ],
    );
  }
}
