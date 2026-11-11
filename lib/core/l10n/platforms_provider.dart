// Platforms provider for the CarJobFinance app.
// Manages the active platform list per country + user-created (custom)
// platforms. Persisted via the extended CountryPlatforms table.
//
// Active platforms are the ones shown in the ride-form dropdown.
// Built-ins are toggled on/off; customs can also be deleted.
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:carjobfinance/core/settings/app_settings_notifier.dart';
import 'package:carjobfinance/core/settings/country_data.dart';
import 'package:carjobfinance/data/datasources/local/daos.dart' show AppDao;

/// One row of the active-platforms state, decoupled from drift.
@immutable
class AppPlatformInfo {
  const AppPlatformInfo({
    required this.name,
    required this.isActive,
    required this.isCustom,
    this.commissionType,
    this.commissionValue,
  });

  final String name;
  final bool isActive;
  final bool isCustom;

  /// Commission config: 'percent' | 'fixed' (see core/finance/commission).
  /// Null = no commission configured.
  final String? commissionType;
  final double? commissionValue;

  bool get hasCommission =>
      commissionType != null && (commissionValue ?? 0) > 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppPlatformInfo &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          isActive == other.isActive &&
          isCustom == other.isCustom &&
          commissionType == other.commissionType &&
          commissionValue == other.commissionValue;

  @override
  int get hashCode =>
      Object.hash(name, isActive, isCustom, commissionType, commissionValue);

  @override
  String toString() =>
      'AppPlatformInfo($name, active: $isActive, custom: $isCustom, '
      'commission: $commissionType/$commissionValue)';
}

/// Full state of the user's platform list for the current country.
class AppPlatformsPref {
  const AppPlatformsPref({
    required this.countryCode,
    required this.platforms,
  });

  /// The country these platforms belong to.
  final String countryCode;

  /// All platforms for the country, in alphabetical order.
  final List<AppPlatformInfo> platforms;

  /// Only the active ones.
  List<String> get activeNames =>
      platforms.where((p) => p.isActive).map((p) => p.name).toList();

  /// Custom platforms (user-created names), including inactive ones.
  List<String> get customNames =>
      platforms.where((p) => p.isCustom).map((p) => p.name).toList();

  /// Built-in platforms (from country_data) that aren't active yet.
  /// These are the candidates shown in the "Adicionar" dialog's chips.
  List<String> get inactiveBuiltinNames => platforms
      .where((p) => !p.isCustom && !p.isActive)
      .map((p) => p.name)
      .toList();

  /// The platform row for [name], or null when unknown.
  AppPlatformInfo? byName(String name) {
    for (final p in platforms) {
      if (p.name == name) return p;
    }
    return null;
  }
}

/// Provider for the platforms DAO.
final platformsDaoProvider = Provider<AppDao>((ref) {
  return ref.watch(appDaoProviderForSettings);
});

/// StateNotifier that tracks the active platform list for the current
/// country. `initialize()` loads from the DB on first build; the caller
/// (the provider factory) invokes it fire-and-forget.
class PlatformsNotifier extends StateNotifier<AppPlatformsPref> {
  final AppDao _dao;

  bool _disposed = false;

  PlatformsNotifier(this._dao, AppPlatformsPref initialState)
      : super(initialState);

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Load the active + custom state for the current country from the DB.
  /// If the table is empty for this country (fresh switch), fall back to
  /// the built-in list from [COUNTRIES].
  Future<void> initialize() async {
    if (_disposed) return;
    final rows = await _dao.getPlatformStatesFor(state.countryCode);
    if (_disposed) return;
    final builtins = _builtinsFor(state.countryCode);
    final list = rows.isEmpty
        ? builtins
            .map((name) =>
                AppPlatformInfo(name: name, isActive: true, isCustom: false))
            .toList()
        : rows
            .map((r) => AppPlatformInfo(
                  name: r.name,
                  isActive: r.isActive,
                  isCustom: r.isCustom,
                  commissionType: r.commissionType,
                  commissionValue: r.commissionValue,
                ))
            .toList();
    state = AppPlatformsPref(countryCode: state.countryCode, platforms: list);
  }

