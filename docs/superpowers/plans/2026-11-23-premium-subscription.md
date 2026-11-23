# Assinatura Premium Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adicionar uma assinatura premium **anual** (Google Play via RevenueCat) que trava Relatórios, Meus objetivos, exportação CSV/PDF, backup na nuvem (envio) e lembretes avançados, com o backup protegido também no servidor.

**Architecture:** Uma interface `PurchasesGateway` (fake nos testes, `NoPurchasesGateway` por padrão, `RevenueCatGateway` só em Android/iOS) alimenta o `EntitlementController` (Riverpod), ligado ao `user.id` do Supabase. As travas do app leem `entitlementProvider`; o servidor guarda o status em `public.entitlements` (webhook do RevenueCat) e a RLS de `backups` exige premium para `insert`/`update`.

**Tech Stack:** Flutter/Dart, Riverpod, GoRouter, `purchases_flutter`, Supabase (Postgres RLS, Edge Functions Deno), flutter_test + mocktail.

**Spec:** `docs/superpowers/specs/2026-11-23-premium-subscription-design.md`

## Global Constraints

- Plano **único anual**, **7 dias de teste grátis**; preço/teste ficam no Play Console/RevenueCat, nunca no código.
- `app_user_id` do RevenueCat = `user.id` do Supabase; entitlement chama-se `premium`.
- Paywall só aparece quando o usuário **toca** em algo premium; nunca na abertura.
- Restaurar backup (cloud e arquivo JSON) e `LoginGate.restoreOffer` **sempre livres**; backup JSON em arquivo, corridas/despesas, Dashboard e meta mensal simples **sempre livres**.
- Envio de backup para não premium é **silencioso** (sem erro na UI).
- Todo texto novo em `strings.dart` com prefixo `premium.` nos 5 bundles base (`pt_BR`, `es_MX`, `en_US`, `id_ID`, `hi_IN`); `pt_PT`/`es_*` herdam via `_merge`. Placeholders `{nome}` via `AppLanguage.tr(key, args:)`.
- `purchases_flutter` não existe em Windows/Linux: configurar só em Android/iOS; testes nunca tocam o SDK real.
- Testes existentes não podem quebrar: `AuthHarness` passa a sobrescrever o gateway como premium.
- Sem comentários óbvios, sem `.md` extra; `flutter analyze` e `flutter test` verdes antes de cada commit; commits convencionais, um por tarefa.
- Trabalhar numa branch nova `feat/premium-subscription` (a atual é `feat/monthly-goals`); nunca push direto para main.

## Review Focus

1. **Corrida na abertura:** `autoBackupIfDue` rodando antes do RevenueCat responder não pode enviar backup sem premium nem travar o app → `resolveIsPremium()` espera com timeout e, sem resposta, trata como não premium (Task 3, 6).
2. **Offline:** sem rede e com cache do SDK, premium continua premium; sem cache, não premium, sem exceção (Task 3).
3. **Assinatura expirada/cancelada:** cancelado continua premium até `expiresAt`; depois dele, lembretes extras ficam salvos mas desagendados e sobra só o de menor `id` (Task 10).
4. **Troca de conta no mesmo aparelho:** o status da conta A não vaza para a conta B; `logOut` zera o estado (Task 3).
5. **Compra cancelada pelo usuário** não mostra erro e a tela permanece aberta; falha de rede mostra mensagem traduzida (Task 7).

---

### Task 1: Branch, configuração e dependência

**Files:**
- Modify: `pubspec.yaml`, `lib/core/config/env.dart`, `.env.example`
- Test: `test/core/config/env_test.dart` (create)

**Interfaces:**
- Produces: `Env({required supabaseUrl, required supabaseKey, String? revenueCatAndroidKey, bool? premiumOverride})`; `Env.load()` lê `REVENUECAT_ANDROID_KEY` (opcional) e `PREMIUM_OVERRIDE` (`true`/`false`, opcional, só honrado quando `kDebugMode`).

