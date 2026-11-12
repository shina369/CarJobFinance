// Reminders page: create reminders with their days, time, message and sound.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/language_provider.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/notifications/notification_settings.dart';
import '../../../core/notifications/reminder.dart';

const _weekdays = {1, 2, 3, 4, 5};
const _weekend = {6, 7};

String daysSummary(Set<int> days, String Function(String) tr) {
  if (days.length == 7) return tr('reminders.everyDay');
  if (setEquals(days, _weekdays)) return tr('reminders.weekdays');
  if (setEquals(days, _weekend)) return tr('reminders.weekend');
  final sorted = days.toList()..sort();
  return sorted.map((d) => tr('day.$d')).join(', ');
}

class RemindersPage extends ConsumerWidget {
  const RemindersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    String tr(String key) => lang.tr(key);
    final prefs = ref.watch(notificationSettingsProvider);
    final notifier = ref.read(notificationSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(tr('reminders.title'))),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('reminder-add'),
        onPressed: () => _openEditor(context, null),
        shape: const StadiumBorder(),
        icon: const Icon(Icons.add),
        label: Text(tr('reminders.add')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          if (!prefs.enabled)
            Card(
              child: ListTile(
                leading: const Icon(Icons.notifications_off_outlined),
                title: Text(tr('reminders.notificationsOff')),
                trailing: FilledButton(
                  key: const Key('reminders-enable'),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final ok =
                        await notifier.setEnabled(true, reminderTextFor(tr));
                    if (!ok) {
                      messenger.showSnackBar(SnackBar(
                          content:
                              Text(tr('settings.notificationsUnavailable'))));
                    }
                  },
                  child: Text(tr('reminders.enable')),
                ),
              ),
            ),
          if (prefs.reminders.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Text(
                tr('reminders.empty'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          for (final reminder in prefs.reminders)
            _ReminderCard(
              reminder: reminder,
              tr: tr,
              onTap: () => _openEditor(context, reminder),
              onToggle: (value) => notifier.save(
                  reminder.copyWith(enabled: value), reminderTextFor(tr)),
            ),
        ],
      ),
    );
  }

  void _openEditor(BuildContext context, Reminder? reminder) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ReminderEditorPage(reminder: reminder),
    ));
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.reminder,
    required this.tr,
    required this.onTap,
    required this.onToggle,
  });

  final Reminder reminder;
  final String Function(String) tr;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final time =
        TimeOfDay(hour: reminder.hour, minute: reminder.minute).format(context);
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(time,
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(daysSummary(reminder.days, tr)),
                    const SizedBox(height: 2),
                    Text(
                      reminder.message ?? tr('notif.reminderTitle'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Switch(
                key: Key('reminder-switch-${reminder.id}'),
                value: reminder.enabled,
                onChanged: onToggle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _MessageChoice { standard, rest, work, custom }

class ReminderEditorPage extends ConsumerStatefulWidget {
  const ReminderEditorPage({super.key, this.reminder});

  /// The reminder being edited; null creates a new one.
  final Reminder? reminder;

  @override
  ConsumerState<ReminderEditorPage> createState() => _ReminderEditorPageState();
}

class _ReminderEditorPageState extends ConsumerState<ReminderEditorPage> {
  late TimeOfDay _time;
  late Set<int> _days;
  late _MessageChoice _choice;
  late final TextEditingController _custom;
  String? _soundUri;
  String? _soundName;

  @override
  void initState() {
    super.initState();
    final r = widget.reminder;
    _time = TimeOfDay(hour: r?.hour ?? 20, minute: r?.minute ?? 0);
    _days = {...(r?.days ?? Reminder.allDays)};
    _soundUri = r?.soundUri;
    _soundName = r?.soundName;
    final tr = ref.read(appLanguageProvider).tr;
    final message = r?.message;
    _custom = TextEditingController();
    if (message == null) {
      _choice = _MessageChoice.standard;
    } else if (message == tr('settings.reminderMessageRest')) {
      _choice = _MessageChoice.rest;
    } else if (message == tr('settings.reminderMessageWork')) {
      _choice = _MessageChoice.work;
    } else {
      _choice = _MessageChoice.custom;
      _custom.text = message;
    }
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  String? _message(String Function(String) tr) => switch (_choice) {
        _MessageChoice.standard => null,
        _MessageChoice.rest => tr('settings.reminderMessageRest'),
        _MessageChoice.work => tr('settings.reminderMessageWork'),
        _MessageChoice.custom =>
          _custom.text.trim().isEmpty ? null : _custom.text.trim(),
      };

  bool get _canSave =>
      _days.isNotEmpty &&
      (_choice != _MessageChoice.custom || _custom.text.trim().isNotEmpty);

  Reminder _build(String Function(String) tr) {
    final notifier = ref.read(notificationSettingsProvider.notifier);
    final base = widget.reminder;
    return Reminder(
      id: base?.id ?? notifier.nextId(),
      hour: _time.hour,
      minute: _time.minute,
      days: {..._days},
      message: _message(tr),
      soundUri: _soundUri,
      soundName: _soundName,
      enabled: base?.enabled ?? true,
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _pickSound() async {
    final sound =
        await ref.read(notificationServiceProvider).pickSound(_soundUri);
    if (sound == null || !mounted) return;
    setState(() {
      _soundUri = sound.uri;
      _soundName = sound.title;
    });
  }

  Future<void> _test(String Function(String) tr) async {
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(notificationSettingsProvider.notifier);
    if (!await ref.read(notificationServiceProvider).requestPermission()) {
      messenger.showSnackBar(
          SnackBar(content: Text(tr('settings.notificationsUnavailable'))));
      return;
    }
    await notifier.preview(_build(tr), reminderTextFor(tr));
  }

  Future<void> _save(String Function(String) tr) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final notifier = ref.read(notificationSettingsProvider.notifier);
    final text = reminderTextFor(tr);
    var ok = true;
    // A reminder is useless with notifications off, so turn them on too.
    if (!ref.read(notificationSettingsProvider).enabled) {
      ok = await notifier.setEnabled(true, text);
    }
    await notifier.save(_build(tr), text);
    if (!ok) {
      messenger.showSnackBar(
          SnackBar(content: Text(tr('settings.notificationsUnavailable'))));
    }
    navigator.pop();
  }

  Future<void> _delete() async {
    final navigator = Navigator.of(context);
    await ref
        .read(notificationSettingsProvider.notifier)
        .remove(widget.reminder!.id);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLanguageProvider);
    String tr(String key) => lang.tr(key);
    final editing = widget.reminder != null;
    final android = defaultTargetPlatform == TargetPlatform.android;

    Widget header(String text) => Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Text(text,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600)),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(editing ? 'reminders.edit' : 'reminders.add')),
        actions: [
          if (editing)
            IconButton(
              key: const Key('reminder-delete'),
              icon: const Icon(Icons.delete_outline),
              tooltip: tr('reminders.delete'),
              onPressed: _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          header(tr('reminders.time')),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              key: const Key('reminder-time'),
              leading: const Icon(Icons.schedule_outlined),
              title: Text(_time.format(context),
                  style: Theme.of(context).textTheme.titleLarge),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickTime,
            ),
          ),
          header(tr('reminders.days')),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (var day = 1; day <= 7; day++)
                FilterChip(
                  key: Key('reminder-day-$day'),
                  label: Text(tr('day.$day')),
                  selected: _days.contains(day),
                  onSelected: (on) =>
                      setState(() => on ? _days.add(day) : _days.remove(day)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              ActionChip(
                key: const Key('reminder-days-all'),
                label: Text(tr('reminders.everyDay')),
                onPressed: () => setState(() => _days = {...Reminder.allDays}),
              ),
              ActionChip(
                key: const Key('reminder-days-weekdays'),
                label: Text(tr('reminders.weekdays')),
                onPressed: () => setState(() => _days = {..._weekdays}),
              ),
              ActionChip(
                key: const Key('reminder-days-weekend'),
                label: Text(tr('reminders.weekend')),
                onPressed: () => setState(() => _days = {..._weekend}),
              ),
            ],
          ),
          if (_days.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(tr('reminders.noDays'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          header(tr('reminders.message')),
          Card(
            margin: EdgeInsets.zero,
            child: RadioGroup<_MessageChoice>(
              groupValue: _choice,
              onChanged: (value) {
                if (value != null) setState(() => _choice = value);
              },
              child: Column(
                children: [
                  for (final (choice, key, label) in [
                    (
                      _MessageChoice.standard,
                      'default',
                      tr('notif.reminderTitle')
                    ),
                    (
                      _MessageChoice.rest,
                      'rest',
                      tr('settings.reminderMessageRest')
                    ),
                    (
                      _MessageChoice.work,
                      'work',
                      tr('settings.reminderMessageWork')
                    ),
                    (
                      _MessageChoice.custom,
                      'custom',
                      tr('settings.reminderMessageCustom')
                    ),
                  ])
                    RadioListTile<_MessageChoice>(
                      key: Key('reminder-message-$key'),
                      value: choice,
                      title: Text(label),
                    ),
                  if (_choice == _MessageChoice.custom)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: TextField(
                        key: const Key('reminder-message-custom-field'),
                        controller: _custom,
                        autofocus: true,
                        maxLength: 60,
                        decoration: InputDecoration(
                            hintText: tr('settings.reminderMessageHint')),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (android) ...[
            header(tr('reminders.sound')),
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                key: const Key('reminder-sound'),
                leading: const Icon(Icons.music_note_outlined),
                title: Text((_soundName ?? '').isEmpty
                    ? tr('reminders.soundDefault')
                    : _soundName!),
                trailing: _soundUri == null
                    ? const Icon(Icons.chevron_right)
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() {
                          _soundUri = null;
                          _soundName = null;
                        }),
                      ),
                onTap: _pickSound,
              ),
            ),
          ],
          const SizedBox(height: 24),
          OutlinedButton.icon(
            key: const Key('reminder-test'),
            onPressed: () => _test(tr),
            icon: const Icon(Icons.notifications_active_outlined),
            label: Text(tr('reminders.test')),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('reminder-save'),
            onPressed: _canSave ? () => _save(tr) : null,
            child: Text(tr('reminders.save')),
          ),
        ],
      ),
    );
  }
}
