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
  static const List<String> supportedPlatforms = [
    'Uber',
    '99',
    'InDrive',
    'Cabify',
    'BlaBlaCar',
    'Outro',
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
  static const String currencySymbol = 'R\$';
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
