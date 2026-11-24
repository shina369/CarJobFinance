// PlatformsPage – manage active platforms for the current country.
// Built-ins can be toggled on/off; customs can also be deleted.
// New platforms are added from a bottom sheet that validates duplicate names
// (case-insensitive, against both built-ins and existing customs).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/finance/commission.dart';
import '../../../core/settings/country_data.dart';
import '../../../core/l10n/currency_provider.dart';
import '../../../core/l10n/language_provider.dart';
import '../../../core/l10n/platforms_provider.dart';
import '../../../core/l10n/strings.dart';
import '../../controllers/controllers.dart' show rideRepositoryProvider;

class PlatformsPage extends ConsumerWidget {
  const PlatformsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    String tr(String key) => lang.tr(key);

    final platforms = ref.watch(platformsProvider);
    final active = platforms.platforms.where((p) => p.isActive).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final inactive = platforms.platforms.where((p) => !p.isActive).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return Scaffold(
      appBar: AppBar(title: Text(tr('platforms.title'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context, platforms),
        icon: const Icon(Icons.add),
        label: Text(tr('platforms.add')),
      ),
      body: platforms.platforms.isEmpty
          ? Center(
              child: Text(tr('platforms.none'),
                  style: Theme.of(context).textTheme.bodyMedium))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                if (active.isNotEmpty) ...[
                  _SectionTitle(text: tr('platforms.active')),
                  _PlatformsCard(platforms: active),
                  const SizedBox(height: 24),
                ],
                if (inactive.isNotEmpty) ...[
                  _SectionTitle(
                    text: tr('platforms.inactive'),
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
                  _PlatformsCard(platforms: inactive),
                ],
              ],
            ),
    );
  }

  /// Built-in platform names from every other country, deduplicated and
  /// skipping any name already in [excludedLowerNames] (lowercase).
  static List<String> _platformsFromOtherCountries(
    String currentCountryCode, {
    required Set<String> excludedLowerNames,
  }) {
    final seen = <String>{...excludedLowerNames};
    final names = <String>[];
    for (final country in COUNTRIES) {
      if (country.code == currentCountryCode) continue;
      for (final name in country.platforms) {
        if (seen.add(name.toLowerCase())) names.add(name);
      }
    }
    return names;
  }

  void _showAddSheet(BuildContext context, AppPlatformsPref platforms) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _AddPlatformSheet(platforms: platforms),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: color ?? Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _PlatformsCard extends StatelessWidget {
  const _PlatformsCard({required this.platforms});

  final List<AppPlatformInfo> platforms;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < platforms.length; i++) ...[
            _PlatformTile(platform: platforms[i]),
            if (i < platforms.length - 1)
              const Divider(height: 1, indent: 64, endIndent: 16),
          ],
        ],
      ),
    );
  }
}

class _PlatformTile extends ConsumerWidget {
  const _PlatformTile({required this.platform});

  final AppPlatformInfo platform;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    String tr(String key) => lang.tr(key);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final currency = ref.watch(appCurrencyProvider);
    final subtitleParts = <String>[
      if (platform.isCustom) tr('platforms.custom'),
      if (platform.hasCommission)
        lang.tr(
          'platforms.commissionLabel',
          args: {
            'value': formatCommissionConfig(platform.commissionType,
                platform.commissionValue ?? 0, currency),
          },
        ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                child: Text(
                  platform.name.isNotEmpty
                      ? platform.name[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      platform.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w500),
                    ),
                    if (subtitleParts.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitleParts.join(' • '),
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                  ],
                ),
              ),
              Switch(
                value: platform.isActive,
                onChanged: (active) => ref
                    .read(platformsProvider.notifier)
                    .togglePlatform(platform.name, active),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 40),
            child: Row(
              children: [
                TextButton.icon(
                  icon: Icon(
                    Icons.percent,
                    size: 16,
                    color: platform.hasCommission ? primary : null,
                  ),
                  label: Text(
                    tr('platforms.commissionSet'),
                    style: TextStyle(
                      fontSize: 13,
                      color: platform.hasCommission ? primary : null,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => _showCommissionDialog(context, ref),
                ),
                if (platform.isCustom) ...[
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    tooltip: tr('platforms.delete'),
                    onPressed: () =>
                        _confirmDelete(context, ref, tr, platform.name),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCommissionDialog(BuildContext context, WidgetRef ref) {
    final lang = ref.read(appLanguageProvider);
    final currency = ref.read(appCurrencyProvider);
    var type = platform.commissionType ?? kCommissionPercent;
    final valueCtrl = TextEditingController(
      text: platform.commissionValue != null
          ? trimCommissionNumber(platform.commissionValue!)
          : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final parsed =
              double.tryParse(valueCtrl.text.trim().replaceAll(',', '.'));
          final isValid = parsed != null &&
              parsed > 0 &&
              (type != kCommissionPercent || parsed <= 100);

          return AlertDialog(
            title:
                Text('${lang.tr('platforms.commission')} — ${platform.name}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: kCommissionPercent,
                      label: Text(lang.tr('platforms.commissionPercent')),
                    ),
                    ButtonSegment(
                      value: kCommissionFixed,
                      label: Text(lang.tr('platforms.commissionFixed')),
                    ),
                  ],
                  selected: {type},
                  onSelectionChanged: (selection) =>
                      setModalState(() => type = selection.first),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: valueCtrl,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setModalState(() {}),
                  decoration: InputDecoration(
                    labelText: lang.tr('platforms.commissionValue'),
                    prefixText:
                        type == kCommissionFixed ? '${currency.symbol} ' : null,
                    suffixText: type == kCommissionPercent ? '%' : null,
                    filled: true,
                    fillColor:
                        Theme.of(ctx).colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    isDense: true,
                  ),
                ),
              ],
            ),
            actions: [
              if (platform.hasCommission)
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _applyCommission(context, ref, null, null);
                  },
                  child: Text(
                    lang.tr('platforms.commissionRemove'),
                    style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                  ),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(lang.tr('dash.cancel')),
              ),
              FilledButton(
                onPressed: isValid
                    ? () {
                        Navigator.pop(ctx);
                        _applyCommission(context, ref, type, parsed);
                      }
                    : null,
                child: Text(lang.tr('platforms.commissionSet')),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Persists the new commission config, then — if this platform already
  /// has recorded rides — asks whether to recalculate their snapshots or
  /// apply the change only to new rides.
  Future<void> _applyCommission(
      BuildContext context, WidgetRef ref, String? type, double? value) async {
    final lang = ref.read(appLanguageProvider);
    await ref
        .read(platformsProvider.notifier)
        .setCommission(platform.name, type, value);

    final repository = ref.read(rideRepositoryProvider);
    final rides = (await repository.getAll())
        .where((r) => r.platform == platform.name)
        .toList();
    if (rides.isEmpty || !context.mounted) return;

    final applyAll = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.tr('platforms.commissionApplyTitle')),
        content: Text(lang.tr(
          'platforms.commissionApplyMsg',
          args: {
            'platform': platform.name,
            'count': '${rides.length}',
          },
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(lang.tr('platforms.commissionOnlyNew')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(lang.tr('platforms.commissionApplyAll')),
          ),
        ],
      ),
    );
    if (applyAll != true) return;

    for (final ride in rides) {
      await repository.update(ride.copyWith(
        commissionType: type,
        commissionValue: value,
        commissionAmount: commissionAmountFor(ride.earnings, type, value),
      ));
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref,
      String Function(String) tr, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('platforms.deleteCustomConfirm')),
        content: Text(tr('platforms.deleteCustomMsg')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('dash.cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () {
              ref.read(platformsProvider.notifier).removeCustomPlatform(name);
              Navigator.pop(ctx);
            },
            child: Text(tr('platforms.delete')),
          ),
        ],
      ),
    );
  }
}