- [ ] **Step 1:** `git checkout -b feat/premium-subscription` e `git add docs/superpowers/specs docs/superpowers/plans && git commit -m "docs: add premium subscription design and plan"`.
- [ ] **Step 2: Write failing test** `env_test.dart`: `Env.fromMap({'SUPABASE_URL':'u','SUPABASE_KEY':'k','PREMIUM_OVERRIDE':'true','REVENUECAT_ANDROID_KEY':'rc'})` gives `premiumOverride == true`, `revenueCatAndroidKey == 'rc'`; sem as chaves opcionais ambos são `null`; sem `SUPABASE_URL` lança a mesma exceção que `Env.load()` lança hoje (ler `env.dart` e manter o tipo).
- [ ] **Step 3:** Run `flutter test test/core/config/env_test.dart` → FAIL (`fromMap` inexistente).
- [ ] **Step 4:** Em `env.dart`, extrair o parsing de `Env.load()` para `factory Env.fromMap(Map<String,String> values)` (load passa `dotenv.env`) e adicionar os dois campos opcionais. Em `pubspec.yaml` adicionar `purchases_flutter` (última versão estável, `flutter pub add purchases_flutter`). Em `.env.example` adicionar `REVENUECAT_ANDROID_KEY=` e `PREMIUM_OVERRIDE=` com uma linha de comentário cada.
- [ ] **Step 5:** `flutter test test/core/config/env_test.dart` → PASS; `flutter analyze` limpo.
- [ ] **Step 6: Commit** `feat(config): add RevenueCat key and premium override to Env`.

---

### Task 2: Textos `premium.*` nos 5 idiomas

**Files:**
- Modify: `lib/core/l10n/strings.dart`
- Test: `test/core/l10n/premium_strings_test.dart` (create)

**Interfaces:**
- Produces (chaves, mesmas nos 5 bundles): `premium.title`, `premium.tagline`, `premium.benefit.reports`, `premium.benefit.goals`, `premium.benefit.export`, `premium.benefit.backup`, `premium.benefit.reminders`, `premium.cta` ("Assinar"), `premium.price.year` (`{price}`), `premium.price.perMonth` (`{price}`), `premium.trial` (`{days}`), `premium.restore`, `premium.terms`, `premium.privacy`, `premium.manage`, `premium.active` , `premium.renews` (`{date}`), `premium.expires` (`{date}`), `premium.locked` (rótulo do cadeado), `premium.reports.sampleBanner`, `premium.backup.locked`, `premium.reminders.limit`, `premium.error.purchase`, `premium.error.unavailable`, `premium.deleteAccount.warning`, `premium.settings.tile`.

- [ ] **Step 1: Write failing test:** para cada tag em `['pt_BR','es_MX','en_US','id_ID','hi_IN']` e cada chave acima, `Strings.t(key, tag)` não é vazio e **não** é igual à própria chave; `premium.price.year` contém `{price}`; `premium.trial` contém `{days}`; tags derivadas (`pt_PT`, `es_AR`) resolvem a mesma chave.
- [ ] **Step 2:** `flutter test test/core/l10n/premium_strings_test.dart` → FAIL.
- [ ] **Step 3:** Adicionar as chaves em cada um dos 5 bundles seguindo a estrutura existente (ver `'cloud.last'` em `strings.dart:106`); redigir texto natural por idioma, sem traduzir marcas.
- [ ] **Step 4:** Test → PASS. **Step 5: Commit** `feat(l10n): add premium strings`.

---

### Task 3: Domínio de entitlement

**Files:**
- Create: `lib/core/purchases/purchases_gateway.dart`, `lib/presentation/controllers/entitlement_controller.dart`, `test/support/fake_purchases_gateway.dart`
- Modify: `test/support/auth_test_support.dart` (`AuthHarness.overrides`)
- Test: `test/presentation/controllers/entitlement_controller_test.dart` (create)

**Interfaces:**
- Produces em `purchases_gateway.dart`:
  - `class PremiumInfo { const PremiumInfo({required bool isPremium, DateTime? expiresAt, bool willRenew = false}); static const none = PremiumInfo(isPremium: false); }`
  - `class PremiumOffer { const PremiumOffer({required String packageId, required String priceText, required String monthlyText, int? trialDays}); }`
  - `class PurchaseCancelled implements Exception`
  - `abstract class PurchasesGateway { Stream<PremiumInfo> get updates; Future<void> logIn(String userId); Future<void> logOut(); Future<PremiumInfo> currentInfo(); Future<PremiumOffer?> annualOffer(); Future<PremiumInfo> purchase(PremiumOffer offer); Future<PremiumInfo> restore(); }`
  - `class NoPurchasesGateway implements PurchasesGateway` (sempre `PremiumInfo.none`, `annualOffer` → `null`, `updates` vazio).
  - `final purchasesGatewayProvider = Provider<PurchasesGateway>((_) => const NoPurchasesGateway());`
