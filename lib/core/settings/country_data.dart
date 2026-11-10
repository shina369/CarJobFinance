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
    platforms: ['Uber', '99', 'InDrive', 'BlaBlaCar', 'Outro'],
  ),
  CountryEntry(
    code: 'PT',
    namePt: 'Portugal',
    currencyCode: 'EUR',
    currencySymbol: '€',
    localeTag: 'pt_PT',
    platforms: ['Uber', 'Bolt', 'inDrive', 'BlaBlaCar', 'Outro'],
  ),
  CountryEntry(
    code: 'MX',
    namePt: 'México',
    currencyCode: 'MXN',
    currencySymbol: '\$',
    localeTag: 'es_MX',
    platforms: ['Uber', 'Didi', 'inDrive', 'BlaBlaCar', 'Outro'],
  ),
  CountryEntry(
    code: 'CO',
    namePt: 'Colômbia',
    currencyCode: 'COP',
    currencySymbol: '\$',
    localeTag: 'es_CO',
    platforms: ['Uber', 'Didi', 'inDrive', 'BlaBlaCar', 'Outro'],
  ),
  CountryEntry(
    code: 'CL',
    namePt: 'Chile',
    currencyCode: 'CLP',
    currencySymbol: '\$',
    localeTag: 'es_CL',
    platforms: ['Uber', 'Didi', 'Bolt', 'BlaBlaCar', 'Outro'],
  ),
  CountryEntry(
    code: 'AR',
    namePt: 'Argentina',
    currencyCode: 'ARS',
    currencySymbol: '\$',
    localeTag: 'es_AR',
    platforms: ['Uber', 'Cabify', 'DiDi', 'BlaBlaCar', 'Outro'],
  ),
  CountryEntry(
    code: 'ES',
    namePt: 'Espanha',
    currencyCode: 'EUR',
    currencySymbol: '€',
    localeTag: 'es_ES',
    platforms: ['Uber', 'Bolt', 'Cabify', 'BlaBlaCar', 'Outro'],
  ),
  CountryEntry(
    code: 'US',
    namePt: 'Estados Unidos',
    currencyCode: 'USD',
    currencySymbol: '\$',
    localeTag: 'en_US',
    platforms: ['Uber', 'Lyft', 'Yellow Cab', 'BlaBlaCar', 'Outro'],
  ),
  CountryEntry(
    code: 'ID',
    namePt: 'Indonésia',
    currencyCode: 'IDR',
    currencySymbol: 'Rp',
    localeTag: 'id_ID',
    platforms: ['Uber', 'Gojek', 'Maxim', 'inDrive', 'Outro'],
  ),
  CountryEntry(
    code: 'IN',
    namePt: 'Índia',
    currencyCode: 'INR',
    currencySymbol: '₹',
    localeTag: 'hi_IN',
    platforms: ['Uber', 'Ola', 'inDrive', 'BlaBlaCar', 'Outro'],
  ),
];
