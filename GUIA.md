# Guia do Projeto CarJobFinance

## Visão Geral
Aplicação Flutter para gerenciamento financeiro de motoristas de aplicativo (Uber, 99, etc.), permitindo controle de ganhos, despesas, quilometragem e relatórios fiscais.

## Arquitetura
```
lib/
├── main.dart                 # Ponto de entrada
├── core/                     # Configurações centrais
│   ├── constants/            # Constantes da aplicação
│   ├── theme/                # Temas e estilos
│   ├── router/               # Navegação (GoRouter)
│   └── di/                   # Injeção de dependência (GetIt)
├── data/                     # Camada de dados
│   ├── models/               # Modelos de dados
│   ├── repositories/         # Implementações de repositórios
│   └── datasources/          # Fontes de dados (local/remoto)
├── domain/                   # Camada de domínio
│   ├── entities/             # Entidades de negócio
│   ├── repositories/         # Contratos de repositórios
│   └── usecases/             # Casos de uso
└── presentation/             # Camada de apresentação
    ├── pages/                # Telas/Páginas
    ├── widgets/              # Widgets reutilizáveis
    ├── controllers/          # Controllers (Riverpod/Bloc)
    └── utils/                # Utilitários de UI
```

## Stack Tecnológica
- **Framework**: Flutter 3.x
- **Gerenciamento de Estado**: Riverpod
- **Navegação**: GoRouter
- **Banco de Dados Local**: SQLite (sqflite) / Drift
- **Injeção de Dependência**: GetIt
- **Serialização**: Freezed + JSON Serializable
- **Testes**: flutter_test + mocktail

## Funcionalidades Principais
1. **Dashboard** - Resumo financeiro diário/semanal/mensal
2. **Corridas** - Registro de corridas com valor, km, tempo, plataforma
3. **Despesas** - Combustível, manutenção, lavagem, alimentação, etc.
4. **Relatórios** - Exportação CSV/PDF para declaração de IR
5. **Metas** - Definição de metas de ganho/horas
6. **Backup/Sync** - Sincronização com nuvem (opcional)

## Modelos de Dados Principais

### Corrida (Ride)
```dart
class Ride {
  final String id;
  final DateTime date;
  final Platform platform; // Uber, 99, InDrive, etc.
  final double earnings;
  final double distanceKm;
  final int durationMinutes;
  final String? origin;
  final String? destination;
  final RideType type; // Comum, Conforto, Black, etc.
}
```

### Despesa (Expense)
```dart
class Expense {
  final String id;
  final DateTime date;
  final ExpenseCategory category; // Combustível, Manutenção, etc.
  final double amount;
  final String description;
  final String? receiptImagePath;
  final bool isRecurring;
}
```

### Resumo Financeiro (FinancialSummary)
```dart
class FinancialSummary {
  final double totalEarnings;
  final double totalExpenses;
  final double netProfit;
  final double totalKm;
  final int totalRides;
  final double avgPerKm;
  final double avgPerHour;
}
```

## Convenções de Código
- **Naming**: snake_case para arquivos, PascalCase para classes, camelCase para variáveis
- **Imports**: Relativos dentro do pacote, absolutos para pacotes externos
- **Widgets**: Stateless sempre que possível, const constructors
- **Estado**: Riverpod providers no arquivo do controller ou feature
- **Testes**: Um arquivo de teste por arquivo de implementação

## Comandos Úteis
```bash
# Executar app
flutter run

# Build release
flutter build apk --release
flutter build ios --release

# Testes
flutter test
flutter test --coverage

# Análise estática
flutter analyze

# Formatação
dart format .

# Gerar código (Freezed, JSON Serializable)
dart run build_runner build --delete-conflicting-outputs

# Limpar build
flutter clean && flutter pub get
```

## Estrutura de Branches (Git Flow)
- `main` - Produção
- `develop` - Desenvolvimento
- `feature/*` - Novas funcionalidades
- `bugfix/*` - Correções
- `release/*` - Preparação de release
- `hotfix/*` - Correções urgentes em produção

## Configuração de Ambiente
1. Flutter SDK 3.19+
2. Dart SDK 3.3+
3. Android Studio / VS Code com extensões Flutter
4. Emulador Android ou dispositivo físico
5. Xcode (para iOS - apenas macOS)

## Próximos Passos
1. Configurar dependências no `pubspec.yaml`
2. Implementar core (theme, router, DI)
3. Criar modelos de dados com Freezed
4. Configurar banco de dados local (Drift)
5. Implementar primeiras telas (Dashboard, Lista de Corridas)
6. Adicionar testes unitários e de widget