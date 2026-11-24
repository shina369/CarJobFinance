import 'dart:async';

import 'package:carjobfinance/core/purchases/purchase_failure.dart';
import 'package:carjobfinance/core/purchases/purchases_gateway.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

PlatformException _storeError(PurchasesErrorCode code) =>
    PlatformException(code: '${code.index}', message: code.name);

void main() {
  test('a closed purchase sheet is a cancellation', () {
    expect(purchaseFailureOf(const PurchaseCancelled()),
        PurchaseFailure.cancelled);
    expect(
      purchaseFailureOf(_storeError(PurchasesErrorCode.purchaseCancelledError)),
      PurchaseFailure.cancelled,
    );
  });

  test('a payment still being processed is pending', () {
    expect(
      purchaseFailureOf(_storeError(PurchasesErrorCode.paymentPendingError)),
      PurchaseFailure.pending,
    );
  });

  test('a subscription the store already has is owned', () {
    expect(
      purchaseFailureOf(
          _storeError(PurchasesErrorCode.productAlreadyPurchasedError)),
      PurchaseFailure.alreadyOwned,
    );
  });

  test('anything else is a plain failure', () {
    expect(
      purchaseFailureOf(_storeError(PurchasesErrorCode.networkError)),
      PurchaseFailure.failed,
    );
    expect(
        purchaseFailureOf(TimeoutException('store')), PurchaseFailure.failed);
    expect(purchaseFailureOf(StateError('gone')), PurchaseFailure.failed);
  });
}
