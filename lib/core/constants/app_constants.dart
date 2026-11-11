// Constantes globais da aplicação CarJobFinance

class AppConstants {
  // App Info
  static const String appName = 'CarJobFinance';
  static const String appVersion = '1.0.0';
  static const String bundleId = 'com.carjobfinance.app';

  // Database
  static const String databaseName = 'carjobfinance.db';
  static const int databaseVersion = 1;

  // Platforms
  // @deprecated Platform lists are now country-aware — see COUNTRIES in
  // core/settings/country_data.dart and AppSettings.platforms. This constant
  // is kept only for backward compatibility and should not be used in new code.
  @Deprecated('Use AppSettings.platforms from app_settings_notifier.dart')
  static const List<String> supportedPlatforms = [
    'Uber',
    '99',
    'inDrive',
    'Cabify',
  ];

  // Ride Types
  static const List<String> rideTypes = [
    'Comum',
    'Conforto',
    'Black',
    'VIP',
    'Compartilhada',
    'Entrega',
  ];

  // Expense Categories
  static const List<String> expenseCategories = [
    'Combustível',
    'Manutenção',
    'Lavagem',
    'Estacionamento',
    'Pedágio',
    'Alimentação',
    'Seguro',
    'IPVA/Licenciamento',
    'Acessórios',
    'Outros',
  ];

  // Currency
  // @deprecated Use AppSettings.currencySymbol/currencyCode from locale_helper.dart instead
  // These constants are kept for backward compatibility but should not be used in new code.
  // Currency is now dynamic based on user's selected country (see AppSettings and LocalizedCurrency).
  @Deprecated('Use AppSettings.currencySymbol from app_settings_notifier.dart')
  static const String currencySymbol = 'R\$';
  @Deprecated('Use AppSettings.currencyCode from app_settings_notifier.dart')
  static const String currencyCode = 'BRL';
  static const int currencyDecimalDigits = 2;

  // Date Formats
  static const String dateFormatBr = 'dd/MM/yyyy';
  static const String dateTimeFormatBr = 'dd/MM/yyyy HH:mm';
  static const String monthYearFormatBr = 'MM/yyyy';

  // Limits
  static const int maxRidesPerDay = 100;
  static const int maxExpensePhotos = 5;
  static const double maxKmPerRide = 500.0;

  // Export
  static const String csvDelimiter = ';';
  static const String csvEncoding = 'utf-8';

  // Notifications
  static const String notificationChannelId = 'carjobfinance_channel';
  static const String notificationChannelName = 'CarJobFinance';
}
