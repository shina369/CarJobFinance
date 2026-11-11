// Currency catalog for the CarJobFinance app.
// One entry per supported country, keyed by country code.
//
// The currency is independent of the language/country: the user can pick
// any currency from Settings > Aparência > Moeda and only the on-screen
// symbol + number format changes — recorded values are NOT converted.

/// A single currency entry.
class AppCurrency {
  const AppCurrency({
    required this.code,
    required this.symbol,
    required this.displayName,
    required this.formatTag,
  });

  /// ISO 4217 currency code (e.g. 'BRL').
  final String code;

  /// Display symbol (e.g. 'R$', '€').
  final String symbol;

  /// Display name, localized to its own language (e.g. 'Real brasileiro').
  final String displayName;

  /// BCP 47 tag used ONLY for [NumberFormat] separators. Not an app locale.
  final String formatTag;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppCurrency &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          symbol == other.symbol &&
          displayName == other.displayName &&
          formatTag == other.formatTag;

  @override
  int get hashCode => Object.hash(code, symbol, displayName, formatTag);

  @override
  String toString() =>
      'AppCurrency($code, $symbol, $displayName, format: $formatTag)';
}

/// The full catalog, one entry per country in [COUNTRIES].
/// EUR appears twice (PT and ES) — the catalog is keyed by country, exactly
/// like [COUNTRIES], so [defaultCurrencyForCountry] resolves unambiguously.
// ignore: constant_identifier_names
const List<AppCurrency> SUPPORTED_CURRENCIES = [
  AppCurrency(
    code: 'BRL',
    symbol: r'R$',
    displayName: 'Real brasileiro',
    formatTag: 'pt_BR',
  ),
  AppCurrency(
    code: 'EUR',
    symbol: '€',
    displayName: 'Euro',
    formatTag: 'pt_PT',
  ),
  AppCurrency(
    code: 'MXN',
    symbol: r'$',
    displayName: 'Peso mexicano',
    formatTag: 'es_MX',
  ),
  AppCurrency(
    code: 'COP',
    symbol: r'$',
    displayName: 'Peso colombiano',
    formatTag: 'es_CO',
  ),
  AppCurrency(
    code: 'CLP',
    symbol: r'$',
    displayName: 'Peso chileno',
    formatTag: 'es_CL',
  ),
  AppCurrency(
    code: 'ARS',
    symbol: r'$',
    displayName: 'Peso argentino',
    formatTag: 'es_AR',
  ),
  AppCurrency(
    code: 'USD',
    symbol: r'$',
    displayName: 'Dólar americano',
    formatTag: 'en_US',
  ),
  AppCurrency(
    code: 'EUR',
    symbol: '€',
    displayName: 'Euro',
    formatTag: 'es_ES',
  ),
  AppCurrency(
    code: 'IDR',
    symbol: 'Rp',
    displayName: 'Rupiah',
    formatTag: 'id_ID',
  ),
  AppCurrency(
    code: 'INR',
    symbol: '₹',
    displayName: 'Rupia indiana',
    formatTag: 'hi_IN',
  ),
];

/// Find a currency by ISO 4217 code.
AppCurrency? currencyForCode(String code) {
  for (final c in SUPPORTED_CURRENCIES) {
    if (c.code == code) return c;
  }
  return null;
}

/// Country code → catalog index. Explicit so EUR (which appears twice,
/// once per country) resolves to the right entry.
// ignore: constant_identifier_names
const Map<String, int> _COUNTRY_TO_CURRENCY_INDEX = {
  'BR': 0,
  'PT': 1,
  'MX': 2,
  'CO': 3,
  'CL': 4,
  'AR': 5,
  'US': 6,
  'ES': 7,
  'ID': 8,
  'IN': 9,
};

/// Default currency for a country, falling back to BRL.
AppCurrency defaultCurrencyForCountry(String countryCode) {
  final index = _COUNTRY_TO_CURRENCY_INDEX[countryCode];
  if (index == null) return SUPPORTED_CURRENCIES.first;
  return SUPPORTED_CURRENCIES[index];
}
