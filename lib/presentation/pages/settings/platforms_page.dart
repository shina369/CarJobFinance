// PlatformsPage – manage active platforms for the current country.
// Built-ins can be toggled on/off; customs can also be deleted.
// New platforms are created via a dialog that validates duplicate names
// (case-insensitive, against both built-ins and existing customs).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/l10n/language_provider.dart';
import '../../../core/l10n/platforms_provider.dart';
import '../../../core/l10n/strings.dart';

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
        onPressed: () => _showAddDialog(context, ref, tr, platforms),
        icon: const Icon(Icons.add),
        label: Text(tr('platforms.add')),
      ),
      body: Column(
        children: [
          if (active.isEmpty && inactive.isEmpty)
            Expanded(
              child: Center(
                  child: Text(tr('platforms.none'),
                      style: Theme.of(context).textTheme.bodyMedium)),
            )
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (active.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, left: 4),
                      child: Text(
                        tr('platforms.active'),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    Card(
                      child: Column(
                        children: active
                            .map((p) => _PlatformTile(
                                  platform: p,
                                  tr: tr,
                                  ref: ref,
                                ))
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (inactive.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, left: 4),
                      child: Text(
                        tr('platforms.inactive'),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.5),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    Card(
                      child: Column(
                        children: inactive
                            .map((p) => _PlatformTile(
                                  platform: p,
                                  tr: tr,
                                  ref: ref,
                                ))
                            .toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref,
      String Function(String) tr, AppPlatformsPref platforms) {
    final existingNames =
        platforms.platforms.map((p) => p.name.toLowerCase()).toSet();
    final inactiveBuiltins = platforms.inactiveBuiltinNames;
    final newCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final entered = newCtrl.text.trim();
            final isDuplicate = entered.isNotEmpty &&
                existingNames.contains(entered.toLowerCase());

            return AlertDialog(
              title: Text(tr('platforms.add')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (inactiveBuiltins.isNotEmpty) ...[
                    Text(
                      tr('platforms.addExisting'),
                      style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                            color: Theme.of(ctx).colorScheme.primary,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: inactiveBuiltins
                          .map(
                            (name) => ActionChip(
                              label: Text(name),
                              onPressed: () {
                                ref
                                    .read(platformsProvider.notifier)
                                    .togglePlatform(name, true);
                                Navigator.pop(ctx);
                              },
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                    Divider(height: 1, color: Theme.of(ctx).dividerColor),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    tr('platforms.createNew'),
                    style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                          color: Theme.of(ctx).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: newCtrl,
                    autofocus: inactiveBuiltins.isEmpty,
                    onChanged: (_) => setModalState(() {}),
                    decoration: InputDecoration(
                      labelText: tr('platforms.newName'),
                      hintText: tr('platforms.namePlaceholder'),
                      errorText: isDuplicate ? tr('platforms.duplicate') : null,
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
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(tr('dash.cancel')),
                ),
                FilledButton(
                  onPressed: (entered.isNotEmpty && !isDuplicate)
                      ? () {
                          ref
                              .read(platformsProvider.notifier)
                              .addCustomPlatform(entered);
                          Navigator.pop(ctx);
                        }
                      : null,
                  child: Text(tr('platforms.createNew')),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _PlatformTile extends ConsumerWidget {
  const _PlatformTile({
    required this.platform,
    required this.tr,
    required this.ref,
  });

  final AppPlatformInfo platform;
  final String Function(String) tr;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef _) {
    return ListTile(
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Text(
          platform.name.isNotEmpty ? platform.name[0].toUpperCase() : '?',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
      title: Text(platform.name),
      subtitle: platform.isCustom
          ? Text(tr('platforms.custom'),
              style: const TextStyle(fontSize: 11, color: Colors.grey))
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (platform.isCustom)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: tr('platforms.delete'),
              onPressed: () => _confirmDelete(context, ref, tr, platform.name),
            ),
          Switch(
            value: platform.isActive,
            onChanged: (active) => ref
                .read(platformsProvider.notifier)
                .togglePlatform(platform.name, active),
          ),
        ],
      ),
    );
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
