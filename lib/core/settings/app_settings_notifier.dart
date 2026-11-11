// AppSettings Riverpod StateNotifier
// Manages country-aware application settings including currency, locale, and platforms
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:carjobfinance/core/settings/country_data.dart';
import 'package:carjobfinance/data/datasources/local/daos.dart';
import 'package:carjobfinance/data/datasources/local/app_database.dart';
/// Immutable value object holding the current app settings state.
@immutable
class AppSettings {
  const AppSettings({
    required this.countryCode,
    required this.currencyCode,
    required this.currencySymbol,
    required this.localeTag,
    required this.platforms,
    required this.configured,
  });

  /// ISO 3166-1 alpha-2 country code (e.g. 'BR').
  final String countryCode;

  /// ISO 4217 currency code (e.g. 'BRL').
  final String currencyCode;

  /// Currency symbol as displayed to the user (e.g. 'R$').
  final String currencySymbol;

  /// BCP 47 locale tag used for number/currency formatting.
  final String localeTag;

  /// List of ride-hailing platforms available in the selected country.
  final List<String> platforms;

  /// True if the user has explicitly chosen a country (i.e., app_country setting exists).
  /// False when falling back to Brazil default with no stored value.
  final bool configured;

  /// Creates default settings for Brazil (fallback when no user preference is stored).
  static AppSettings defaultBrazil() {
    final br = COUNTRIES.firstWhere((c) => c.code == 'BR');
    return AppSettings(
      countryCode: br.code,
      currencyCode: br.currencyCode,
      currencySymbol: br.currencySymbol,
      localeTag: br.localeTag,
      platforms: br.platforms,
      configured: false,
    );
  }

  /// Creates settings from a CountryEntry with configured = true.
  static AppSettings fromCountry(CountryEntry country, List<String> platforms) {
    return AppSettings(
      countryCode: country.code,
      currencyCode: country.currencyCode,
      currencySymbol: country.currencySymbol,
      localeTag: country.localeTag,
      platforms: platforms,
      configured: true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettings &&
          runtimeType == other.runtimeType &&
          countryCode == other.countryCode &&
          currencyCode == other.currencyCode &&
          currencySymbol == other.currencySymbol &&
          localeTag == other.localeTag &&
          platforms.length == other.platforms.length &&
          platforms.every((p) => other.platforms.contains(p)) &&
          configured == other.configured;

  @override
  int get hashCode =>
      countryCode.hashCode ^
      currencyCode.hashCode ^
      currencySymbol.hashCode ^
      localeTag.hashCode ^
      platforms.hashCode ^
      configured.hashCode;

  @override
  String toString() =>
      'AppSettings(countryCode: $countryCode, currencyCode: $currencyCode, '
      'currencySymbol: $currencySymbol, localeTag: $localeTag, '
      'platforms: $platforms, configured: $configured)';
}

/// StateNotifier managing app settings with country-aware state.
class AppSettingsNotifier extends StateNotifier<AppSettings> {
  final AppDao _dao;
  final CountryPlatformsDao _countryPlatformsDao;

  AppSettingsNotifier(AppDao dao, CountryPlatformsDao countryPlatformsDao)
      : _dao = dao,
        _countryPlatformsDao = countryPlatformsDao,
        super(AppSettings.defaultBrazil());

  /// Creates a notifier for testing purposes.
  /// Subclasses can pass mock DAOs and override DAO-backed methods
  /// (e.g. [setCountry]) to avoid touching a real database.
  @visibleForTesting
  AppSettingsNotifier.forTesting(
    AppDao dao,
    CountryPlatformsDao countryPlatformsDao,
    super.initialState,
  )   : _dao = dao,
        _countryPlatformsDao = countryPlatformsDao;

  /// Initializes settings by reading the stored country preference.
  /// Falls back to Brazil defaults if no preference is stored.
  Future<void> initialize() async {
    final storedCountryCode = await _dao.getSetting('app_country');
    final countryCode = storedCountryCode ?? 'BR';

    // Re-seed the country's platform list so app updates that change the
    // COUNTRIES constant reach the table without a schema bump. Upserts are
    // idempotent.
    final countryEntry = COUNTRIES.firstWhere(
      (c) => c.code == countryCode,
      orElse: () => COUNTRIES.firstWhere((c) => c.code == 'BR'),
    );
    await _countryPlatformsDao.upsertCountryPlatforms(
      countryEntry.code,
      countryEntry.platforms,
    );

    // Purge retired platform names from the table. COUNTRIES no longer
    // lists them, but older DBs still hold rows seeded before the change.
    await _countryPlatformsDao.deleteObsoletePlatforms(OBSOLETE_PLATFORM_NAMES);

    if (storedCountryCode == null) {
      // No stored preference - keep Brazil defaults with configured = false
      state = AppSettings.defaultBrazil();
      return;
    }

    // Load settings for the stored country
    await _loadCountrySettings(storedCountryCode);
  }

  /// Loads settings for a specific country code.
  Future<void> _loadCountrySettings(String countryCode) async {
    final countryEntry = COUNTRIES.firstWhere(
      (c) => c.code == countryCode,
      orElse: () => COUNTRIES.firstWhere((c) => c.code == 'BR'),
    );
    final platforms = await _countryPlatformsDao.getPlatformNames(countryCode);
    state = AppSettings.fromCountry(countryEntry, platforms);
  }

  /// Sets a new country, persists the choice, and updates state.
  Future<void> setCountry(String countryCode) async {
    // Validate country code exists
    final countryEntry = COUNTRIES.firstWhere(
      (c) => c.code == countryCode,
      orElse: () => COUNTRIES.firstWhere((c) => c.code == 'BR'),
    );

    // Persist the choice
    await _dao.setSetting('app_country', countryCode);

    // Load platforms and update state
    final platforms = await _countryPlatformsDao.getPlatformNames(countryCode);
    state = AppSettings.fromCountry(countryEntry, platforms);
  }

  /// Resets to Brazil defaults and clears the stored preference.
  Future<void> resetToDefault() async {
    await _dao.deleteSetting('app_country');
    state = AppSettings.defaultBrazil();
  }
}

/// Riverpod provider for CountryPlatformsDao.
final countryPlatformsDaoProvider = Provider<CountryPlatformsDao>(
  (ref) => ref.watch(appDatabaseProviderForSettings).countryPlatformsDao,
);

/// Riverpod provider for AppSettingsNotifier.
final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>(
  (ref) => AppSettingsNotifier(
    ref.watch(appDaoProviderForSettings),
    ref.watch(countryPlatformsDaoProvider),
  ),
);

/// Standalone AppDao provider for settings (avoids circular import with controllers.dart).
final appDaoProviderForSettings = Provider<AppDao>(
  (ref) => AppDao(ref.watch(appDatabaseProviderForSettings)),
);

/// Standalone AppDatabase provider for settings (avoids circular import with controllers.dart).
final appDatabaseProviderForSettings = Provider<AppDatabase>((ref) {
  return AppDatabase();
});