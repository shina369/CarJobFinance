// Language provider for the CarJobFinance app.
// Manages the user-selected language independently of the country.
//
// On first run the language defaults to the country's default (set by
// onboarding). The user can later override it from Settings.
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:carjobfinance/core/l10n/languages.dart';
import 'package:carjobfinance/core/settings/app_settings_notifier.dart';
import 'package:carjobfinance/data/datasources/local/daos.dart' show AppDao;

/// Persisted language preference, stored in the settings table.
class AppLanguagePref {
  const AppLanguagePref({
    required this.language,
    required this.countryCode,
  });

  /// The selected language.
  final AppLanguage language;

  /// The country the user selected (used to pick the default language
  /// on first run, or after a reset).
  final String countryCode;

  /// The locale to feed into [MaterialApp.locale].
  Locale get locale => language.locale;

  /// The language tag to feed into the string bundle.
  String get tag => language.tag;

  static AppLanguagePref defaultFor(String countryCode) => AppLanguagePref(
        language: defaultLanguageForCountry(countryCode),
        countryCode: countryCode,
      );
}

/// StateNotifier that persists the user's language choice in the AppDao
/// settings table (key `app_language`).
class LanguageNotifier extends StateNotifier<AppLanguagePref> {
  final AppDao _dao;

  static const _storageKey = 'app_language';

  bool _disposed = false;

  /// Whether the user (or the onboarding) picked a language, as opposed to
  /// the one derived from the country.
  bool hasChosenLanguage = false;

  LanguageNotifier(this._dao, AppLanguagePref initialState)
      : super(initialState);

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Load the stored preference. If none exists, fall back to the
  /// country's default language.
  Future<void> initialize() async {
    if (_disposed) return;
    final stored = await _dao.getSetting(_storageKey);
    if (_disposed) return;
    final country = state.countryCode;
    if (stored != null && languageForTag(stored) != null) {
      hasChosenLanguage = true;
      state = AppLanguagePref(
        language: languageForTag(stored)!,
        countryCode: country,
      );
      return;
    }
    state = AppLanguagePref.defaultFor(country);
  }

  /// Pick a new language and persist it.
  Future<void> setLanguage(AppLanguage lang) async {
    if (_disposed) return;
    hasChosenLanguage = true;
    await _dao.setSetting(_storageKey, lang.tag);
    if (_disposed) return;
    state = AppLanguagePref(language: lang, countryCode: state.countryCode);
  }

  /// Reset the language back to the country default (e.g. after country
  /// changes or a data clear).
  Future<void> resetToCountryDefault() async {
    if (_disposed) return;
    await _dao.deleteSetting(_storageKey);
    if (_disposed) return;
    hasChosenLanguage = false;
    state = AppLanguagePref.defaultFor(state.countryCode);
  }
}

/// AppDao provider (reused from the settings module).
final languageDaoProvider = Provider<AppDao>((ref) {
  return ref.watch(appDaoProviderForSettings);
});

/// StateNotifier that tracks the language. Initialized with the
/// current country code from the settings provider.
final languageProvider =
    StateNotifierProvider<LanguageNotifier, AppLanguagePref>(
  (ref) {
    final settings = ref.watch(appSettingsProvider);
    final notifier = LanguageNotifier(ref.watch(languageDaoProvider),
        AppLanguagePref.defaultFor(settings.countryCode));
    // Riverpod disposes the notifier automatically when the container
    // or the provider itself is disposed — do NOT add a manual
    // ref.onDispose(notifier.dispose): it would run after Riverpod's
    // own dispose and throw "Tried to use after dispose".
    notifier.initialize();
    return notifier;
  },
);

/// Current [Locale] for the [MaterialApp.locale].
final appLocaleProvider = Provider<Locale>((ref) {
  return ref.watch(languageProvider).locale;
});

/// Convenience provider to fetch the current language.
final appLanguageProvider = Provider<AppLanguage>((ref) {
  return ref.watch(languageProvider).language;
});
