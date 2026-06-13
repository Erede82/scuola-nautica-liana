import 'package:flutter/material.dart';

import '../../domain/backoffice/accounting.dart';
import '../../domain/backoffice/accounting_annual_stats.dart';
import '../../domain/backoffice/management_foundation.dart';
import '../../theme/app_visual_tokens.dart';
import '../../widgets/backoffice/backoffice_formatters.dart';

/// Sezione Statistiche del modulo Contabilità — confronto annuale e dettaglio.
class AccountingStatisticsSection extends StatefulWidget {
  const AccountingStatisticsSection({
    super.key,
    required this.payments,
    required this.expenses,
    required this.categories,
    this.loading = false,
  });

  final List<AccountingPaymentListItem> payments;
  final List<NauticalExpense> expenses;
  final List<ExpenseCategory> categories;
  final bool loading;

  @override
  State<AccountingStatisticsSection> createState() =>
      _AccountingStatisticsSectionState();
}

class _AccountingStatisticsSectionState extends State<AccountingStatisticsSection> {
  int? _selectedYear;

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final hasData = hasAnyAccountingMovements(
      payments: widget.payments,
      expenses: widget.expenses,
    );
    if (!hasData) {
      return _EmptyStatsMessage();
    }

    final snapshot = buildAccountingAnnualStats(
      payments: widget.payments,
      expenses: widget.expenses,
      categories: widget.categories,
    );
    final detailYear = _selectedYear ?? snapshot.defaultDetailYear;
    final yearMatches =
        snapshot.yearlyComparison.where((y) => y.year == detailYear);
    final yearDetail = yearMatches.isEmpty ? null : yearMatches.first;
    final monthly = monthlyBreakdownForYear(
      payments: widget.payments,
      expenses: widget.expenses,
      year: detailYear,
    );
    final categoryRows = categoryBreakdownForYear(
      expenses: widget.expenses,
      categories: widget.categories,
      year: detailYear,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _YearlyComparisonCard(rows: snapshot.yearlyComparison),
        const SizedBox(height: 14),
        _DetailYearCard(
          selectableYears: snapshot.selectableYears,
          selectedYear: detailYear,
          onYearSelected: (y) => setState(() => _selectedYear = y),
          summary: yearDetail,
        ),
        const SizedBox(height: 14),
        _CategoryBreakdownCard(rows: categoryRows, year: detailYear),
        const SizedBox(height: 14),
        _MonthlyTrendCard(rows: monthly, year: detailYear),
      ],
    );
  }
}

