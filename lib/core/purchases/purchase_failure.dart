// Why a purchase or restore did not end premium, without the store's SDK types.
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'purchases_gateway.dart';

enum PurchaseFailure {
  /// The driver closed the store's sheet.
  cancelled,

  /// The store accepted the order but the payment clears later; the
  /// entitlement arrives through the store's updates.
  pending,

  /// The store account already holds the subscription: restore it.
  alreadyOwned,

  failed,
}

PurchaseFailure purchaseFailureOf(Object error) {
  if (error is PurchaseCancelled) return PurchaseFailure.cancelled;
  if (error is! PlatformException) return PurchaseFailure.failed;
  return switch (PurchasesErrorHelper.getErrorCode(error)) {
    PurchasesErrorCode.purchaseCancelledError => PurchaseFailure.cancelled,
    PurchasesErrorCode.paymentPendingError => PurchaseFailure.pending,
    PurchasesErrorCode.productAlreadyPurchasedError =>
      PurchaseFailure.alreadyOwned,
    _ => PurchaseFailure.failed,
  };
}
