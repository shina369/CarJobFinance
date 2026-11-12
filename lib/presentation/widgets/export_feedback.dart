// Runs an export/backup action and reports the outcome in a SnackBar.
import 'package:flutter/material.dart';

import '../../core/l10n/languages.dart';
import '../../core/l10n/strings.dart';

/// [action] returns false when the user cancelled (no message is shown).
Future<void> runExport(
  BuildContext context,
  AppLanguage lang,
  Future<bool> Function() action,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    if (await action()) {
      messenger.showSnackBar(SnackBar(content: Text(lang.tr('export.done'))));
    }
  } catch (e) {
    messenger.showSnackBar(SnackBar(
      content: Text(lang.tr('export.failed', args: {'error': '$e'})),
    ));
  }
}
