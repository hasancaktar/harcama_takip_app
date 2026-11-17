import 'package:harcama_takip/core/l10n/app_locale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/repository_providers.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../widgets/common.dart';
import '../../widgets/state_views.dart';
import 'auth_scaffold.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .signIn(
            email: _emailController.text,
            password: _passwordController.text,
          );
      // Yönlendirme, oturum durumu değişince router tarafından yapılır.
    } catch (e) {
      if (mounted) setState(() => _errorMessage = ErrorMessages.from(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return AuthScaffold(
      title: 'Tekrar hoş geldiniz'.tr,
      subtitle:
          'Harcama, kart ve taksitlerinizi takip etmek için giriş yapın.'.tr,
      children: [
        if (_errorMessage != null) ...[
          InlineMessage(message: _errorMessage!, tone: MessageTone.error),
          const SizedBox(height: AppSpacing.md),
        ],
        AutofillGroup(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [
                    AutofillHints.email,
                    AutofillHints.username,
                  ],
                  autocorrect: false,
                  validator: Validators.email,
                  decoration: InputDecoration(
                    labelText: 'E-posta'.tr,
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                PasswordField(
                  controller: _passwordController,
                  validator: Validators.loginPassword,
                  onSubmitted: (_) => _handleLogin(),
                ),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              final email = _emailController.text.trim();
              context.push(
                Uri(
                  path: '/forgot-password',
                  queryParameters: email.isEmpty ? null : {'email': email},
                ).toString(),
              );
            },
            child: Text('Şifremi unuttum'.tr),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        AppButton(
          label: 'Giriş yap'.tr,
          onPressed: _handleLogin,
          isLoading: _isLoading,
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Hesabınız yok mu?'.tr,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            TextButton(
              onPressed: () => context.push('/register'),
              child: Text('Hesap oluştur'.tr),
            ),
          ],
        ),
      ],
    );
  }
}