- Produces em `entitlement_controller.dart`:
  - `class EntitlementState { const EntitlementState({this.info = PremiumInfo.none, this.resolved = false}); bool get isPremium => info.isPremium && (info.expiresAt == null || info.expiresAt!.isAfter(DateTime.now())); }`
  - `class EntitlementController extends StateNotifier<EntitlementState>` — `EntitlementController(PurchasesGateway gateway, String? userId, {Duration resolveTimeout = const Duration(seconds: 5), bool? forced})`; `Future<bool> resolveIsPremium()`; `Future<void> purchase(PremiumOffer)`; `Future<void> restore()`.
  - `final entitlementProvider = StateNotifierProvider<EntitlementController, EntitlementState>` — lê `ref.watch(sessionProvider.select((s) => s.user?.id))`, `purchasesGatewayProvider` e `envProvider`'s `premiumOverride` (só em `kDebugMode`; se `envProvider` não estiver sobrescrito, trata override como `null`).
  - `final isPremiumProvider = Provider<bool>((ref) => ref.watch(entitlementProvider).isPremium);`
- Produces em test support: `class FakePurchasesGateway implements PurchasesGateway` com `PremiumInfo info`, `Object? error`, `Duration? delay`, `StreamController<PremiumInfo> push`, `List<String> loggedIn`, `int logOutCalls`, `PremiumOffer? offer`; helper `premiumGatewayOverride({bool premium = true})` → `Override` de `purchasesGatewayProvider`.
- `AuthHarness.overrides` inclui `premiumGatewayOverride()`; campo novo `bool premium = true` no harness (false para testes de não premium).

- [ ] **Step 1: Write failing tests** (`ProviderContainer` + `FakePurchasesGateway`):
  - `usuário null → não premium, sem chamar logIn`
  - `logIn com user.id e currentInfo premium → isPremium true e resolved true`
  - `expiresAt no passado → isPremium false`
  - `cancelado (willRenew false) com expiresAt futuro → isPremium true`
  - `updates emite premium → estado atualiza`
  - `resolveIsPremium aguarda logIn lento e devolve true` e `gateway que demora mais que resolveTimeout → false, sem exceção`
  - `gateway lança em currentInfo (offline sem cache) → não premium, resolved true`
  - `trocar user A→B: estado volta a none antes de B resolver; logOut chamado uma vez`
  - `purchase` premium atualiza estado; `PurchaseCancelled` propaga sem alterar estado; `restore` atualiza.
  - `forced: true/false` ignora o gateway.
- [ ] **Step 2:** Run `flutter test test/presentation/controllers/entitlement_controller_test.dart` → FAIL.
- [ ] **Step 3:** Implementar os arquivos acima. Abordagem: o construtor dispara `_init()` guardando o `Future` em `_ready`; `resolveIsPremium` = `await _ready.timeout(resolveTimeout, onTimeout: ...)` e devolve `state.isPremium`. Cancelar a subscription em `dispose`. Atualizar `AuthHarness` e `FakePurchasesGateway`.
- [ ] **Step 4:** Test → PASS; `flutter test` inteiro continua verde (harness premium por padrão).
- [ ] **Step 5: Commit** `feat(premium): add entitlement domain and controller`.

---

### Task 4: Adaptador RevenueCat e inicialização

**Files:**
- Create: `lib/core/purchases/revenuecat_gateway.dart`
- Modify: `lib/main.dart`
- Test: `test/core/purchases/revenuecat_mapping_test.dart` (create)

**Interfaces:**
- Consumes: `PurchasesGateway`, `PremiumInfo`, `PremiumOffer`, `PurchaseCancelled` (Task 3), `Env.revenueCatAndroidKey`.
- Produces: `class RevenueCatGateway implements PurchasesGateway` (`static Future<RevenueCatGateway?> configure(Env env)` → `null` se não Android/iOS ou sem chave); funções puras `PremiumInfo premiumInfoFrom(CustomerInfo info)` e `PremiumOffer? annualOfferFrom(Offerings offerings)` (testáveis).

