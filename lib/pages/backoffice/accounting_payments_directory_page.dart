import 'package:flutter/material.dart';

import '../../constants/backoffice_payment_methods.dart';
import '../../domain/backoffice/backoffice.dart';
import '../../repositories/backoffice/backoffice_registry.dart';
import '../../widgets/backoffice/backoffice_formatters.dart';
import '../../widgets/backoffice/backoffice_ui_tokens.dart';
import '../../theme/app_visual_tokens.dart';

enum _AccountingQuickFilter { none, today, thisMonth, last30 }

/// Directory contabilità (V1): elenco incassi da `payments` + dati minimi allievo (**solo lettura**).
class AccountingPaymentsDirectoryPage extends StatefulWidget {
  const AccountingPaymentsDirectoryPage({
    super.key,
    this.embedded = false,
    required this.onOpenStudent360,
  });

  final bool embedded;
  final ValueChanged<StudentId> onOpenStudent360;

  @override
  State<AccountingPaymentsDirectoryPage> createState() =>
      _AccountingPaymentsDirectoryPageState();
}

class _AccountingPaymentsDirectoryPageState
    extends State<AccountingPaymentsDirectoryPage> {
  final _searchCtrl = TextEditingController();

  List<AccountingPaymentListItem>? _items;
  Object? _error;
  bool _loading = true;

  PaymentMethod? _methodFilter;
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
    super.dispose();
  }

  void _clearFilters() {
    setState(() {
      _searchCtrl.clear();
      _methodFilter = null;
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
      final list = await backofficeRepository.listAccountingPayments();
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('AccountingPaymentsDirectoryPage load: $e\n$st');
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
        _items = null;
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

  ({int sumToday, int sumMonth, int count}) _summaryFor(
    List<AccountingPaymentListItem> filtered,
  ) {
    final now = DateTime.now();
    final t0 = DateTime(now.year, now.month, now.day);
    var sumToday = 0;
    var sumMonth = 0;
    for (final p in filtered) {
      final d = _localDateOnly(p.receivedAt);
      if (d == t0) sumToday += p.amountCents;
      if (d.year == now.year && d.month == now.month) {
        sumMonth += p.amountCents;
      }
    }
    return (sumToday: sumToday, sumMonth: sumMonth, count: filtered.length);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final raw = _items;
    final filtered = raw == null
        ? const <AccountingPaymentListItem>[]
        : _filtered(raw).toList(growable: false);
    final summary = _summaryFor(filtered);

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
              count: summary.count,
              loading: _loading && raw == null,
              searchCtrl: _searchCtrl,
              onSearchChanged: () => setState(() {}),
              onRefresh: _load,
              refreshDisabled: _loading,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth >= 720;
                final methodField = DropdownButtonFormField<PaymentMethod?>(
                  key: ValueKey(_methodFilter?.name ?? 'all_methods'),
                  initialValue: _methodFilter,
                  decoration: const InputDecoration(
                    labelText: 'Metodo',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
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
                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 160, child: methodField),
                      const SizedBox(width: 8),
                      Expanded(child: _buildFilterStrip(context)),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    methodField,
                    const SizedBox(height: 8),
                    _buildFilterStrip(context),
                  ],
                );
              },
            ),
          ),
          Expanded(child: _buildBody(textTheme)),
        ],
      ),
    );
  }

  Widget _buildFilterStrip(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilterChip(
          label: const Text('Oggi'),
          visualDensity: VisualDensity.compact,
          selected: _quick == _AccountingQuickFilter.today,
          onSelected: (v) => setState(() {
            _quick = v ? _AccountingQuickFilter.today : _AccountingQuickFilter.none;
          }),
        ),
        FilterChip(
          label: const Text('Questo mese'),
          visualDensity: VisualDensity.compact,
          selected: _quick == _AccountingQuickFilter.thisMonth,
          onSelected: (v) => setState(() {
            _quick =
                v ? _AccountingQuickFilter.thisMonth : _AccountingQuickFilter.none;
          }),
        ),
        FilterChip(
          label: const Text('Ultimi 30 giorni'),
          visualDensity: VisualDensity.compact,
          selected: _quick == _AccountingQuickFilter.last30,
          onSelected: (v) => setState(() {
            _quick = v ? _AccountingQuickFilter.last30 : _AccountingQuickFilter.none;
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
            style: Theme.of(context).textTheme.labelLarge,
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
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        TextButton(
          onPressed: _clearFilters,
          child: const Text('Reimposta filtri'),
        ),
      ],
    );
  }

  Widget _buildBody(TextTheme textTheme) {
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
    final raw = _items ?? const <AccountingPaymentListItem>[];
    final filtered = _filtered(raw).toList(growable: false);
    if (filtered.isEmpty) {
      return Center(
        child: Text(
          raw.isEmpty
              ? 'Nessun pagamento in elenco.'
              : 'Nessun risultato con i filtri correnti.',
          style: textTheme.bodyLarge,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          itemCount: filtered.length,
          separatorBuilder: (_, _) => const SizedBox(height: 6),
          itemBuilder: (context, index) {
            final p = filtered[index];
            return _PaymentRowCard(
              item: p,
              wide: wide,
              onOpen360: () => widget.onOpenStudent360(p.studentId),
            );
          },
        );
      },
    );
  }
}

