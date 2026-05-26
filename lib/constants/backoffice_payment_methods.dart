import '../domain/backoffice/backoffice.dart';

/// Metodi pagamento proponibili nei form staff (nuovi incassi).
///
/// I valori storici (es. bonifico) restano leggibili in elenco tramite [BackofficeFormatters].
abstract final class BackofficePaymentMethods {
  static const List<PaymentMethod> selectableForNewPayment = [
    PaymentMethod.cash,
    PaymentMethod.card,
    PaymentMethod.other,
  ];
}
