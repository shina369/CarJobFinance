// LocalizedCurrency helper for formatting currency values based on locale
// Uses intl package for number formatting and COUNTRIES for currency symbol lookup

import 'package:intl/intl.dart';
import 'package:carjobfinance/core/l10n/currencies.dart';
import 'package:carjobfinance/core/settings/country_data.dart';
import 'package:carjobfinance/core/settings/app_settings_notifier.dart';

/// Helper class for formatting currency values according to locale.
///
/// Domain layer entities should use the top-level [formatCurrency] function
/// which takes locale explicitly. Presentation layer widgets can use
/// [LocalizedCurrency.format] with an [AppSettings] instance.
class LocalizedCurrency {
  /// Formats a currency amount using the specified locale tag.
  ///
  /// The currency symbol is resolved from the COUNTRIES list based on the locale.
  /// If the locale is not recognized, falls back to USD ($).
  static String format(double amount, {String localeTag = 'en_US'}) {
    final symbol = _currencySymbolForLocale(localeTag);
    final formattedAmount = NumberFormat('#,##0.00', localeTag).format(amount);
    return '$symbol $formattedAmount';
  }

  /// Formats a currency amount using the provided [AppSettings].
  ///
  /// Convenience method for presentation layer widgets that have access to AppSettings.
  static String formatWithSettings(double amount, AppSettings settings) {
    return format(amount, localeTag: settings.localeTag);
  }

  /// Formats a currency amount using an explicit [AppCurrency].
  ///
  /// Uses [currency.formatTag] only for the number separators; the
  /// symbol comes from [currency.symbol] directly, so the result is
  /// independent of the current country/language settings.
  static String formatFor(double amount, AppCurrency currency) {
    final formattedAmount =
        NumberFormat('#,##0.00', currency.formatTag).format(amount);
    return '${currency.symbol} $formattedAmount';
  }

  /// Resolves the currency symbol for a given locale tag.
  static String _currencySymbolForLocale(String localeTag) {
    // Try to find matching country by localeTag
    for (final country in COUNTRIES) {
      if (country.localeTag == localeTag) {
        return country.currencySymbol;
      }
    }
    // Fallback: try to match by language code (first 2 chars)
    final langCode = localeTag.split('_').first.toLowerCase();
    for (final country in COUNTRIES) {
      if (country.localeTag.split('_').first.toLowerCase() == langCode) {
        return country.currencySymbol;
      }
    }
    // Default to USD
    return '\$';
  }
}

/// Top-level function for domain layer entities to format currency.
///
/// Domain entities cannot depend on Riverpod or AppSettings, so this function
/// takes the locale explicitly. Presentation layer is responsible for passing
/// the correct locale from AppSettings.
String formatCurrency(double amount,
    {String? localeTag, String? currencySymbol}) {
  final effectiveLocale = localeTag ?? 'en_US';
  final effectiveSymbol = currencySymbol ??
      LocalizedCurrency._currencySymbolForLocale(effectiveLocale);
  final formattedAmount =
      NumberFormat('#,##0.00', effectiveLocale).format(amount);
  return '$effectiveSymbol $formattedAmount';
}

/// Top-level convenience for presentation: formats with an explicit
/// [AppCurrency], decoupled from country/language settings.
String formatCurrencyFor(double amount, AppCurrency currency) =>
    LocalizedCurrency.formatFor(amount, currency);
