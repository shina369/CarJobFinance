# Design: Currency & Platforms in Settings > Aparência

**Date:** 2026-11-11
**Author:** Claude Code
**Scope:** Two new rows in the Settings → Aparência card — Currency and Platforms — plus a new `CurrencyProvider` and `PlatformsProvider` so the whole app follows user-selected currency/platforms independently of country/language.

---

## 1. Intent

The user explicitly wants **currency display** to be decoupled from country/language, same as language was in a prior iteration. They also want a platform manager: activate/deactivate existing + create new custom platform names that appear in the ride form dropdown.

**Non-goals (explicitly excluded):**
- No currency **conversion** of already-registered values. Only the symbol/format changes on screen.
- No editing the per-country platform list in `country_data.dart` (item 2 option b).
- No i18n beyond what already exists.
- No persistence of disabled/activated state across country switches — the user's own spec says it persists **per country** (their words: "a seleção de ativas/desativadas + plataformas criadas persiste por país, mesmo depois de trocar de país/idioma/moeda"). So if you switch BR→PT, the BR active list stays stored; when you switch back to BR, it's restored. The state is keyed by country code.

---

## 2. Currency

### 2.1 New data: currency catalog

`lib/core/l10n/currencies.dart`

```dart
class AppCurrency {
  final String code;        // 'BRL', 'USD', ...
  final String symbol;      // 'R$', '$', ...
  final String displayName; // 'Real brasileiro', 'Dólar americano', ...
  final String formatTag;   // BCP 47 tag used ONLY for NumberFormat
                            // separators, e.g. 'pt_BR' (not an app locale)
  const AppCurrency(...);
}

const List<AppCurrency> SUPPORTED_CURRENCIES = [
  // One entry per country in country_data.dart:
  // BRL R$  pt_BR | EUR €  pt_PT | MXN $ es_MX | COP $ es_CO |
  // CLP $ es_CL | ARS $ es_AR | USD $ en_US | EUR € es_ES |
  // IDR Rp  id_ID | INR ₹ hi_IN
];

AppCurrency? currencyForCode(String code);
AppCurrency defaultCurrencyForCountry(String countryCode);
```

Note: EUR appears twice (PT and ES) — the catalog is keyed by country,
exactly like `COUNTRIES`, so `defaultCurrencyForCountry` resolves
unambiguously. `formatTag` values are all already in
`SUPPORTED_LANGUAGES`, so **no new `initializeDateFormatting` locales are
needed**.

### 2.2 New state: CurrencyProvider (mirrors LanguageProvider)

`lib/core/l10n/currency_provider.dart`

- `AppCurrencyPref` with `currency` + `countryCode` (countryKey only for the default fallback path; the pref itself is **independent** of country).
- `CurrencyNotifier extends StateNotifier<AppCurrencyPref>`:
  - `initialize()` — loads `app_currency` key from settings table; falls back to the country's default currency.
  - `setCurrency(AppCurrency)` — persists `app_currency` key.
  - `resetToCountryDefault()` — clears it.
- Guarded against double-dispose (same `isDisposed` pattern as `LanguageNotifier`).
- Providers:
  - `currencyDaoProvider` → reuses `appDaoProviderForSettings`.
  - `currencyProvider` (StateNotifierProvider, auto-disposes with Riverpod; **no** `ref.onDispose` — Riverpod handles it, we learned that the hard way last session).
  - `appCurrencyProvider` → convenience: returns the current `AppCurrency` object.

### 2.3 Number-formatting locale for the currency

`AppCurrency.formatTag` drives only `NumberFormat` separators. EUR uses
`pt_PT` when selected from PT and `es_ES` when selected from ES (country-
keyed, no shared tag), GBP is not in the catalog (there is no GB country
in `COUNTRIES`).

### 2.4 Where display changes

- **Presentation** — every `settings.currencySymbol` / `settings.currencyCode`
  read becomes `ref.watch(appCurrencyProvider)` (symbol + currencyTag):
  dashboard (goal dialog + metric prefix, line 104), ride/expense forms
  (`prefixText`, hints, "total" labels), report totals, rides/expenses
  list row totals, onboarding "your currency will be" preview.
