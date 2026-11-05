# CLAUDE.md - Instruções para Assistente IA

## Contexto do Projeto
**CarJobFinance** - Aplicativo Flutter para motoristas de aplicativo gerenciarem finanças.
Localização: `C:\Users\aceri\Desktop\CarJobFinance\carjobfinance`

## Stack & Versões
- Flutter 3.19+ | Dart 3.3+
- Estado: Riverpod | Navegação: GoRouter | DI: GetIt
- DB Local: Drift (SQLite) | Serialização: Freezed + JSON Serializable
- Testes: flutter_test + mocktail

## Regras de Ouro
1. **Sempre leia o arquivo antes de editar** - Use `Read` tool primeiro
2. **Prefira editar a criar** - Modifique arquivos existentes
3. **Sem comentários óbvios** - Código autoexplicativo > comentários
4. **Testes obrigatórios** - Nova funcionalidade = testes unitários + widget
5. **Commits atômicos** - Uma mudança lógica por commit

## Padrões de Código

### Estrutura de Feature
```
feature_name/
├── data/
│   ├── datasources/
│   ├── models/
│   └── repositories/
├── domain/
│   ├── entities/
│   ├── repositories/
│   └── usecases/
└── presentation/
    ├── controllers/
    ├── pages/
    └── widgets/
```

### Riverpod Providers
```dart
// providers.dart - Sempre no final do arquivo da feature
final rideRepositoryProvider = Provider<RideRepository>((ref) => 
  ref.watch(databaseProvider).rideDao);

final ridesControllerProvider = StateNotifierProvider<RidesController, AsyncValue<List<Ride>>>((ref) =>
  RidesController(ref.watch(rideRepositoryProvider)));
```

### Freezed Models
```dart
@freezed
class Ride with _$Ride {
  const factory Ride({
    required String id,
    required DateTime date,
    required Platform platform,
    required double earnings,
    required double distanceKm,
    required int durationMinutes,
    String? origin,
    String? destination,
    required RideType type,
  }) = _Ride;

  factory Ride.fromJson(Map<String, dynamic> json) => _$RideFromJson(json);
}
```

### Drift Database
```dart
@DriftDatabase(tables: [Rides, Expenses], daos: [RideDao, ExpenseDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  
  @override
  int get schemaVersion => 1;
}
```

## Comandos de Desenvolvimento

| Comando | Descrição |
|---------|-----------|
| `flutter run` | Executa em modo debug |
| `flutter test` | Roda todos os testes |
| `flutter analyze` | Análise estática |
| `dart format .` | Formata código |
| `dart run build_runner build --delete-conflicting-outputs` | Gera código (Freezed, Drift) |
| `flutter build apk --release` | Build Android release |

## Tarefas Comuns

### Adicionar Nova Feature
1. Criar estrutura de pastas em `lib/features/nova_feature/`
2. Definir entidades em `domain/entities/`
3. Criar repository interface em `domain/repositories/`
4. Implementar em `data/repositories/`
5. Criar use cases em `domain/usecases/`
6. Controller/Provider em `presentation/controllers/`
7. Telas em `presentation/pages/`
8. Widgets em `presentation/widgets/`
9. Registrar no DI (`core/di/injection.dart`)
10. Adicionar rotas no `core/router/app_router.dart`
11. **Escrever testes**

### Modificar Modelo Existente
1. Atualizar classe Freezed em `data/models/`
2. Rodar `build_runner`
3. Atualizar tabela Drift se necessário
4. Criar migration no Drift (`schemaVersion++`)
5. Atualizar repository/DAO
6. Testar migração

### Adicionar Tela Nova
1. Criar page em `presentation/pages/`
2. Criar controller/provider se necessário
3. Adicionar rota no `AppRouter`
4. Adicionar navegação no widget chamador
5. Testes de widget

## Convenções de Nomenclatura
| Tipo | Padrão | Exemplo |
|------|--------|---------|
| Arquivos | snake_case | `ride_controller.dart` |
| Classes | PascalCase | `RideController` |
| Variáveis/Funções | camelCase | `fetchRides()` |
| Constantes | SCREAMING_SNAKE | `MAX_RIDES_PER_DAY` |
| Providers | snake_case + Provider | `ridesControllerProvider` |
| Enums | PascalCase singular | `Platform`, `RideType` |

## O que NÃO fazer
- ❌ Não use `setState` em widgets complexos - use Riverpod
- ❌ Não coloque lógica de negócio em widgets
- ❌ Não faça queries SQL diretas - use DAOs
- ❌ Não commite código sem `flutter analyze` passar
- ❌ Não commite sem testes para nova funcionalidade
- ❌ Não use `BuildContext` async gaps sem `mounted` check

## Debugging
```bash
# Logs detalhados
flutter run --verbose

# Inspecionar widget tree
flutter inspect

# Performance
flutter run --profile
```

## Dependências Principais (pubspec.yaml)
```yaml
dependencies:
  flutter_riverpod: ^2.4.0
  go_router: ^12.0.0
  get_it: ^7.6.0
  drift: ^2.14.0
  sqlite3_flutter_libs: ^0.5.0
  freezed_annotation: ^2.4.0
  json_annotation: ^4.8.0
  path_provider: ^2.1.0
  intl: ^0.19.0

dev_dependencies:
  build_runner: ^2.4.0
  freezed: ^2.4.0
  json_serializable: ^6.7.0
  drift_dev: ^2.14.0
  mocktail: ^1.0.0
  flutter_test:
    sdk: flutter
```

## Checklist de PR
- [ ] `flutter analyze` sem erros
- [ ] `flutter test` passando
- [ ] `dart format .` aplicado
- [ ] Testes para nova funcionalidade
- [ ] Documentação atualizada (README/CHANGELOG se necessário)
- [ ] Migração de banco testada (se houver schema change)

## Contatos / Referências
- Flutter Docs: https://docs.flutter.dev/
- Riverpod: https://riverpod.dev/
- Drift: https://drift.simonbinder.eu/
- Freezed: https://pub.dev/packages/freezed
- GoRouter: https://pub.dev/packages/go_router