- [ ] **Step 1: Write failing test** com `CustomerInfo`/`Offerings` construídos à mão (ou mocktail): entitlement `premium` ativo → `isPremium true`, `expiresAt` e `willRenew` mapeados; sem entitlement → `none`; offering atual com pacote `PackageType.annual` → `PremiumOffer` com `priceText` do `storeProduct.priceString`, `monthlyText` = preço/12 formatado na moeda do produto, `trialDays` do `introductoryPrice` gratuito (ou `null`); sem pacote anual → `null`.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Implementar mapeamento e gateway (`Purchases.configure`, `logIn`/`logOut`, `addCustomerInfoUpdateListener` → stream, `purchasePackage` capturando `PurchasesErrorCode.purchaseCancelledError` → `PurchaseCancelled`). Em `main.dart`, depois de `Env.load()`: `final gateway = await RevenueCatGateway.configure(env);` e adicionar `if (gateway != null) purchasesGatewayProvider.overrideWithValue(gateway)` aos overrides; depois de `sessionProvider.initialize()` fazer `container.read(entitlementProvider);` (como já é feito com `notificationSettingsProvider`).
- [ ] **Step 4:** Test → PASS; `flutter analyze`; `flutter build apk --debug` compila.
- [ ] **Step 5: Commit** `feat(premium): add RevenueCat gateway`.

---

### Task 5: Servidor — tabela, RLS e webhook

**Files:**
- Create: `supabase/migrations/20261123000000_entitlements.sql`, `supabase/functions/revenuecat-webhook/index.ts`, `supabase/functions/revenuecat-webhook/handler.ts`, `supabase/functions/revenuecat-webhook/handler_test.ts`, `supabase/tests/entitlements_rls.sql`

**Interfaces:**
- Produces: tabela `public.entitlements(user_id uuid primary key references auth.users on delete cascade, is_premium boolean not null default false, expires_at timestamptz, updated_at timestamptz not null default now())`, RLS com `select` só do dono (`auth.uid() = user_id`) e nenhuma política de escrita; função SQL `public.is_premium(uid uuid) returns boolean` (`security definer`, `stable`, `search_path = public`): existe linha com `is_premium` e `expires_at > now()`; políticas de `insert`/`update` de `public.backups` recriadas com `... and public.is_premium(auth.uid())`; `select` inalterada.
- Produces no TS: `export function applyEvent(event: RcEvent): { userId: string; isPremium: boolean; expiresAt: string | null } | null` (puro, em `handler.ts`) e `index.ts` com `Deno.serve` que valida `Authorization` contra `Deno.env.get("REVENUECAT_WEBHOOK_SECRET")` (401 se diferente), chama `applyEvent`, faz upsert com a service role e responde 200.

- [ ] **Step 1: Write failing tests** em `handler_test.ts` (`deno test`): `INITIAL_PURCHASE`/`RENEWAL`/`PRODUCT_CHANGE`/`UNCANCELLATION` → premium com `expiration_at_ms`; `CANCELLATION` → continua premium até a expiração (mantém `expiresAt`); `EXPIRATION` → `isPremium false`; `BILLING_ISSUE` → mantém até a expiração; `TRANSFER` → premium para `transferred_to` e não premium para `transferred_from`, `app_user_id` não UUID (`$RCAnonymousID:`) → `null`; evento desconhecido → `null`; evento fora de ordem (mais antigo que o já gravado) não sobrescreve: `updated_at` guarda o `event_timestamp_ms` do evento e o upsert é condicional (`where excluded.updated_at >= entitlements.updated_at`), feito pela RPC `public.apply_entitlement(uid uuid, premium boolean, expires timestamptz, ts timestamptz)` (`security definer`, `execute` só para a service role, na mesma migration).
- [ ] **Step 2:** `deno test supabase/functions/revenuecat-webhook` → FAIL.
- [ ] **Step 3:** Implementar `handler.ts`, `index.ts` (estilo CORS/service role de `supabase/functions/delete-account/index.ts`) e a migration. Consultar a documentação de webhooks do RevenueCat para os nomes exatos dos campos antes de fechar `RcEvent`.
- [ ] **Step 4:** `supabase/tests/entitlements_rls.sql` (script pgTAP ou SQL com `do $$ ... assert`): usuário não premium recebe erro de RLS ao `insert`/`update` em `backups`; premium com `expires_at` futuro consegue; premium expirado não; ambos conseguem `select`; usuário não consegue escrever em `entitlements`. Rodar com `supabase db reset && supabase test db` (se Docker indisponível, anotar no PR que ficou para o passo manual da Task 12).
- [ ] **Step 5:** Testes passam. **Step 6: Commit** `feat(server): entitlements table, backup RLS and RevenueCat webhook`.