- **Formatting helpers** — `LocalizedCurrency.format(amount,
  localeTag:)` takes a *locale tag* and re-derives the symbol from
  COUNTRIES, which would reintroduce the coupling this feature removes.
  So we add `formatCurrencyFor(amount, AppCurrency)` (passes the symbol
  directly, uses `currency.formatTag` only for the `NumberFormat`
  decimal/thousand separators), and `reports_page.dart:224`
  (`formatWithSettings`) switches to it.
- **main.dart** — no change needed: every `formatTag` in the catalog is
  already an initialized language tag, so `Strings.initIntlDateFormats()`
  covers them as-is.

### 2.5 Settings UI

`lib/presentation/pages/settings/settings_page.dart`

New row in the Aparência card, **below** the language row:

```
[icon: attach_money]  Moeda          →  "Real brasileiro (R$)"
```

- `ListTile` watches `appCurrencyProvider`, shows `displayName` + `symbol`.
- `onTap` → `showDialog` with `DropdownButtonFormField<AppCurrency>` (same shape as the language dialog — we just fixed that layout crash; reuse the pattern: **no** `SizedBox(width: double.maxFinite)` wrapper, **no** `Expanded` inside `DropdownMenuItem`).
- `onChanged` → `ref.read(currencyProvider.notifier).setCurrency(c)` → close dialog.

### 2.6 New l10n keys

`strings.dart`:
- `settings.currency` → "Moeda" / "Currency"
- `settings.chooseCurrency` → "Escolher moeda" / "Choose currency"

---

## 3. Platforms

### 3.1 New data: persisted per-country active list + user-created platforms

The existing `country_platforms` table (`app_database.dart`, schema v2) already
holds one row per (country, platform) pair — it is the **single source of
truth**, and we extend it in place rather than adding a parallel
`active_platforms` table:

```
ALTER country_platforms ADD is_active INTEGER NOT NULL DEFAULT 1;
ALTER country_platforms ADD is_custom INTEGER NOT NULL DEFAULT 0;
-- schemaVersion 2 -> 3 (onCreate + onUpgrade)
```

`is_active` toggles from the UI; `is_custom` marks user-created names
(customs can be deleted; built-ins are only toggled, never removed).

### 3.2 New DAO

`lib/data/datasources/local/platforms_dao.dart` — a **new** `PlatformsDao`
(its own `DatabaseAccessor<AppDatabase>`), because the existing
`CountryPlatformsDao` / `AppDao.upsert*` methods are static seeders with no
per-row `is_active`/`is_custom` awareness. No code is duplicated — it reads
and writes the same extended table:

```
class PlatformsDao extends DatabaseAccessor<AppDatabase> {
  Future<List<String>> getActiveFor(String countryCode);
  Future<List<String>> getAllFor(String countryCode);        // built-in + custom
  Future<void> setActive(String countryCode, String platform, bool active);
  Future<void> createCustom(String countryCode, String platform); // upsert, is_custom=1
  Future<void> deleteCustom(String countryCode, String platform); // only when is_custom=1
}
```

### 3.3 New state: PlatformsProvider

`lib/core/l10n/platforms_provider.dart`

- `PlatformInfo { name: String; isActive: bool; isCustom: bool; }`
  (one per row, not two string lists — a plain `active`/`custom` split
  cannot represent a **disabled custom** that still occupies its name).
- `AppPlatformsPref { countryCode; platforms: List<PlatformInfo>; }`
- `PlatformsNotifier extends StateNotifier<AppPlatformsPref>`:
  - `initialize()` — loads all rows for the current country from
    `PlatformsDao`; if the country has no rows at all, seeds with
    `CountryEntry.platforms` (all active, not custom).
  - `togglePlatform(name, active)` — persists via `setActive`.
  - `addPlatform(name)` — upserts a custom row (active), persists via
    `createCustom`. Callers pre-validate duplicates (case-insensitive vs
    all existing names).
  - `removePlatform(name)` — deletes the row (customs only), persists
    via `deleteCustom`.
  - Same `_disposed` guard pattern as `LanguageNotifier`.
- `platformsDaoProvider` → `PlatformsDao(appDatabaseProviderForSettings)`.
- `platformsProvider` (StateNotifierProvider, auto-dispose with Riverpod).
- `activePlatformsProvider` → `[...platforms.where(p => p.isActive).map(p => p.name)]`,
  watched by ride form dropdowns.

### 3.4 Where platform list comes from changes