class _EmptyStatsMessage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.insights_outlined,
                size: 48,
                color: AppVisual.logoBlue.withValues(alpha: 0.55),
              ),
              const SizedBox(height: 14),
              Text(
                'Nessun dato contabile',
                textAlign: TextAlign.center,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppVisual.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Quando saranno registrati incassi e uscite, qui compariranno '
                'i confronti annuali e il dettaglio per categoria e mese.',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(
                  color: AppVisual.inkMuted,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.icon = Icons.bar_chart_rounded,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppVisual.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppVisual.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 22, color: AppVisual.logoBlue.withValues(alpha: 0.9)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppVisual.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppVisual.inkMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _YearlyComparisonCard extends StatelessWidget {
  const _YearlyComparisonCard({required this.rows});

  final List<AnnualAccountingSummary> rows;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final maxAbsNet = rows
        .map((r) => r.netCents.abs())
        .fold<int>(0, (a, b) => a > b ? a : b)
        .clamp(1, 1 << 31);

    return _StatsCard(
      title: 'Confronto annuale',
      subtitle: 'Entrate, uscite e saldo netto per ogni anno con movimenti.',
      child: Column(
        children: [
          _TableHeader(
            columns: const ['Anno', 'Entrate', 'Uscite', 'Saldo netto'],
          ),
          const SizedBox(height: 6),
          ...rows.map((row) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppVisual.ivory,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppVisual.border.withValues(alpha: 0.7)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${row.year}',
                        style: textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppVisual.ink,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        BackofficeFormatters.moneyEur(row.incomeCents),
                        style: textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        BackofficeFormatters.moneyEur(row.expenseCents),
                        style: textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        BackofficeFormatters.moneyEur(row.netCents),
                        style: textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: _netColor(row.netCents),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          ...rows.map((row) {
            final frac = (row.netCents.abs() / maxAbsNet).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${row.year}',
                      style: textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppVisual.inkMuted,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: frac,
                        minHeight: 8,
                        backgroundColor: AppVisual.chipFill,
                        color: _netColor(row.netCents).withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _DetailYearCard extends StatelessWidget {
  const _DetailYearCard({
    required this.selectableYears,
    required this.selectedYear,
    required this.onYearSelected,
    required this.summary,
  });

  final List<int> selectableYears;
  final int selectedYear;
  final ValueChanged<int> onYearSelected;
  final AnnualAccountingSummary? summary;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final income = summary?.incomeCents ?? 0;
    final expense = summary?.expenseCents ?? 0;
    final net = summary?.netCents ?? 0;

    return _StatsCard(
      title: 'Anno di dettaglio',
      subtitle: 'Seleziona l\'anno per categorie e andamento mensile.',
      icon: Icons.calendar_month_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final year in selectableYears)
                ChoiceChip(
                  label: Text('$year'),
                  selected: year == selectedYear,
                  onSelected: (_) => onYearSelected(year),
                  selectedColor: AppVisual.logoBlue.withValues(alpha: 0.15),
                  labelStyle: textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: year == selectedYear
                        ? AppVisual.logoBlue
                        : AppVisual.ink,
                  ),
                  side: BorderSide(
                    color: year == selectedYear
                        ? AppVisual.logoBlue.withValues(alpha: 0.5)
                        : AppVisual.border,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Entrate $selectedYear',
                  value: BackofficeFormatters.moneyEur(income),
                  icon: Icons.south_west_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricTile(
                  label: 'Uscite $selectedYear',
                  value: BackofficeFormatters.moneyEur(expense),
                  icon: Icons.north_east_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricTile(
                  label: 'Saldo netto',
                  value: BackofficeFormatters.moneyEur(net),
                  icon: Icons.balance_rounded,
                  valueColor: _netColor(net),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppVisual.ivory,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppVisual.border.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppVisual.logoBlue.withValues(alpha: 0.8)),
          const SizedBox(height: 6),
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: AppVisual.inkMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            value,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: valueColor ?? AppVisual.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBreakdownCard extends StatelessWidget {
  const _CategoryBreakdownCard({
    required this.rows,
    required this.year,
  });

  final List<CategoryExpenseBreakdown> rows;
  final int year;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return _StatsCard(
      title: 'Uscite per categoria',
      subtitle: 'Distribuzione delle uscite nel $year.',
      icon: Icons.pie_chart_outline_rounded,
      child: rows.isEmpty
          ? Text(
              'Nessuna uscita registrata nel $year.',
              style: textTheme.bodySmall?.copyWith(color: AppVisual.inkMuted),
            )
          : Column(
              children: [
                _TableHeader(
                  columns: const ['Categoria', 'Importo', '%'],
                ),
                const SizedBox(height: 8),
                ...rows.map((row) {
                  final frac =
                      (row.percentOfYearExpenses / 100).clamp(0.0, 1.0);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Text(
                                row.categoryName,
                                style: textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                BackofficeFormatters.moneyEur(row.amountCents),
                                style: textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 48,
                              child: Text(
                                '${row.percentOfYearExpenses.round()}%',
                                textAlign: TextAlign.end,
                                style: textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppVisual.inkMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: frac,
                            minHeight: 7,
                            backgroundColor: AppVisual.chipFill,
                            color: AppVisual.logoBlue.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
    );
  }
}

class _MonthlyTrendCard extends StatelessWidget {
  const _MonthlyTrendCard({
    required this.rows,
    required this.year,
  });

  final List<MonthlyAccountingSummary> rows;
  final int year;

  static const _monthLabels = [
    'Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu',
    'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic',
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final maxMonthTotal = rows
        .map((r) => r.incomeCents > r.expenseCents ? r.incomeCents : r.expenseCents)
        .fold<int>(0, (a, b) => a > b ? a : b)
        .clamp(1, 1 << 31);

    return _StatsCard(
      title: 'Andamento mensile',
      subtitle: 'Entrate, uscite e saldo netto mese per mese nel $year.',
      icon: Icons.show_chart_rounded,
      child: Column(
        children: [
          _TableHeader(
            columns: const ['Mese', 'Entrate', 'Uscite', 'Saldo'],
          ),
          const SizedBox(height: 6),
          ...List.generate(12, (index) {
            final row = rows[index];
            final label = _monthLabels[index];
            final hasMovement = row.incomeCents > 0 || row.expenseCents > 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 36,
                        child: Text(
                          label,
                          style: textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppVisual.inkMuted,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          BackofficeFormatters.moneyEur(row.incomeCents),
                          style: textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          BackofficeFormatters.moneyEur(row.expenseCents),
                          style: textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          BackofficeFormatters.moneyEur(row.netCents),
                          style: textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: _netColor(row.netCents),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (hasMovement) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const SizedBox(width: 36),
                        Expanded(
                          child: _MiniBar(
                            value: row.incomeCents / maxMonthTotal,
                            color: const Color(0xFF2E7D5B),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _MiniBar(
                            value: row.expenseCents / maxMonthTotal,
                            color: const Color(0xFFC75D3A),
                          ),
                        ),
                        const Expanded(child: SizedBox()),
                      ],
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _MiniBar extends StatelessWidget {
  const _MiniBar({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: 5,
        backgroundColor: AppVisual.chipFill,
        color: color.withValues(alpha: 0.75),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({required this.columns});

  final List<String> columns;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        for (var i = 0; i < columns.length; i++)
          Expanded(
            flex: i == 0 ? 2 : 3,
            child: Text(
              columns[i],
              style: textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppVisual.inkMuted,
              ),
            ),
          ),
      ],
    );
  }
}

Color _netColor(int netCents) {
  if (netCents > 0) return const Color(0xFF2E7D5B);
  if (netCents < 0) return const Color(0xFFC75D3A);
  return AppVisual.inkMuted;
}
