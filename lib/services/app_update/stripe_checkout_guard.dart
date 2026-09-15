import 'package:flutter/foundation.dart';

/// Protezione update durante checkout/redirect/ritorno Stripe (Extra).
abstract final class StripeCheckoutGuard {
  static int _pendingCount = 0;

  static bool get isCheckoutPending => _pendingCount > 0;

  static void beginCheckout() {
    _pendingCount++;
    AppUpdateCoordinatorBridge.notifyStripeChanged();
  }

  static void endCheckout() {
    if (_pendingCount > 0) {
      _pendingCount--;
    }
    AppUpdateCoordinatorBridge.notifyStripeChanged();
  }

  /// Solo test / reset harness — non usare in runtime app.
  static void resetForTest() {
    _pendingCount = 0;
  }
}

/// Branch del return-query Extra (`extraCheckout=...`).
enum ExtraCheckoutReturnKind { success, cancel, unknown }

/// Begin Stripe update-guard sul return Extra.
///
/// - [success]: lascia il guard attivo (caller chiama [StripeCheckoutGuard.endCheckout]
///   dopo reload/fulfillment).
/// - [cancel] / [unknown]: rilascia subito il guard (nessun leak).
ExtraCheckoutReturnKind protectExtraCheckoutReturn(String checkout) {
  StripeCheckoutGuard.beginCheckout();
  if (checkout == 'success') {
    return ExtraCheckoutReturnKind.success;
  }
  StripeCheckoutGuard.endCheckout();
  return checkout == 'cancel'
      ? ExtraCheckoutReturnKind.cancel
      : ExtraCheckoutReturnKind.unknown;
}

/// Bridge leggero per evitare import circolare coordinator ↔ guard.
abstract final class AppUpdateCoordinatorBridge {
  static VoidCallback? onStripeChanged;

  static void notifyStripeChanged() => onStripeChanged?.call();
}
