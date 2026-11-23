import 'package:carjobfinance/core/config/env.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const base = {
    'SUPABASE_URL': 'u',
    'SUPABASE_PUBLISHABLE_KEY': 'k',
  };

  test('parses optional RevenueCat key and premium override', () {
    final env = Env.fromMap({
      ...base,
      'PREMIUM_OVERRIDE': 'true',
      'REVENUECAT_ANDROID_KEY': 'rc',
    });

    expect(env.supabaseUrl, 'u');
    expect(env.supabaseKey, 'k');
    expect(env.premiumOverride, isTrue);
    expect(env.revenueCatAndroidKey, 'rc');
  });

  test('parses PREMIUM_OVERRIDE=false', () {
    final env = Env.fromMap({...base, 'PREMIUM_OVERRIDE': 'false'});

    expect(env.premiumOverride, isFalse);
  });

  test('optional keys are null when absent or blank', () {
    final absent = Env.fromMap(base);
    final blank = Env.fromMap({
      ...base,
      'PREMIUM_OVERRIDE': ' ',
      'REVENUECAT_ANDROID_KEY': '',
    });

    expect(absent.premiumOverride, isNull);
    expect(absent.revenueCatAndroidKey, isNull);
    expect(blank.premiumOverride, isNull);
    expect(blank.revenueCatAndroidKey, isNull);
  });

  test('throws StateError when SUPABASE_URL is missing', () {
    expect(
      () => Env.fromMap({'SUPABASE_PUBLISHABLE_KEY': 'k'}),
      throwsStateError,
    );
  });
}