class _AddPlatformSheet extends ConsumerStatefulWidget {
  const _AddPlatformSheet({required this.platforms});

  final AppPlatformsPref platforms;

  @override
  ConsumerState<_AddPlatformSheet> createState() => _AddPlatformSheetState();
}

class _AddPlatformSheetState extends ConsumerState<_AddPlatformSheet> {
  final _newCtrl = TextEditingController();

  late final Set<String> _existingLower =
      widget.platforms.platforms.map((p) => p.name.toLowerCase()).toSet();

  late final List<String> _inactiveBuiltins =
      widget.platforms.inactiveBuiltinNames;

  late final List<String> _otherCountryNames =
      PlatformsPage._platformsFromOtherCountries(
    widget.platforms.countryCode,
    excludedLowerNames: _existingLower.union(
      _inactiveBuiltins.map((n) => n.toLowerCase()).toSet(),
    ),
  );

  @override
  void dispose() {
    _newCtrl.dispose();
    super.dispose();
  }

  void _activate(String name) {
    ref.read(platformsProvider.notifier).togglePlatform(name, true);
    Navigator.pop(context);
  }

  void _addCustom(String name) {
    ref.read(platformsProvider.notifier).addCustomPlatform(name);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLanguageProvider);
    final theme = Theme.of(context);
    final hasSuggestions =
        _inactiveBuiltins.isNotEmpty || _otherCountryNames.isNotEmpty;

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _newCtrl,
      builder: (context, value, _) {
        final entered = value.text.trim();
        final isDuplicate = entered.isNotEmpty &&
            _existingLower.contains(entered.toLowerCase());
        final canCreate = entered.isNotEmpty && !isDuplicate;

        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                child: Text(
                  lang.tr('platforms.add'),
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_inactiveBuiltins.isNotEmpty) ...[
                        _SectionTitle(text: lang.tr('platforms.addExisting')),
                        _ChipGroup(
                          names: _inactiveBuiltins,
                          onSelected: _activate,
                        ),
                        const SizedBox(height: 24),
                      ],
                      if (_otherCountryNames.isNotEmpty) ...[
                        _SectionTitle(
                            text: lang.tr('platforms.addFromOtherCountries')),
                        _ChipGroup(
                          names: _otherCountryNames,
                          onSelected: _addCustom,
                        ),
                        const SizedBox(height: 24),
                      ],
                      if (hasSuggestions) ...[
                        const Divider(height: 1),
                        const SizedBox(height: 24),
                      ],
                      TextField(
                        controller: _newCtrl,
                        autofocus: !hasSuggestions,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: lang.tr('platforms.newName'),
                          hintText: lang.tr('platforms.namePlaceholder'),
                          errorText: isDuplicate
                              ? lang.tr('platforms.duplicate')
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(lang.tr('dash.cancel')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: canCreate ? () => _addCustom(entered) : null,
                        child: Text(lang.tr('platforms.createNew')),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChipGroup extends StatelessWidget {
  const _ChipGroup({required this.names, required this.onSelected});

  final List<String> names;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final name in names)
          ActionChip(
            avatar: Icon(Icons.add, size: 16, color: primary),
            label: Text(name),
            onPressed: () => onSelected(name),
          ),
      ],
    );
  }
}
