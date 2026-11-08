// Settings Page - Configurações
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Aparência
          const _SectionHeader('Aparência'),
          Card(
            child: Column(
              children: [
                Consumer(
                  builder: (context, ref, _) {
                    final themeMode = ref.watch(themeModeProvider);
                    return ListTile(
                      leading: Icon(
                        Icons.palette_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: const Text('Tema'),
                      subtitle: Text(_themeModeToString(themeMode)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showThemeDialog(context, ref),
                    );
                  },
                ),
                const Divider(height: 1, indent: 72),
                ListTile(
                  leading: Icon(
                    Icons.language_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: const Text('Idioma'),
                  subtitle: const Text('Português (Brasil)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Show language selector
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Dados
          const _SectionHeader('Dados e Backup'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.backup_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: const Text('Backup e Restauração'),
                  subtitle: const Text('Exportar/Importar dados'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Navigate to backup page
                  },
                ),
                const Divider(height: 1, indent: 72),
                ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: const Text('Limpar Todos os Dados'),
                  subtitle: const Text('Apaga corridas, despesas e configurações'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showClearDataDialog(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Notificações
          const _SectionHeader('Notificações'),
          Card(
            child: Column(
              children: [
                Consumer(
                  builder: (context, ref, _) {
                    // TODO: Connect to notification settings provider
                    return SwitchListTile(
                      secondary: Icon(
                        Icons.notifications_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: const Text('Notificações Ativas'),
                      subtitle: const Text('Receber lembretes e alertas'),
                      value: true, // TODO: actual value
                      onChanged: (value) {
                        // TODO: Toggle notifications
                      },
                    );
                  },
                ),
                const Divider(height: 1, indent: 72),
                ListTile(
                  leading: Icon(
                    Icons.schedule_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: const Text('Lembrete Diário'),
                  subtitle: const Text('Configurar horário do lembrete'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Show time picker for daily reminder
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Sobre
          const _SectionHeader('Sobre'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: const Text('Versão do App'),
                  subtitle: const Text('1.0.0'),
                ),
                const Divider(height: 1, indent: 72),
                ListTile(
                  leading: Icon(
                    Icons.article_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: const Text('Termos de Uso'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Show terms
                  },
                ),
                const Divider(height: 1, indent: 72),
                ListTile(
                  leading: Icon(
                    Icons.privacy_tip_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: const Text('Política de Privacidade'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Show privacy policy
                  },
                ),
                const Divider(height: 1, indent: 72),
                ListTile(
                  leading: Icon(
                    Icons.bug_report_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: const Text('Reportar Problema'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Open issue tracker/email
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Claro';
      case ThemeMode.dark:
        return 'Escuro';
      case ThemeMode.system:
        return 'Sistema';
    }
  }

  void _showThemeDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        final currentMode = ref.read(themeModeProvider);
        return AlertDialog(
          title: const Text('Escolher Tema'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<ThemeMode>(
                title: const Text('Claro'),
                value: ThemeMode.light,
                groupValue: currentMode,
                onChanged: (value) {
                  if (value != null) {
                    ref.read(themeModeProvider.notifier).state = value;
                    Navigator.pop(context);
                  }
                },
              ),
              RadioListTile<ThemeMode>(
                title: const Text('Escuro'),
                value: ThemeMode.dark,
                groupValue: currentMode,
                onChanged: (value) {
                  if (value != null) {
                    ref.read(themeModeProvider.notifier).state = value;
                    Navigator.pop(context);
                  }
                },
              ),
              RadioListTile<ThemeMode>(
                title: const Text('Sistema'),
                value: ThemeMode.system,
                groupValue: currentMode,
                onChanged: (value) {
                  if (value != null) {
                    ref.read(themeModeProvider.notifier).state = value;
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showClearDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar Todos os Dados?'),
        content: const Text(
          'Esta ação é irreversível. Todas as suas corridas, despesas '
          'e configurações serão apagadas permanentemente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              // TODO: Clear all data
              Navigator.pop(context);
            },
            child: const Text('Apagar Tudo'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}