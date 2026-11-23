// The store that sells and reports the premium subscription.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class PremiumInfo {
  const PremiumInfo({
    required this.isPremium,
    this.expiresAt,
    this.willRenew = false,
  });

  static const none = PremiumInfo(isPremium: false);

  final bool isPremium;

  /// Null when the entitlement does not expire.
  final DateTime? expiresAt;

  /// False once the subscription was cancelled: it still counts until
  /// [expiresAt].
  final bool willRenew;

  @override
  bool operator ==(Object other) =>
      other is PremiumInfo &&
      other.isPremium == isPremium &&
      other.expiresAt == expiresAt &&
      other.willRenew == willRenew;

  @override
  int get hashCode => Object.hash(isPremium, expiresAt, willRenew);
}

/// The annual plan as the store prices it, ready to display.
@immutable
class PremiumOffer {
  const PremiumOffer({
    required this.packageId,
    required this.priceText,
    required this.monthlyText,
    this.trialDays,
  });

  final String packageId;
  final String priceText;

  /// The annual price spread over twelve months.
  final String monthlyText;

  /// Null when the driver is not eligible for a free trial.
  final int? trialDays;
}

/// The driver closed the store's purchase sheet without buying.
class PurchaseCancelled implements Exception {
  const PurchaseCancelled();
}

abstract class PurchasesGateway {
  /// Changes reported by the store for the logged-in account.
  Stream<PremiumInfo> get updates;

  Future<void> logIn(String userId);

  Future<void> logOut();

  Future<PremiumInfo> currentInfo();

  /// Null when the store has nothing to sell (e.g. offline).
  Future<PremiumOffer?> annualOffer();

  /// Throws [PurchaseCancelled] when the driver gives up.
  Future<PremiumInfo> purchase(PremiumOffer offer);

  Future<PremiumInfo> restore();
}

/// Used where the store is not configured: nothing is ever premium.
class NoPurchasesGateway implements PurchasesGateway {
  const NoPurchasesGateway();

  @override
  Stream<PremiumInfo> get updates => const Stream.empty();

  @override
  Future<void> logIn(String userId) async {}

  @override
  Future<void> logOut() async {}

  @override
  Future<PremiumInfo> currentInfo() async => PremiumInfo.none;

  @override
  Future<PremiumOffer?> annualOffer() async => null;

  @override
  Future<PremiumInfo> purchase(PremiumOffer offer) async => PremiumInfo.none;

  @override
  Future<PremiumInfo> restore() async => PremiumInfo.none;
}

final purchasesGatewayProvider =
    Provider<PurchasesGateway>((_) => const NoPurchasesGateway());
