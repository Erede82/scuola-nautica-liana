import 'backoffice_enums.dart';
import 'ids.dart';

class NauticalInstructor {
  const NauticalInstructor({
    required this.id,
    required this.displayName,
    required this.slug,
    this.active = true,
  });

  final String id;
  final String displayName;
  final String slug;
  final bool active;
}

class ExpenseCategory {
  const ExpenseCategory({
    required this.id,
    required this.name,
    required this.slug,
    required this.sortOrder,
    this.active = true,
  });

  final String id;
  final String name;
  final String slug;
  final int sortOrder;
  final bool active;
}

class NauticalExpense {
  const NauticalExpense({
    required this.id,
    required this.title,
    required this.amountCents,
    required this.expenseDate,
    this.categoryId,
    this.instructorId,
    this.currencyCode = 'EUR',
    this.notes,
    this.paymentMethod,
    this.receiptReference,
  });

  final String id;
  final String title;
  final int amountCents;
  final DateTime expenseDate;
  final String? categoryId;
  final String? instructorId;
  final String currencyCode;
  final String? notes;
  final PaymentMethod? paymentMethod;
  final String? receiptReference;
}

/// Input per registrazione uscita scuola (`expenses`).
class ExpenseCreateInput {
  const ExpenseCreateInput({
    required this.title,
    required this.amountCents,
    required this.expenseDate,
    required this.categoryId,
    required this.paymentMethod,
    this.receiptReference,
    this.notes,
    this.instructorId,
  });

  final String title;
  final int amountCents;
  final DateTime expenseDate;
  final String categoryId;
  final PaymentMethod paymentMethod;
  final String? receiptReference;
  final String? notes;
  final String? instructorId;
}

class ExtraProduct {
  const ExtraProduct({
    required this.id,
    required this.title,
    required this.sortOrder,
    this.subtitle,
    this.description,
    this.priceCents,
    this.currencyCode = 'EUR',
    this.active = true,
  });

  final String id;
  final String title;
  final int sortOrder;
  final String? subtitle;
  final String? description;
  final int? priceCents;
  final String currencyCode;
  final bool active;
}

class ExtraVideoItem {
  const ExtraVideoItem({
    required this.id,
    required this.productId,
    required this.title,
    required this.sortOrder,
    this.description,
    this.videoUrl,
    this.durationSeconds,
    this.active = true,
  });

  final String id;
  final String productId;
  final String title;
  final int sortOrder;
  final String? description;
  final String? videoUrl;
  final int? durationSeconds;
  final bool active;
}

class StudentExtraPurchase {
  const StudentExtraPurchase({
    required this.id,
    required this.studentId,
    required this.productId,
    required this.status,
    required this.purchasedAt,
    this.amountCents,
    this.currencyCode = 'EUR',
    this.paymentReference,
  });

  final String id;
  final StudentId studentId;
  final String productId;
  final StudentExtraPurchaseStatus status;
  final DateTime purchasedAt;
  final int? amountCents;
  final String currencyCode;
  final String? paymentReference;

  bool get unlocksContent => status == StudentExtraPurchaseStatus.purchased;
}

enum StudentExtraPurchaseStatus { pending, purchased, refunded, revoked }
