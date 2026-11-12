// Forgot password: ask for a code by e-mail, then set a new password.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/language_provider.dart';
import '../../../core/l10n/strings.dart';
import '../../controllers/session_controller.dart';
import 'auth_widgets.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage>
    with AuthFormMixin {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  String? _codeSentTo;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _email.text.trim();
    final ok = await submit(
        () => ref.read(sessionProvider.notifier).sendPasswordResetCode(email));
    if (ok && mounted) setState(() => _codeSentTo = email);
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    await submit(() => ref
        .read(sessionProvider.notifier)
        .resetPassword(_codeSentTo!, _code.text, _password.text));
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLanguageProvider);
    final sentTo = _codeSentTo;

    if (sentTo == null) {
      return AuthScaffold(
        showBack: true,
        title: lang.tr('auth.forgotPassword'),
        subtitle: lang.tr('auth.forgotSubtitle'),
        children: [
          Form(
            key: _formKey,
            child: EmailField(
              controller: _email,
              label: lang.tr('auth.email'),
              validator: validateEmail,
            ),
          ),
          AuthErrorText(error),
          AuthSubmitButton(
            label: lang.tr('auth.sendCode'),
            busy: busy,
            onPressed: _sendCode,
          ),
        ],
      );
    }

    return AuthScaffold(
      showBack: true,
      title: lang.tr('auth.resetTitle'),
      subtitle: lang.tr('auth.codeSent', args: {'email': sentTo}),
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CodeField(
                controller: _code,
                label: lang.tr('auth.code'),
                validator: validateCode,
              ),
              const SizedBox(height: 16),
              PasswordField(
                key: const Key('auth-password'),
                controller: _password,
                label: lang.tr('auth.newPassword'),
                toggleTooltip: lang.tr('auth.togglePassword'),
                validator: validatePassword,
                isNew: true,
              ),
              const SizedBox(height: 16),
              PasswordField(
                key: const Key('auth-confirm'),
                controller: _confirm,
                label: lang.tr('auth.confirmPassword'),
                toggleTooltip: lang.tr('auth.togglePassword'),
                validator: (v) => v == _password.text
                    ? null
                    : lang.tr('auth.err.passwordMismatch'),
                isNew: true,
                onSubmitted: _resetPassword,
              ),
            ],
          ),
        ),
        AuthErrorText(error),
        AuthSubmitButton(
          label: lang.tr('auth.resetSubmit'),
          busy: busy,
          onPressed: _resetPassword,
        ),
      ],
    );
  }
}
