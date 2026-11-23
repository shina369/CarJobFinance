// The premium subscription sold through RevenueCat (Google Play / App Store).
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../config/env.dart';
import 'purchases_gateway.dart';

/// The entitlement configured in the RevenueCat dashboard.
const premiumEntitlementId = 'premium';

PremiumInfo premiumInfoFrom(CustomerInfo info) {
  final entitlement = info.entitlements.active[premiumEntitlementId];
  if (entitlement == null || !entitlement.isActive) return PremiumInfo.none;
  final expiration = entitlement.expirationDate;
  return PremiumInfo(
    isPremium: true,
    expiresAt: expiration == null ? null : DateTime.tryParse(expiration),
    willRenew: entitlement.willRenew,
  );
}

/// [locale] formats [PremiumOffer.monthlyText]; defaults to Intl's locale.
PremiumOffer? annualOfferFrom(Offerings offerings, {String? locale}) {
  final package = _annualPackage(offerings);
  if (package == null) return null;
  final product = package.storeProduct;
  final monthly = NumberFormat.simpleCurrency(
    locale: Intl.verifiedLocale(
      locale ?? Intl.getCurrentLocale(),
      NumberFormat.localeExists,
      onFailure: (_) => 'en_US',
    ),
    name: product.currencyCode,
  ).format(product.price / 12);
  return PremiumOffer(
    packageId: package.identifier,
    priceText: product.priceString,
    monthlyText: monthly,
    trialDays: _freeTrialDays(product.introductoryPrice),
  );
}

Package? _annualPackage(Offerings offerings) {
  final offering = offerings.current;
  if (offering == null) return null;
  return offering.annual ??
      offering.availablePackages
          .firstWhereOrNull((p) => p.packageType == PackageType.annual);
}

/// On Google Play the SDK only reports offers the account is eligible for.
int? _freeTrialDays(IntroductoryPrice? intro) {
  if (intro == null || intro.price != 0) return null;
  final unitDays = switch (intro.periodUnit) {
    PeriodUnit.day => 1,
    PeriodUnit.week => 7,
    PeriodUnit.month => 30,
    PeriodUnit.year => 365,
    PeriodUnit.unknown => null,
  };
  if (unitDays == null || intro.periodNumberOfUnits <= 0) return null;
  final cycles = intro.cycles < 1 ? 1 : intro.cycles;
  return unitDays * intro.periodNumberOfUnits * cycles;
}

class RevenueCatGateway implements PurchasesGateway {
  RevenueCatGateway._();

  /// Null where the store cannot be used: not Android/iOS, no SDK key, or the
  /// SDK failed to start. Never throws, so the app still boots.
  static Future<RevenueCatGateway?> configure(Env env) async {
    if (kIsWeb) return null;
    final apiKey = switch (defaultTargetPlatform) {
      TargetPlatform.android => env.revenueCatAndroidKey,
      // No App Store key yet: iOS runs without purchases until one exists.
      TargetPlatform.iOS => null,
      _ => null,
    };
    if (apiKey == null || apiKey.trim().isEmpty) return null;
    try {
      if (kDebugMode) await Purchases.setLogLevel(LogLevel.debug);
      await Purchases.configure(PurchasesConfiguration(apiKey.trim()));
      return RevenueCatGateway._();
    } catch (error) {
      debugPrint('RevenueCat not configured: $error');
      return null;
    }
  }

  /// The SDK is one static identity: account switches run one at a time.
  Future<void> _switching = Future.value();

  /// The current account's last answer, for when the store is unreachable.
  PremiumInfo? _lastKnown;

  bool _replaying = false;

  late final StreamController<PremiumInfo> _updates =
      StreamController.broadcast(
    onListen: _startListening,
    onCancel: () => Purchases.removeCustomerInfoUpdateListener(_onCustomerInfo),
  );

  @override
  Stream<PremiumInfo> get updates => _updates.stream;

  /// The SDK replays its last update to a new listener; it may belong to the
  /// previous account, and [currentInfo] already answers for this one.
  void _startListening() {
    _replaying = true;
    try {
      Purchases.addCustomerInfoUpdateListener(_onCustomerInfo);
    } finally {
      _replaying = false;
    }
  }

  void _onCustomerInfo(CustomerInfo info) {
    if (!_replaying) _updates.add(premiumInfoFrom(info));
  }

  Future<void> _oneAtATime(Future<void> Function() call) {
    final next = _switching.then((_) => call());
    _switching = next.then((_) {}, onError: (_) {});
    return next;
  }

  @override
  Future<void> logIn(String userId) => _oneAtATime(() async {
        _lastKnown = null;
        final result = await Purchases.logIn(userId);
        _lastKnown = premiumInfoFrom(result.customerInfo);
      });

  @override
  Future<void> logOut() => _oneAtATime(() async {
        _lastKnown = null;
        try {
          await Purchases.logOut();
        } on PlatformException catch (error) {
          // Already anonymous: there is nothing to log out of.
          if (PurchasesErrorHelper.getErrorCode(error) !=
              PurchasesErrorCode.logOutWithAnonymousUserError) {
            rethrow;
          }
        }
      });

  @override
  Future<PremiumInfo> currentInfo() async {
    try {
      return _lastKnown = premiumInfoFrom(await Purchases.getCustomerInfo());
    } catch (_) {
      final lastKnown = _lastKnown;
      if (lastKnown != null) return lastKnown;
      rethrow;
    }
  }

  @override
  Future<PremiumOffer?> annualOffer() async {
    try {
      return annualOfferFrom(
        await Purchases.getOfferings(),
        locale: PlatformDispatcher.instance.locale.toString(),
      );
    } catch (error) {
      debugPrint('RevenueCat offerings unavailable: $error');
      return null;
    }
  }

  @override
  Future<PremiumInfo> purchase(PremiumOffer offer) async {
    final offering = (await Purchases.getOfferings()).current;
    final package = offering?.getPackage(offer.packageId);
    if (package == null) {
      throw StateError('Package ${offer.packageId} is no longer offered');
    }
    try {
      final result = await Purchases.purchase(PurchaseParams.package(package));
      return _lastKnown = premiumInfoFrom(result.customerInfo);
    } on PlatformException catch (error) {
      if (PurchasesErrorHelper.getErrorCode(error) ==
          PurchasesErrorCode.purchaseCancelledError) {
        throw const PurchaseCancelled();
      }
      rethrow;
    }
  }

  @override
  Future<PremiumInfo> restore() async =>
      _lastKnown = premiumInfoFrom(await Purchases.restorePurchases());
}
