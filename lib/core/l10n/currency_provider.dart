// Currency provider for the CarJobFinance app.
// Manages the user-selected currency independently of the country/language.
//
// On first run the currency defaults to the country's currency (set by
// onboarding). The user can later override it from Settings > Aparência.
// Changing currency only changes the on-screen symbol/format; recorded
// values are NOT converted.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:carjobfinance/core/l10n/currencies.dart';
import 'package:carjobfinance/core/settings/app_settings_notifier.dart';
import 'package:carjobfinance/data/datasources/local/daos.dart' show AppDao;

/// Persisted currency preference, stored in the settings table.
class AppCurrencyPref {
  const AppCurrencyPref({
    required this.currency,
    required this.countryCode,
  });

  /// The selected currency.
  final AppCurrency currency;

  /// The country the user selected (used to pick the default currency
  /// on first run, or after a reset).
  final String countryCode;

  static AppCurrencyPref defaultFor(String countryCode) => AppCurrencyPref(
        currency: defaultCurrencyForCountry(countryCode),
        countryCode: countryCode,
      );
}

/// StateNotifier that persists the user's currency choice in the AppDao
/// settings table (key `app_currency`).
class CurrencyNotifier extends StateNotifier<AppCurrencyPref> {
  final AppDao _dao;

  static const _storageKey = 'app_currency';

  bool _disposed = false;

  CurrencyNotifier(this._dao, AppCurrencyPref initialState)
      : super(initialState);

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Load the stored preference. If none exists, fall back to the
  /// country's default currency.
  Future<void> initialize() async {
    if (_disposed) return;
    final stored = await _dao.getSetting(_storageKey);
    if (_disposed) return;
    final country = state.countryCode;
    if (stored != null && currencyForCode(stored) != null) {
      state = AppCurrencyPref(
        currency: currencyForCode(stored)!,
        countryCode: country,
      );
      return;
    }
    state = AppCurrencyPref.defaultFor(country);
  }

  /// Pick a new currency and persist it.
  Future<void> setCurrency(AppCurrency currency) async {
    if (_disposed) return;
    await _dao.setSetting(_storageKey, currency.code);
    if (_disposed) return;
    state = AppCurrencyPref(currency: currency, countryCode: state.countryCode);
  }

  /// Reset the currency back to the country default (e.g. after a data
  /// clear).
  Future<void> resetToCountryDefault() async {
    if (_disposed) return;
    await _dao.deleteSetting(_storageKey);
    if (_disposed) return;
    state = AppCurrencyPref.defaultFor(state.countryCode);
  }
}

/// AppDao provider (reused from the settings module).
final currencyDaoProvider = Provider<AppDao>((ref) {
  return ref.watch(appDaoProviderForSettings);
});

/// StateNotifier that tracks the currency. Initialized with the
/// current country code from the settings provider.
final currencyProvider =
    StateNotifierProvider<CurrencyNotifier, AppCurrencyPref>(
  (ref) {
    final settings = ref.watch(appSettingsProvider);
    final notifier = CurrencyNotifier(ref.watch(currencyDaoProvider),
        AppCurrencyPref.defaultFor(settings.countryCode));
    // Riverpod disposes the notifier automatically when the container
    // or the provider itself is disposed — do NOT add a manual
    // ref.onDispose(notifier.dispose): it would run after Riverpod's
    // own dispose and throw "Tried to use after dispose".
    notifier.initialize();
    return notifier;
  },
);

/// Convenience provider to fetch the current currency.
final appCurrencyProvider = Provider<AppCurrency>((ref) {
  return ref.watch(currencyProvider).currency;
});