---

### Task 6: Trava do backup na nuvem

**Files:**
- Modify: `lib/presentation/controllers/cloud_backup_controller.dart`, `lib/presentation/controllers/session_controller.dart` (signOut), `lib/presentation/pages/settings/backup_page.dart`
- Test: `test/presentation/controllers/cloud_backup_controller_test.dart`, `test/presentation/controllers/session_controller_test.dart`, `test/presentation/pages/settings/backup_page_test.dart` (adicionar casos; criar o último se não existir)

**Interfaces:**
- Consumes: `entitlementProvider` (`resolveIsPremium()`), `PremiumRequiredException` (novo, em `cloud_backup_controller.dart`: `class PremiumRequiredException implements Exception`).
- Produces: `backupNow()` lança `PremiumRequiredException` se não premium; `autoBackupIfDue({DateTime? now})` retorna sem enviar nem lançar se não premium; `signOut()` não tenta `backupNow` se não premium e continua a sair normalmente; `restoreFromCloud()`, `remoteBackupAt()`, `hasLocalData()` sem mudança.

- [ ] **Step 1: Write failing tests** (harness com `premium = false`): `backupNow lança PremiumRequiredException e não chama FakeCloud.upload`; `autoBackupIfDue não envia e não lança`; `restoreFromCloud funciona sem premium`; `signOut não envia mas sai`; com `premium = true` o comportamento atual se mantém; `resolveIsPremium` lento (gateway com `delay` > timeout) → não envia. Widget: `BackupPage` não premium mostra `cloud-upgrade` (botão que abre `/paywall`) no lugar de `cloud-backup-now`, e `cloud-restore` continua visível; `cloud-backup-now` tocado capturando `PremiumRequiredException` abre o paywall em vez de mostrar erro.
- [ ] **Step 2:** Run `flutter test test/presentation/controllers test/presentation/pages/settings/backup_page_test.dart` → FAIL.
- [ ] **Step 3:** Implementar. `CloudBackupController` chama `_ref.read(entitlementProvider.notifier).resolveIsPremium()` antes de enviar. Em `BackupPage`, `_cloudBackup` trata `PremiumRequiredException` navegando via `ensurePremium` (Task 7 — até lá usar `context.push('/paywall')`).
- [ ] **Step 4:** Tests → PASS. **Step 5: Commit** `feat(premium): gate cloud backup upload`.

---

### Task 7: Paywall, rota, `ensurePremium` e `/goals`

**Files:**
- Create: `lib/presentation/pages/premium/paywall_page.dart`, `lib/presentation/widgets/premium_gate.dart`
- Modify: `lib/core/router/app_router.dart`
- Test: `test/presentation/pages/premium/paywall_page_test.dart`, `test/core/router/app_redirect_test.dart`, `test/presentation/widgets/premium_gate_test.dart`

**Interfaces:**
- Produces: `class PaywallPage extends ConsumerWidget` (rota `/paywall`, fora do shell como `/goals`); `Future<bool> ensurePremium(BuildContext context, WidgetRef ref)` em `premium_gate.dart` — `true` se já premium; senão `context.push<bool>('/paywall')` e devolve o resultado (`true` quando a compra/restauração termina premium); `appRedirect({required SessionState session, required bool configured, required String location, bool isPremium = true})` → para autenticado, sem gate, `location == '/goals'` e `!isPremium` devolve `'/paywall'`; `routerProvider` passa `ref.read(isPremiumProvider)` e se reconstrói (`refreshListenable`/watch já usado para a sessão) quando premium muda.
- Chaves de widget do paywall: `paywall-cta`, `paywall-restore`, `paywall-price`, `paywall-trial`, `paywall-terms`, `paywall-privacy`, `paywall-error`.

