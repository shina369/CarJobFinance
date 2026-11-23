import 'dart:async';

import 'package:carjobfinance/core/purchases/purchases_gateway.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const PremiumInfo activePremium = PremiumInfo(isPremium: true, willRenew: true);

const PremiumOffer annualTestOffer = PremiumOffer(
  packageId: '\$rc_annual',
  priceText: 'R\$ 59,90',
  monthlyText: 'R\$ 4,99',
  trialDays: 7,
);

class FakePurchasesGateway implements PurchasesGateway {
  FakePurchasesGateway({
    this.info = PremiumInfo.none,
    this.offer = annualTestOffer,
  });

  PremiumInfo info;
  PremiumOffer? offer;

  /// Thrown by [currentInfo], [purchase] and [restore] while set.
  Object? error;

  /// Applied to every call before it returns.
  Duration? delay;

  final StreamController<PremiumInfo> push =
      StreamController<PremiumInfo>.broadcast();

  /// Every call in the order it was made, e.g. `logIn:user-1`, `logOut`.
  final List<String> calls = [];

  List<String> get loggedIn => [
        for (final call in calls)
          if (call.startsWith('logIn:')) call.substring('logIn:'.length),
      ];

  int get logOutCalls => calls.where((call) => call == 'logOut').length;

  Future<void> _step(String call) async {
    calls.add(call);
    final wait = delay;
    if (wait != null) await Future<void>.delayed(wait);
  }

  void _maybeThrow() {
    final pending = error;
    if (pending != null) throw pending;
  }

  @override
  Stream<PremiumInfo> get updates => push.stream;

  @override
  Future<void> logIn(String userId) => _step('logIn:$userId');

  @override
  Future<void> logOut() => _step('logOut');

  @override
  Future<PremiumInfo> currentInfo() async {
    await _step('currentInfo');
    _maybeThrow();
    return info;
  }

  @override
  Future<PremiumOffer?> annualOffer() async {
    await _step('annualOffer');
    return offer;
  }

  @override
  Future<PremiumInfo> purchase(PremiumOffer offer) async {
    await _step('purchase:${offer.packageId}');
    _maybeThrow();
    return info = activePremium;
  }

  @override
  Future<PremiumInfo> restore() async {
    await _step('restore');
    _maybeThrow();
    return info;
  }
}

Override premiumGatewayOverride({bool premium = true}) =>
    purchasesGatewayProvider.overrideWithValue(
      FakePurchasesGateway(info: premium ? activePremium : PremiumInfo.none),
    );
