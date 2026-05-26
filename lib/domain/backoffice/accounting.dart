import 'backoffice_enums.dart';
import 'ids.dart';

/// Voce di incasso — riga contabile collegata allo studente.
///
/// Tabella `payments` / movimenti; saldo residuo da calcolare o materializzare in vista.
class PaymentReceived {
  const PaymentReceived({
    required this.id,
    required this.studentId,
    required this.amountCents,
    required this.currencyCode,
    required this.receivedAt,
    required this.method,
    this.receiptReference,
    this.fiscalReceiptNumber,
    this.notes,
    this.recordedByStaffId,
  });

  final PaymentId id;
  final StudentId studentId;

  /// Importo in centesimi (evita float; allineato a Stripe/fatturazione).
  final int amountCents;
  final String currencyCode;
  final DateTime receivedAt;
  final PaymentMethod method;
  final String? receiptReference;

  /// Numero ricevuta fiscale / ID gestionale.
  final String? fiscalReceiptNumber;
  final String? notes;
  final StaffId? recordedByStaffId;
}

/// Voce per directory contabile globale (lista incassi con anagrafica minimale).
///
/// Costruita da una singola lettura `payments` + `students` senza caricare la Scheda 360.
class AccountingPaymentListItem {
  const AccountingPaymentListItem({
    required this.paymentId,
    required this.studentId,
    required this.studentFullName,
    this.studentEmail,
    this.studentPhone,
    required this.amountCents,
    required this.currencyCode,
    required this.receivedAt,
    required this.method,
    this.receiptReference,
    this.fiscalReceiptNumber,
    this.notes,
    this.recordedByStaffId,
  });

  final PaymentId paymentId;
  final StudentId studentId;
  final String studentFullName;
  final String? studentEmail;
  final String? studentPhone;
  final int amountCents;
  final String currencyCode;
  final DateTime receivedAt;
  final PaymentMethod method;
  final String? receiptReference;
  final String? fiscalReceiptNumber;
  final String? notes;
  final StaffId? recordedByStaffId;
}

/// Fascicolo economico studente — usato in dashboard amministrazione.
///
/// Il saldo può essere campo denormalizzato aggiornato da trigger o edge function.
class StudentFinancialSummary {
  const StudentFinancialSummary({
    required this.studentId,
    required this.registrationFeeCents,
    required this.currencyCode,
    required this.totalPaidCents,
    required this.remainingBalanceCents,
    this.accountingNotes,
    this.lastUpdatedAt,
  });

  final StudentId studentId;

  /// Iscrizione / iscrizione corso base.
  final int registrationFeeCents;
  final String currencyCode;
  final int totalPaidCents;
  final int remainingBalanceCents;
  final String? accountingNotes;
  final DateTime? lastUpdatedAt;

  double get remainingBalanceMajorUnits => remainingBalanceCents / 100.0;
}
