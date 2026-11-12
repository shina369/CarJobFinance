// Full-backup snapshot of the local database and its JSON codec.
import 'dart:convert';

import 'app_database.dart';

const String kBackupFormat = 'carjobfinance-backup';
const int kBackupVersion = 1;

/// Thrown when a backup file is not a valid CarJobFinance backup.
class BackupFormatException implements Exception {
  const BackupFormatException(this.message);
  final String message;

  @override
  String toString() => 'BackupFormatException: $message';
}

/// Everything the app persists: rides, expenses, settings and the
/// per-country platform configuration.
class BackupData {
  const BackupData({
    required this.rides,
    required this.expenses,
    required this.settings,
    required this.countryPlatforms,
  });

  final List<Ride> rides;
  final List<Expense> expenses;
  final Map<String, String> settings;
  final List<CountryPlatform> countryPlatforms;

  String encode({DateTime? exportedAt}) {
    return const JsonEncoder.withIndent('  ').convert({
      'format': kBackupFormat,
      'version': kBackupVersion,
      'exportedAt': (exportedAt ?? DateTime.now()).toIso8601String(),
      'rides': rides.map((r) => r.toJson()).toList(),
      'expenses': expenses.map((e) => e.toJson()).toList(),
      'settings': settings,
      'countryPlatforms': countryPlatforms.map((p) => p.toJson()).toList(),
    });
  }

  /// Parses a backup produced by [encode]. Throws [BackupFormatException]
  /// for anything that is not a readable backup of a supported version.
  static BackupData decode(String source) {
    final Object? root;
    try {
      root = jsonDecode(source);
    } on FormatException catch (e) {
      throw BackupFormatException('invalid JSON: ${e.message}');
    }
    if (root is! Map<String, dynamic> || root['format'] != kBackupFormat) {
      throw const BackupFormatException('not a CarJobFinance backup');
    }
    final version = root['version'];
    if (version is! int || version < 1 || version > kBackupVersion) {
      throw BackupFormatException('unsupported backup version: $version');
    }
    try {
      return BackupData(
        rides: _rows(root['rides']).map(Ride.fromJson).toList(),
        expenses: _rows(root['expenses']).map(Expense.fromJson).toList(),
        settings: (root['settings'] as Map<String, dynamic>? ?? const {})
            .map((k, v) => MapEntry(k, v as String)),
        countryPlatforms: _rows(root['countryPlatforms'])
            .map(CountryPlatform.fromJson)
            .toList(),
      );
    } on BackupFormatException {
      rethrow;
    } catch (e) {
      throw BackupFormatException('corrupted backup content: $e');
    }
  }

  static List<Map<String, dynamic>> _rows(Object? value) {
    if (value == null) return const [];
    return (value as List).cast<Map<String, dynamic>>();
  }
}
