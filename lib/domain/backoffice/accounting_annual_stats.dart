import 'accounting.dart';
import 'management_foundation.dart';

/// Data locale (senza ora) per incassi — allineata alla directory Contabilità.
DateTime accountingLocalDateOnly(DateTime d) {
  final l = d.toLocal();
  return DateTime(l.year, l.month, l.day);
}

/// Riepilogo contabile per anno solare.
class AnnualAccountingSummary {
  const AnnualAccountingSummary({
    required this.year,
    required this.incomeCents,
    required this.expenseCents,
  });

  final int year;
  final int incomeCents;
  final int expenseCents;

  int get netCents => incomeCents - expenseCents;
}

/// Riepilogo contabile per mese (1–12) dentro un anno.
class MonthlyAccountingSummary {
  const MonthlyAccountingSummary({
    required this.year,
    required this.month,
    required this.incomeCents,
    required this.expenseCents,
  });

  final int year;
  final int month;
  final int incomeCents;
  final int expenseCents;

  int get netCents => incomeCents - expenseCents;
}

/// Uscite aggregate per categoria in un anno.
class CategoryExpenseBreakdown {
  const CategoryExpenseBreakdown({
    required this.categoryId,
    required this.categoryName,
    required this.amountCents,
    required this.percentOfYearExpenses,
  });

  /// Vuoto per uscite senza `categoryId`.
  final String categoryId;
  final String categoryName;
  final int amountCents;

  /// Percentuale sul totale uscite dell'anno (0–100).
  final double percentOfYearExpenses;
}

/// Snapshot completo per la sezione Statistiche Contabilità.
class AccountingAnnualStatsSnapshot {
  const AccountingAnnualStatsSnapshot({
    required this.yearlyComparison,
    required this.selectableYears,
    required this.defaultDetailYear,
  });

  final List<AnnualAccountingSummary> yearlyComparison;
  final List<int> selectableYears;
  final int defaultDetailYear;
}

const String kUncategorizedExpenseLabel = 'Senza categoria';
const String kUncategorizedExpenseId = '';

/// Primo anno operativo della scuola nel gestionale — non mostrare anni precedenti.
const int kAccountingStatsMinYear = 2025;

/// Costruisce statistiche annuali da incassi, uscite e catalogo categorie.
AccountingAnnualStatsSnapshot buildAccountingAnnualStats({
  required List<AccountingPaymentListItem> payments,
  required List<NauticalExpense> expenses,
  required List<ExpenseCategory> categories,
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  final currentYear = clock.year;

  final comparisonYears = _comparisonYearRange(currentYear);
  final yearlyComparison = comparisonYears
      .map(
        (year) => AnnualAccountingSummary(
          year: year,
          incomeCents: sumPaymentsForYear(payments, year),
          expenseCents: sumExpensesForYear(expenses, year),
        ),
      )
      .toList(growable: false);

  final selectableYears = List<int>.from(comparisonYears)
    ..sort((a, b) => b.compareTo(a));

  final detailYearCandidate = currentYear < kAccountingStatsMinYear
      ? kAccountingStatsMinYear
      : currentYear;
  final defaultDetailYear = selectableYears.contains(detailYearCandidate)
      ? detailYearCandidate
      : selectableYears.first;

  return AccountingAnnualStatsSnapshot(
    yearlyComparison: yearlyComparison,
    selectableYears: selectableYears,
    defaultDetailYear: defaultDetailYear,
  );
}

List<int> _comparisonYearRange(int currentYear) {
  final minYear = kAccountingStatsMinYear;
  final maxYear = currentYear < minYear ? minYear : currentYear;
  return [
    for (var y = minYear; y <= maxYear; y++) y,
  ];
}

int sumPaymentsForYear(List<AccountingPaymentListItem> payments, int year) {
  var total = 0;
  for (final p in payments) {
    if (accountingLocalDateOnly(p.receivedAt).year == year) {
      total += p.amountCents;
    }
  }
  return total;
}

int sumExpensesForYear(List<NauticalExpense> expenses, int year) {
  var total = 0;
  for (final e in expenses) {
    if (e.expenseDate.year == year) {
      total += e.amountCents;
    }
  }
  return total;
}

/// Andamento mensile (gen–dic) per un anno.
List<MonthlyAccountingSummary> monthlyBreakdownForYear({
  required List<AccountingPaymentListItem> payments,
  required List<NauticalExpense> expenses,
  required int year,
}) {
  final incomeByMonth = List<int>.filled(12, 0);
  final expenseByMonth = List<int>.filled(12, 0);

  for (final p in payments) {
    final d = accountingLocalDateOnly(p.receivedAt);
    if (d.year == year) {
      incomeByMonth[d.month - 1] += p.amountCents;
    }
  }
  for (final e in expenses) {
    if (e.expenseDate.year == year) {
      expenseByMonth[e.expenseDate.month - 1] += e.amountCents;
    }
  }

  return [
    for (var m = 1; m <= 12; m++)
      MonthlyAccountingSummary(
        year: year,
        month: m,
        incomeCents: incomeByMonth[m - 1],
        expenseCents: expenseByMonth[m - 1],
      ),
  ];
}

/// Breakdown uscite per categoria in un anno (include «Senza categoria»).
List<CategoryExpenseBreakdown> categoryBreakdownForYear({
  required List<NauticalExpense> expenses,
  required List<ExpenseCategory> categories,
  required int year,
}) {
  final nameById = {for (final c in categories) c.id: c.name};
  final totalsByCategory = <String, int>{};

  for (final e in expenses) {
    if (e.expenseDate.year != year) continue;
    final key = e.categoryId ?? kUncategorizedExpenseId;
    totalsByCategory[key] = (totalsByCategory[key] ?? 0) + e.amountCents;
  }

  final yearExpenseTotal = totalsByCategory.values.fold<int>(0, (a, b) => a + b);
  if (yearExpenseTotal == 0) return const [];

  final rows = <CategoryExpenseBreakdown>[];
  totalsByCategory.forEach((categoryId, amountCents) {
    final name = categoryId.isEmpty
        ? kUncategorizedExpenseLabel
        : (nameById[categoryId] ?? 'Categoria sconosciuta');
    rows.add(
      CategoryExpenseBreakdown(
        categoryId: categoryId,
        categoryName: name,
        amountCents: amountCents,
        percentOfYearExpenses: amountCents / yearExpenseTotal * 100,
      ),
    );
  });

  rows.sort((a, b) => b.amountCents.compareTo(a.amountCents));
  return rows;
}

bool hasAnyAccountingMovements({
  required List<AccountingPaymentListItem> payments,
  required List<NauticalExpense> expenses,
}) {
  return payments.isNotEmpty || expenses.isNotEmpty;
}
