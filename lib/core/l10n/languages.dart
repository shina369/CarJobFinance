// Language definitions for the app.
// Each language has a BCP 47 tag, a display name (in its own language),
// an optional flag emoji, and the countries it is the default for.
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/widgets.dart' show Locale;

@immutable
class AppLanguage {
  const AppLanguage({
    required this.tag,
    required this.displayName,
    this.flag,
    required this.defaultForCountries,
  });

  /// BCP 47 locale tag (e.g. 'pt_BR').
  final String tag;

  /// Display name in the language itself (e.g. "Português (Brasil)").
  final String displayName;

  /// Flag emoji associated with the language (used in UI dropdowns).
  final String? flag;

  /// Country codes for which this language is the default.
  final Set<String> defaultForCountries;

  Locale get locale {
    final parts = tag.split('_');
    final lang = parts.first;
    final country = parts.length > 1 ? parts[1] : null;
    return country == null ? Locale(lang) : Locale(lang, country);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppLanguage &&
          runtimeType == other.runtimeType &&
          tag == other.tag;

  @override
  int get hashCode => tag.hashCode;

  @override
  String toString() => 'AppLanguage($tag)';
}

/// All supported languages for the app.
// ignore: constant_identifier_names
const List<AppLanguage> SUPPORTED_LANGUAGES = [
  AppLanguage(
    tag: 'pt_BR',
    displayName: 'Português (Brasil)',
    flag: '🇧🇷',
    defaultForCountries: {'BR'},
  ),
  AppLanguage(
    tag: 'pt_PT',
    displayName: 'Português (Portugal)',
    flag: '🇵🇹',
    defaultForCountries: {'PT'},
  ),
  AppLanguage(
    tag: 'es_MX',
    displayName: 'Español (México)',
    flag: '🇲🇽',
    defaultForCountries: {'MX'},
  ),
  AppLanguage(
    tag: 'es_CO',
    displayName: 'Español (Colombia)',
    flag: '🇨🇴',
    defaultForCountries: {'CO'},
  ),
  AppLanguage(
    tag: 'es_CL',
    displayName: 'Español (Chile)',
    flag: '🇨🇱',
    defaultForCountries: {'CL'},
  ),
  AppLanguage(
    tag: 'es_AR',
    displayName: 'Español (Argentina)',
    flag: '🇦🇷',
    defaultForCountries: {'AR'},
  ),
  AppLanguage(
    tag: 'es_ES',
    displayName: 'Español (España)',
    flag: '🇪🇸',
    defaultForCountries: {'ES'},
  ),
  AppLanguage(
    tag: 'en_US',
    displayName: 'English (US)',
    flag: '🇺🇸',
    defaultForCountries: {'US'},
  ),
  AppLanguage(
    tag: 'id_ID',
    displayName: 'Bahasa Indonesia',
    flag: '🇮🇩',
    defaultForCountries: {'ID'},
  ),
  AppLanguage(
    tag: 'hi_IN',
    displayName: 'हिन्दी (भारत)',
    flag: '🇮🇳',
    defaultForCountries: {'IN'},
  ),
];

/// One entry of the sign-in language picker. All Spanish variants share a
/// single entry; the other languages are listed as they are.
@immutable
class SignInLanguage {
  const SignInLanguage({
    required this.language,
    required this.label,
    required this.flagCountry,
    this.family,
  });

  /// The language applied when the entry is picked.
  final AppLanguage language;
  final String label;

  /// Country whose flag illustrates the entry.
  final String flagCountry;

  /// Language code covered by the entry, when it stands for several variants.
  final String? family;

  /// Whether [other] is the entry's language, or one of its variants.
  bool covers(AppLanguage other) =>
      other == language ||
      (family != null && other.locale.languageCode == family);
}

/// Languages offered on the sign-in page: Spanish once, the rest unchanged.
List<SignInLanguage> signInLanguages() {
  final options = <SignInLanguage>[];
  var spanishAdded = false;
  for (final lang in SUPPORTED_LANGUAGES) {
    final country = lang.tag.split('_').last;
    if (lang.locale.languageCode == 'es') {
      if (spanishAdded) continue;
      spanishAdded = true;
      options.add(SignInLanguage(
        language: lang,
        label: 'Español',
        flagCountry: 'ES',
        family: 'es',
      ));
      continue;
    }
    options.add(SignInLanguage(
      language: lang,
      label: lang.displayName,
      flagCountry: country,
    ));
  }
  return options;
}

/// Find a language by tag.
AppLanguage? languageForTag(String tag) {
  for (final lang in SUPPORTED_LANGUAGES) {
    if (lang.tag == tag) return lang;
  }
  return null;
}

/// Default language for a country code.
AppLanguage defaultLanguageForCountry(String countryCode) {
  for (final lang in SUPPORTED_LANGUAGES) {
    if (lang.defaultForCountries.contains(countryCode)) return lang;
  }
  return SUPPORTED_LANGUAGES.first; // pt_BR fallback
}
