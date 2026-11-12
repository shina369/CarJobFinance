// Login: the gate in front of the whole app.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_repository.dart';
import '../../../core/l10n/language_provider.dart';
import '../../../core/l10n/strings.dart';
import '../../controllers/session_controller.dart';
import 'auth_widgets.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> with AuthFormMixin {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    final session = ref.read(sessionProvider.notifier);
    final email = _email.text.trim();
    var needsConfirmation = false;

    await submit(() async {
      try {
        await session.signIn(email, _password.text);
      } on AuthFailure catch (e) {
        if (e.reason != AuthFailureReason.emailNotConfirmed) rethrow;
        // The account exists but its e-mail was never confirmed: send a
        // fresh code and let the driver finish that step.
        await session.resendSignUpCode(email);
        needsConfirmation = true;
      }
    });

    if (needsConfirmation && mounted) {
      context.push('/register', extra: email);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLanguageProvider);

    return AuthScaffold(
      title: lang.tr('auth.signIn'),
      subtitle: lang.tr('auth.loginSubtitle'),
      children: [
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                EmailField(
                  controller: _email,
                  label: lang.tr('auth.email'),
                  validator: validateEmail,
                ),
                const SizedBox(height: 16),
                PasswordField(
                  key: const Key('auth-password'),
                  controller: _password,
                  label: lang.tr('auth.password'),
                  toggleTooltip: lang.tr('auth.togglePassword'),
                  validator: (v) => (v ?? '').isEmpty
                      ? lang.tr('auth.err.invalidCredentials')
                      : null,
                  onSubmitted: _signIn,
                ),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            key: const Key('auth-forgot'),
            onPressed: busy ? null : () => context.push('/forgot-password'),
            child: Text(lang.tr('auth.forgotPassword')),
          ),
        ),
        AuthErrorText(error),
        AuthSubmitButton(
          label: lang.tr('auth.signIn'),
          busy: busy,
          onPressed: _signIn,
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          key: const Key('auth-create'),
          onPressed: busy ? null : () => context.push('/register'),
          style:
              OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: Text(lang.tr('auth.createAccount')),
        ),
      ],
    );
  }
}