class _AccountingSummaryRow extends StatelessWidget {
  const _AccountingSummaryRow({
    required this.sumToday,
    required this.sumMonth,
    required this.count,
    required this.loading,
    required this.searchCtrl,
    required this.onSearchChanged,
    required this.onRefresh,
    required this.refreshDisabled,
  });

  final int sumToday;
  final int sumMonth;
  final int count;
  final bool loading;
  final TextEditingController searchCtrl;
  final VoidCallback onSearchChanged;
  final VoidCallback onRefresh;
  final bool refreshDisabled;

  static const double _tileWidth = 168;
  static const double _searchWidth = 240;

  @override
  Widget build(BuildContext context) {
    final todayValue = loading
        ? '—'
        : BackofficeFormatters.moneyEur(sumToday);
    final monthValue = loading
        ? '—'
        : BackofficeFormatters.moneyEur(sumMonth);
    final countValue = loading ? '—' : '$count';

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: _tileWidth,
            child: _SummaryTile(
              title: 'Incassato oggi',
              value: todayValue,
              icon: Icons.today_outlined,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: _tileWidth,
            child: _SummaryTile(
              title: 'Incassato nel mese',
              value: monthValue,
              icon: Icons.calendar_month_outlined,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: _tileWidth,
            child: _SummaryTile(
              title: 'Movimenti',
              value: countValue,
              icon: Icons.view_list_outlined,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: _searchWidth,
            child: _SummarySearchField(
              controller: searchCtrl,
              onChanged: (_) => onSearchChanged(),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: _tileWidth,
            child: const _UscitePlaceholder(),
          ),
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
}

class _SummarySearchField extends StatelessWidget {
  const _SummarySearchField({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.search_rounded,
              size: 20,
              color: AppVisual.logoBlue.withValues(alpha: 0.85),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Cerca',
                    style: textTheme.labelSmall?.copyWith(
                      color: AppVisual.inkMuted,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                  TextField(
                    controller: controller,
                    onChanged: onChanged,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: BackofficeUiTokens.text,
                      height: 1.15,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Nome, email, tel., ricevuta…',
                      hintStyle: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppVisual.inkMuted.withValues(alpha: 0.65),
                        fontSize: 13,
                        height: 1.15,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isCollapsed: true,
                    ),
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

/// Placeholder UI — gestione uscite (Carburante, compensi, …) in patch DB dedicata.
class _UscitePlaceholder extends StatelessWidget {
  const _UscitePlaceholder();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Tooltip(
      message: 'Funzione in arrivo',
      child: Material(
        color: AppVisual.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppVisual.border),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              Icon(
                Icons.arrow_outward_rounded,
                size: 20,
                color: AppVisual.inkMuted.withValues(alpha: 0.55),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Uscite',
                      style: textTheme.labelSmall?.copyWith(
                        color: AppVisual.inkMuted,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      'In arrivo',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppVisual.inkMuted.withValues(alpha: 0.55),
                        height: 1.15,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

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
                      color: BackofficeUiTokens.text,
                      height: 1.15,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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

class _PaymentRowCard extends StatelessWidget {
  const _PaymentRowCard({
    required this.item,
    required this.wide,
    required this.onOpen360,
  });

  final AccountingPaymentListItem item;
  final bool wide;
  final VoidCallback onOpen360;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final contact = [
      if (item.studentEmail != null && item.studentEmail!.trim().isNotEmpty)
        item.studentEmail,
      if (item.studentPhone != null && item.studentPhone!.trim().isNotEmpty)
        item.studentPhone,
    ].join(' · ');

    final ref = item.receiptReference?.trim();
    final fiscal = item.fiscalReceiptNumber?.trim();
    final refLine = [
      if (ref != null && ref.isNotEmpty) ref,
      if (fiscal != null && fiscal.isNotEmpty) fiscal,
    ].join(' · ');

    final metaLine = [
      BackofficeFormatters.dateUi(item.receivedAt),
      BackofficeFormatters.paymentMethod(item.method),
      if (refLine.isNotEmpty) refLine,
    ].join(' · ');

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
                  children: [
                    Expanded(
                      flex: 3,
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
                          Text(
                            metaLine,
                            style: textTheme.bodySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      BackofficeFormatters.moneyEur(item.amountCents),
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppVisual.logoBlueDeep,
                      ),
                    ),
                    const SizedBox(width: 12),
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
                      children: [
                        Expanded(
                          child: Text(
                            item.studentFullName,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          BackofficeFormatters.moneyEur(item.amountCents),
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppVisual.logoBlueDeep,
                          ),
                        ),
                      ],
                    ),
                    if (contact.isNotEmpty)
                      Text(
                        contact,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppVisual.inkMuted,
                        ),
                      ),
                    Text(metaLine, style: textTheme.bodySmall),
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
