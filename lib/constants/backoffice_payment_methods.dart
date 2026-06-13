import '../domain/backoffice/backoffice.dart';

/// Metodi pagamento proponibili nei form staff (nuovi incassi).
///
/// [PaymentMethod.other] è mostrato in UI come «Welfare». Valori storici non
/// più usati (bonifico, assegno) restano leggibili in elenco tramite [BackofficeFormatters].
abstract final class BackofficePaymentMethods {
  static const List<PaymentMethod> selectableForNewPayment = [
    PaymentMethod.cash,
    PaymentMethod.card,
    PaymentMethod.other,
  ];

  /// Metodi pagamento proponibili nei form staff (nuove uscite).
  ///
  /// Welfare escluso: la scuola non registra spese pagate con Welfare.
  static const List<PaymentMethod> selectableForNewExpense = [
    PaymentMethod.cash,
    PaymentMethod.card,
  ];
}
