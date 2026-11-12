// Shown right after login when a decision is needed before entering the
// app: data from another account on the device, or a cloud backup to restore.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/language_provider.dart';
import '../../../core/l10n/strings.dart';
import '../../controllers/session_controller.dart';
import 'auth_widgets.dart';

class AccountGatePage extends ConsumerStatefulWidget {
  const AccountGatePage({super.key});

  @override
  ConsumerState<AccountGatePage> createState() => _AccountGatePageState();
}

class _AccountGatePageState extends ConsumerState<AccountGatePage>
    with AuthFormMixin {
  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLanguageProvider);
    final session = ref.watch(sessionProvider);
    final controller = ref.read(sessionProvider.notifier);

    if (session.gate == LoginGate.foreignData) {
      return AuthScaffold(
        title: lang.tr('gate.foreignTitle'),
        subtitle: lang.tr(
          'gate.foreignMsg',
          args: {'email': session.user?.email ?? ''},
        ),
        children: [
          AuthErrorText(error),
          FilledButton(
            key: const Key('gate-confirm'),
            onPressed:
                busy ? null : () => submit(controller.discardForeignData),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: Text(lang.tr('gate.foreignConfirm')),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            key: const Key('gate-cancel'),
            onPressed: busy ? null : () => submit(controller.cancelLogin),
            style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48)),
            child: Text(lang.tr('gate.foreignCancel')),
          ),
        ],
      );
    }

    final backupAt = session.cloudBackupAt;
    final date = backupAt == null
        ? ''
        : DateFormat.yMd(lang.tag).add_Hm().format(backupAt.toLocal());

    return AuthScaffold(
      title: lang.tr('gate.restoreTitle'),
      subtitle: lang.tr('gate.restoreMsg', args: {'date': date}),
      children: [
        AuthErrorText(error),
        AuthSubmitButton(
          label: lang.tr('gate.restoreConfirm'),
          busy: busy,
          onPressed: () => submit(controller.acceptRestore),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          key: const Key('gate-cancel'),
          onPressed: busy ? null : controller.declineRestore,
          style:
              OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: Text(lang.tr('gate.restoreSkip')),
        ),
      ],
    );
  }
}