- [ ] **Step 1: Write failing tests:** router: `/goals` não premium → `/paywall`; premium → `null`; `/reports` e `/` não premium → `null` (relatórios borrados vivem na página); `/paywall` fora da lista de rotas de login. Paywall (gateway fake com `offer`): mostra benefícios, `paywall-price` com `priceText`, `paywall-trial` só quando `trialDays != null`; tocar `paywall-cta` chama `purchase` e fecha com `true`; `PurchaseCancelled` não mostra erro e a tela fica; outro erro mostra `paywall-error` traduzido (`premium.error.purchase`); `annualOffer == null` mostra `premium.error.unavailable` e CTA desabilitado; `paywall-restore` chama `restore`. `ensurePremium` não abre paywall quando já premium.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Implementar; links de Termos/Privacidade abrem as páginas existentes de `legal_page.dart` (ler o arquivo para os caminhos/rotas atuais); visual segue o tema do app (aplicar `frontend-design` ao compor a tela).
- [ ] **Step 4:** Tests → PASS. **Step 5: Commit** `feat(premium): paywall page, route and gate helper`.

---

### Task 8: Relatórios borrados para não premium

**Files:**
- Modify: `lib/presentation/pages/reports/reports_page.dart`
- Create: `lib/presentation/pages/reports/reports_sample.dart`
- Test: `test/presentation/pages/reports/reports_page_test.dart` (adicionar/criar)

**Interfaces:**
- Consumes: `isPremiumProvider`, `ensurePremium`.
- Produces: não premium vê `Key('reports-locked')` com o conteúdo de exemplo (dados fictícios fixos, nunca os dados reais do usuário) sob `ImageFiltered`/`BackdropFilter` + `IgnorePointer`, banner `premium.reports.sampleBanner` e botão `reports-upgrade` → `ensurePremium`; premium vê a página atual inalterada.

- [ ] **Step 1: Write failing tests:** não premium → `reports-locked` presente, seletor de período (`ReportPeriod`) real ausente, texto de valores reais do usuário **ausente**, `reports-upgrade` abre `/paywall`; premium → comportamento atual (testes existentes seguem verdes).
- [ ] **Step 2:** Run → FAIL. **Step 3:** Implementar (`ReportsPage` escolhe entre `_ReportsContent()` e `ReportsLockedPreview`). **Step 4:** PASS.
- [ ] **Step 5: Commit** `feat(premium): blurred reports sample for free users`.

---

### Task 9: Exportação CSV/PDF

**Files:**
- Modify: `lib/presentation/widgets/export_actions.dart`
- Test: `test/presentation/widgets/export_actions_test.dart` (criar) ou o teste de `settings_page_test.dart` existente

**Interfaces:**
- Consumes: `isPremiumProvider`, `ensurePremium`.
- Produces: `ExportTiles` mostra ícone de cadeado (`Icons.lock_outline`, chave `export-csv-lock`/`export-pdf-lock`) e `premium.locked` nos tiles CSV e PDF quando não premium; tocar chama `ensurePremium` e só exporta se `true`; o tile de backup JSON nunca tem cadeado.

- [ ] **Step 1: Write failing tests:** não premium: tocar CSV/PDF navega ao paywall e não chama `dataControllerProvider.exportBackup`/exportadores; JSON abre sem paywall; premium: sem cadeados, exporta como antes.
- [ ] **Step 2:** FAIL. **Step 3:** Implementar. **Step 4:** PASS.
- [ ] **Step 5: Commit** `feat(premium): lock CSV and PDF export`.

---

### Task 10: Lembretes — limite e personalização

**Files:**
- Modify: `lib/core/notifications/notification_settings.dart`, `lib/presentation/pages/settings/reminders_page.dart`
- Test: `test/core/notifications/notification_settings_test.dart`, `test/presentation/pages/settings/reminders_page_test.dart`

