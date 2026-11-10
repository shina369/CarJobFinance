import 'package:flutter/foundation.dart';

/// A single country entry for the onboarding flow.
@immutable
class CountryEntry {
  const CountryEntry({
    required this.code,
    required this.namePt,
    required this.currencyCode,
    required this.currencySymbol,
    required this.localeTag,
    required this.platforms,
  });

  /// ISO 3166-1 alpha-2 country code (e.g. 'BR').
  final String code;

  /// Country name in Portuguese.
  final String namePt;

  /// ISO 4217 currency code (e.g. 'BRL').
  final String currencyCode;

  /// Currency symbol as displayed to the user (e.g. 'R$').
  final String currencySymbol;

  /// BCP 47 locale tag used for number/currency formatting.
  final String localeTag;

  /// List of ride-hailing platforms available in this country.
  final List<String> platforms;
}

/// All supported countries for the onboarding flow.
/// Default is Brazil (BR) when no preference is stored.
// ignore: constant_identifier_names
const List<CountryEntry> COUNTRIES = [
  CountryEntry(
    code: 'BR',
    namePt: 'Brasil',
    currencyCode: 'BRL',
    currencySymbol: 'R\$',
    localeTag: 'pt_BR',
    platforms: [
      'Uber',
      '99',
      'inDrive',
      'Maxim',
      'POP Move',
      'Garupa',
      'Urbano Norte',
      'Mubis',
      'Taxi',
      'Transfer',
    ],
  ),
  CountryEntry(
    code: 'PT',
    namePt: 'Portugal',
    currencyCode: 'EUR',
    currencySymbol: '€',
    localeTag: 'pt_PT',
    platforms: ['Uber', 'Bolt', 'IzzyMove', 'Taxi', 'Transfer'],
  ),
  CountryEntry(
    code: 'MX',
    namePt: 'México',
    currencyCode: 'MXN',
    currencySymbol: '\$',
    localeTag: 'es_MX',
    platforms: [
      'Uber',
      'DiDi',
      'inDrive',
      'Cabify',
      'Maxim',
      'Bolt',
      'Taxi',
      'Transfer',
    ],
  ),
  CountryEntry(
    code: 'CO',
    namePt: 'Colômbia',
    currencyCode: 'COP',
    currencySymbol: '\$',
    localeTag: 'es_CO',
    platforms: [
      'Uber',
      'DiDi',
      'Cabify',
      'inDrive',
      'Maxim',
      'Yango',
      'Taxi',
      'Transfer',
    ],
  ),
  CountryEntry(
    code: 'CL',
    namePt: 'Chile',
    currencyCode: 'CLP',
    currencySymbol: '\$',
    localeTag: 'es_CL',
    platforms: [
      'Uber',
      'DiDi',
      'Cabify',
      'inDrive',
      'Maxim',
      'Yango',
      'Taxi',
      'Transfer',
    ],
  ),
  CountryEntry(
    code: 'AR',
    namePt: 'Argentina',
    currencyCode: 'ARS',
    currencySymbol: '\$',
    localeTag: 'es_AR',
    platforms: [
      'Uber',
      'DiDi',
      'Cabify',
      'inDrive',
      'Maxim',
      'BA Taxi',
      'Taxi',
      'Transfer',
    ],
  ),
  CountryEntry(
    code: 'ES',
    namePt: 'Espanha',
    currencyCode: 'EUR',
    currencySymbol: '€',
    localeTag: 'es_ES',
    platforms: ['Uber', 'Cabify', 'Bolt', 'FREE NOW', 'Taxi', 'Transfer'],
  ),
  CountryEntry(
    code: 'US',
    namePt: 'Estados Unidos',
    currencyCode: 'USD',
    currencySymbol: '\$',
    localeTag: 'en_US',
    platforms: [
      'Uber',
      'Lyft',
      'Empower',
      'Via',
      'Curb',
      'Waymo',
      'Wridz',
      'Taxi',
      'Transfer',
    ],
  ),
  CountryEntry(
    code: 'ID',
    namePt: 'Indonésia',
    currencyCode: 'IDR',
    currencySymbol: 'Rp',
    localeTag: 'id_ID',
    platforms: ['Gojek', 'Grab', 'Maxim', 'inDrive', 'Taxi', 'Transfer'],
  ),
  CountryEntry(
    code: 'IN',
    namePt: 'Índia',
    currencyCode: 'INR',
    currencySymbol: '₹',
    localeTag: 'hi_IN',
    platforms: [
      'Uber',
      'Ola',
      'Rapido',
      'inDrive',
      'Namma Yatri',
      'BluSmart',
      'Taxi',
      'Transfer',
    ],
  ),
];
