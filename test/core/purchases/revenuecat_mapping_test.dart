import 'package:carjobfinance/core/purchases/purchases_gateway.dart';
import 'package:carjobfinance/core/purchases/revenuecat_gateway.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

EntitlementInfo _entitlement({
  String id = 'premium',
  bool isActive = true,
  bool willRenew = true,
  String? expirationDate = '2027-01-15T10:30:00Z',
}) {
  return EntitlementInfo(
    id,
    isActive,
    willRenew,
    '2026-01-15T10:30:00Z',
    '2026-01-15T10:30:00Z',
    'carjob_premium_annual',
    false,
    expirationDate: expirationDate,
  );
}

CustomerInfo _customer(List<EntitlementInfo> entitlements) {
  final all = {for (final e in entitlements) e.identifier: e};
  final active = {
    for (final e in entitlements)
      if (e.isActive) e.identifier: e,
  };
  return CustomerInfo(
    EntitlementInfos(all, active),
    const {},
    const [],
    const [],
    const [],
    '2026-01-01T00:00:00Z',
    'user-1',
    const {},
    '2026-11-23T00:00:00Z',
  );
}

StoreProduct _product({
  double price = 99.9,
  String priceString = r'R$ 99,90',
  String currencyCode = 'BRL',
  IntroductoryPrice? intro,
}) {
  return StoreProduct(
    'carjob_premium_annual',
    'Premium',
    'Premium (CarJob)',
    price,
    priceString,
    currencyCode,
    introductoryPrice: intro,
    subscriptionPeriod: 'P1Y',
  );
}

const _context = PresentedOfferingContext('default', null, null);

Package _package(PackageType type, StoreProduct product, {String? id}) =>
    Package(id ?? '\$rc_${type.name}', type, product, _context);

Offerings _offerings(List<Package> packages, {bool setAnnual = true}) {
  Package? annual;
  for (final p in packages) {
    if (p.packageType == PackageType.annual) annual = p;
  }
  final offering = Offering(
    'default',
    'Default',
    const {},
    packages,
    annual: setAnnual ? annual : null,
  );
  return Offerings({'default': offering}, current: offering);
}

IntroductoryPrice _intro({
  double price = 0,
  PeriodUnit unit = PeriodUnit.day,
  int units = 7,
  int cycles = 1,
}) {
  return IntroductoryPrice(
    price,
    price == 0 ? 'Free' : r'R$ 1,99',
    'P$units${unit.name[0].toUpperCase()}',
    cycles,
    unit,
    units,
  );
}

void main() {
  group('premiumInfoFrom', () {
    test('an active premium entitlement is premium with its dates', () {
      final info = premiumInfoFrom(_customer([_entitlement(willRenew: false)]));

      expect(info.isPremium, isTrue);
      expect(info.expiresAt, DateTime.utc(2027, 1, 15, 10, 30));
      expect(info.willRenew, isFalse);
    });

    test('a lifetime entitlement has no expiry', () {
      final info = premiumInfoFrom(
        _customer([_entitlement(expirationDate: null)]),
      );

      expect(info.isPremium, isTrue);
      expect(info.expiresAt, isNull);
      expect(info.willRenew, isTrue);
    });

    test('no entitlement is none', () {
      expect(premiumInfoFrom(_customer([])), PremiumInfo.none);
    });

    test('an expired premium entitlement is none', () {
      expect(
        premiumInfoFrom(_customer([_entitlement(isActive: false)])),
        PremiumInfo.none,
      );
    });

    test('another active entitlement is none', () {
      expect(
        premiumInfoFrom(_customer([_entitlement(id: 'pro')])),
        PremiumInfo.none,
      );
    });
  });

  group('annualOfferFrom', () {
    test('maps the annual package of the current offering', () {
      final offer = annualOfferFrom(
        _offerings([
          _package(PackageType.monthly, _product(price: 12.9)),
          _package(PackageType.annual, _product(intro: _intro())),
        ]),
        locale: 'pt_BR',
      );

      expect(offer, isNotNull);
      expect(offer!.packageId, r'$rc_annual');
      expect(offer.priceText, r'R$ 99,90');
      expect(offer.monthlyText, 'R\$ 8,33');
      expect(offer.trialDays, 7);
    });

    test('formats the monthly price in the product currency', () {
      final offer = annualOfferFrom(
        _offerings([
          _package(
            PackageType.annual,
            _product(price: 47.88, priceString: r'$47.88', currencyCode: 'USD'),
          ),
        ]),
        locale: 'en_US',
      );

      expect(offer!.monthlyText, r'$3.99');
    });

    test('finds the annual package when the offering has no annual slot', () {
      final offer = annualOfferFrom(
        _offerings(
          [_package(PackageType.annual, _product(), id: 'yearly')],
          setAnnual: false,
        ),
        locale: 'pt_BR',
      );

      expect(offer?.packageId, 'yearly');
    });

    test('converts week and month trial periods to days', () {
      int? trialFor(IntroductoryPrice intro) => annualOfferFrom(
            _offerings([_package(PackageType.annual, _product(intro: intro))]),
            locale: 'pt_BR',
          )!
              .trialDays;

      expect(trialFor(_intro(unit: PeriodUnit.week, units: 2)), 14);
      expect(trialFor(_intro(unit: PeriodUnit.month, units: 1)), 30);
      expect(trialFor(_intro(unit: PeriodUnit.day, units: 3, cycles: 2)), 6);
    });

    test('has no trial without a free introductory price', () {
      int? trialFor(IntroductoryPrice? intro) => annualOfferFrom(
            _offerings([_package(PackageType.annual, _product(intro: intro))]),
            locale: 'pt_BR',
          )!
              .trialDays;

      expect(trialFor(null), isNull);
      expect(trialFor(_intro(price: 1.99)), isNull);
      expect(trialFor(_intro(unit: PeriodUnit.unknown)), isNull);
    });

    test('is null without an annual package', () {
      expect(
        annualOfferFrom(
          _offerings([_package(PackageType.monthly, _product())]),
          locale: 'pt_BR',
        ),
        isNull,
      );
    });

    test('is null without a current offering', () {
      expect(annualOfferFrom(const Offerings({}), locale: 'pt_BR'), isNull);
    });
  });
}