**Interfaces:**
- Consumes: `isPremiumProvider`; `Reminder{id,hour,minute,days,message,soundUri,soundName,enabled}`; `ReminderText`.
- Produces: `NotificationSettingsNotifier` ganha parâmetro `bool Function() isPremium` (provider injeta `() => ref.read(isPremiumProvider)`); `resync()` e `_apply` agendam, para não premium, **apenas** o lembrete ativo de menor `id`, com texto e som padrão (ignora `message`/`soundUri`), sem apagar os dados salvos; provider reexecuta `resync()` quando `isPremiumProvider` muda (`ref.listen`). Novo `static const freeReminderLimit = 1`.
- UI: não premium com 1 lembrete → FAB `reminder-add` abre paywall em vez do editor; no editor, escolher `reminder-message-custom` ou tocar `reminder-sound` abre paywall (mostra cadeado) e mantém o valor padrão.

- [ ] **Step 1: Write failing tests** (`_InMemoryAppDao`, `_FakeNotificationService`): não premium com reminders ids 1,2,3 → só o id 1 é agendado e com texto/som padrão mesmo que tenha `message`; os registros 2 e 3 e as personalizações continuam no DAO; premium → todos agendados com personalização; mudar de não premium para premium reagenda todos; premium → não premium cancela 2 e 3; `setEnabled(false)` continua funcionando sem premium. Widget: FAB com 1 lembrete e não premium abre `/paywall`; sem lembretes o FAB abre o editor; opção custom/som não premium abre paywall.
- [ ] **Step 2:** FAIL. **Step 3:** Implementar. **Step 4:** PASS.
- [ ] **Step 5: Commit** `feat(premium): limit free reminders and lock customization`.

---

### Task 11: Item Premium nas Configurações e aviso na exclusão

**Files:**
- Create: `lib/presentation/pages/settings/premium_tile.dart`
- Modify: `lib/presentation/pages/settings/settings_page.dart`, `lib/presentation/pages/settings/delete_account_dialog.dart`
- Test: `test/presentation/pages/settings/settings_page_test.dart`, `test/presentation/pages/settings/delete_account_dialog_test.dart`

**Interfaces:**
- Consumes: `entitlementProvider` (`info.expiresAt`, `info.willRenew`), `ensurePremium`.
- Produces: `PremiumTile` (chave `premium-tile`) no topo de Configurações: não premium → `premium.settings.tile` + abre `/paywall`; premium → `premium.active` + `premium.renews`/`premium.expires` (conforme `willRenew`) e ação `premium-manage` que abre `https://play.google.com/store/account/subscriptions` via `url_launcher` (adicionar ao `pubspec` com `flutter pub add url_launcher` se ainda não estiver; os testes sobrescrevem o lançador com um fake injetado por provider). `DeleteAccountDialog` exibe `premium.deleteAccount.warning` quando premium.

- [ ] **Step 1: Write failing tests** nos dois estados. **Step 2:** FAIL. **Step 3:** Implementar. **Step 4:** PASS.
- [ ] **Step 5: Commit** `feat(premium): settings premium tile and delete-account warning`.

---

### Task 12: Verificação final e configuração externa

**Files:** nenhum código (ajustes só se algo falhar).

- [ ] **Step 1:** `dart format .`, `flutter analyze`, `flutter test` inteiros verdes.
- [ ] **Step 2:** Rodar o app (skill `run`) com `.env` `PREMIUM_OVERRIDE=false` e `true` e conferir: Relatórios borrado ↔ liberado, `/goals` ↔ paywall, cadeados de CSV/PDF, backup page, segundo lembrete.
- [ ] **Step 3 (usuário, fora do código — entregar como checklist):**
  - Play Console: assinatura com plano base **anual**, oferta de **7 dias grátis**, app em faixa de teste interna, testadores licenciados.
  - RevenueCat: projeto Android, entitlement `premium`, offering `default` com o pacote anual, chave pública do SDK em `.env` (`REVENUECAT_ANDROID_KEY`).
  - Supabase: `supabase db push`, `supabase secrets set REVENUECAT_WEBHOOK_SECRET=...`, `supabase functions deploy revenuecat-webhook`; webhook do RevenueCat apontando para a função com o mesmo segredo no cabeçalho `Authorization`.
  - Confirmar a comissão atual do Google Play para assinaturas e a faixa gratuita/percentual do RevenueCat.
  - Teste de ponta a ponta com build assinado: compra, cancelamento, expiração, restauração em segundo aparelho, backup recusado para conta sem premium.
- [ ] **Step 4: Commit** de eventuais ajustes `chore(premium): final verification fixes`.