  /// Toggle a platform on/off. Persists immediately.
  Future<void> togglePlatform(String name, bool active) async {
    if (_disposed) return;
    await _dao.setActive(state.countryCode, name, active);
    if (_disposed) return;
    state = AppPlatformsPref(
      countryCode: state.countryCode,
      platforms: state.platforms
          .map((p) => p.name == name
              ? AppPlatformInfo(
                  name: p.name,
                  isActive: active,
                  isCustom: p.isCustom,
                  commissionType: p.commissionType,
                  commissionValue: p.commissionValue,
                )
              : p)
          .toList(),
    );
  }

  /// Set (or clear, with nulls) the commission of a platform. Persists
  /// immediately.
  Future<void> setCommission(
      String name, String? commissionType, double? commissionValue) async {
    if (_disposed) return;
    await _dao.setCommission(
        state.countryCode, name, commissionType, commissionValue);
    if (_disposed) return;
    state = AppPlatformsPref(
      countryCode: state.countryCode,
      platforms: state.platforms
          .map((p) => p.name == name
              ? AppPlatformInfo(
                  name: p.name,
                  isActive: p.isActive,
                  isCustom: p.isCustom,
                  commissionType: commissionType,
                  commissionValue: commissionValue,
                )
              : p)
          .toList(),
    );
  }

  /// Create a custom platform (upserts + active). The caller validates
  /// duplicates; the DAO is the source of truth.
  Future<void> addCustomPlatform(String name) async {
    if (_disposed) return;
    await _dao.createCustom(state.countryCode, name);
    if (_disposed) return;
    state = AppPlatformsPref(
      countryCode: state.countryCode,
      platforms: [
        ...state.platforms,
        AppPlatformInfo(name: name, isActive: true, isCustom: true),
      ],
    );
  }

  /// Delete a custom platform row. Built-ins are not removable.
  Future<void> removeCustomPlatform(String name) async {
    if (_disposed) return;
    await _dao.deleteCustom(state.countryCode, name);
    if (_disposed) return;
    state = AppPlatformsPref(
      countryCode: state.countryCode,
      platforms:
          state.platforms.where((p) => p.name != name).toList(),
    );
  }

  /// Reset to the country's built-in list (e.g. after a data clear or
  /// when the country changes).
  Future<void> resetToBuiltin() async {
    if (_disposed) return;
    final builtins = _builtinsFor(state.countryCode);
    if (_disposed) return;
    state = AppPlatformsPref(
      countryCode: state.countryCode,
      platforms: builtins
          .map((n) => AppPlatformInfo(name: n, isActive: true, isCustom: false))
          .toList(),
    );
  }

  /// Built-in platform names for a country, from the static [COUNTRIES]
  /// catalog.
  List<String> _builtinsFor(String countryCode) {
    final entry = COUNTRIES.firstWhere(
      (c) => c.code == countryCode,
      orElse: () => COUNTRIES.first,
    );
    return entry.platforms;
  }
}

/// The notifier + state provider.
final platformsProvider =
    StateNotifierProvider<PlatformsNotifier, AppPlatformsPref>(
  (ref) {
    final settings = ref.watch(appSettingsProvider);
    final notifier = PlatformsNotifier(
      ref.watch(platformsDaoProvider),
      AppPlatformsPref(countryCode: settings.countryCode, platforms: []),
    );
    notifier.initialize();
    return notifier;
  },
);

/// Convenience: the active platform names for the current country.
final activePlatformsProvider = Provider<List<String>>((ref) {
  return ref.watch(platformsProvider).activeNames;
});

/// Convenience: the custom platform names for the current country.
final customPlatformsProvider = Provider<List<String>>((ref) {
  return ref.watch(platformsProvider).customNames;
});