Currently, every form builds the dropdown from `settings.platforms` (the country's built-in list). After this:

- **ride_form_page.dart** — `ref.watch(activePlatformsProvider)` instead of `ref.watch(appSettingsProvider).platforms`.
- **rides_page / expenses_page** — any place that shows a "platform" badge filters by active.
- The **expense form has no platform dropdown** (only a category dropdown) — it does **not** consume the active list.
- If `active` list is empty (user toggled everything off), the forms fall back to the country default (no empty dropdowns).

### 3.5 Settings UI — Platforms manager

`lib/presentation/pages/settings/platforms_page.dart` (new page, `Navigator.push`)

Tapping the "Plataformas" tile in Settings → Aparência opens this page.

Layout:
- **AppBar**: "Plataformas" — **no delete button in the AppBar**; there is no
  "selected platform" concept. Deletion happens per-row instead.
- **List**: every platform in the current country (built-ins + custom) shown
  as a `ListTile` with a `Switch` on the trailing side.
  - Built-in: `Switch` → `togglePlatform(name)` (switch off removes from
    `active`, on adds). No delete — built-ins can't be removed.
  - Custom: `Switch` (same as built-in) **plus a delete `IconButton`** to
    the left of the switch, always visible for customs (delete a custom
    name even while it's active — that's the supported path).
- **Bottom**: "Adicionar plataforma" tile → opens a dialog:
  - A chip row of the country's built-in platforms that aren't active yet
    (tap = activate it).
  - A text field + "Criar nova" button → `addPlatform(name)` with
    validation: non-empty, not a duplicate of any existing (built-in or
    custom, case-insensitive) → shows "Já existe" and blocks the button
    (**user-confirmed requirement**).

### 3.6 Settings UI — tile in Aparência card

New row below the currency row:

```
[icon: directions_car]  Plataformas   →  "Uber, 99, inDrive (+3)"
```

- Subtitle shows the active names (up to 3, then `+N` for overflow) — this is
  a **new** subtitle pattern for this tile; the language tile above it uses a
  plain `Text(currentLang.displayName)`, so the "+N" truncation is
  specific to the platforms row (long lists would overflow otherwise).
- `onTap` → `Navigator.push(context, MaterialPageRoute(builder: (_) => PlatformsPage()))`.

### 3.7 New l10n keys

- `settings.platforms` → "Plataformas" / "Platforms"
- `settings.platformsSub` → "Uber, 99, inDrive (+3)" (computed in UI, but key for the title)
- `platforms.addTitle` → "Adicionar plataforma"
- `platforms.create` → "Criar nova"
- `platforms.nameHint` → "Nome da plataforma"
- `platforms.exists` → "Já existe" (duplicate check)
- `platforms.remove` → "Remover"

---

## 4. Database migration

`lib/data/datasources/local/app_database.dart` — `schemaVersion` 2 → 3:
add `is_active` (default 1) and `is_custom` (default 0) columns to the
existing `country_platforms` table. Additive only — no destructive
migration.

## 5. Risks / Open questions

- **Currency switching doesn't convert values**: if a user switches from BRL to EUR while having R$ 50,000 recorded, the dashboard will display "€ 50,000.00" (same number, different symbol). That is **explicitly what the user asked for** ("apenas trocar o cifrão"). No converter. If they later want conversion, that's a separate ticket.
- **Platform active list is per-country and does NOT reset on language/currency switch** — only on **country switch** does the loaded platform list change to that country's active list. (User confirmed this: "a seleção de ativas/desativadas + plataformas criadas persiste por país".)
- **Custom platform names persist in the DB** but are only reachable from the current country's Platforms page. If a user creates "99 Pop" under BR, then switches to PT, "99 Pop" is still in the DB but not shown (correct — it's BR's).
- **Duplicate-name validation** (user requirement): "Criar nova" is blocked with "Já existe" when the trimmed name matches any existing platform of that country (built-in or custom, case-insensitive).

## 6. What's left to the builder

- Exact wording of subtitle/label texts (reasonable defaults picked, user
  can reword).
- Live currency update while the settings dialog is open: **yes** (same as
  language).
- Platform form delete affordance: customs always show the delete
  `IconButton` (delete works even when the switch is off); built-ins
  only toggle — no delete.
- Duplicate check is case-insensitive and trims whitespace before
  comparison (my call).
