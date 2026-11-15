import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/services/account_service.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../widgets/common.dart';
import '../../widgets/state_views.dart';
import 'auth_scaffold.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _acceptedPolicy = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedPolicy) {
      setState(
        () =>
            _errorMessage = 'Devam etmek için gizlilik politikasını onaylayın.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(accountServiceProvider)
          .register(
            email: _emailController.text,
            password: _passwordController.text,
            displayName: _nameController.text,
          );
      // Router, doğrulanmamış kullanıcıyı otomatik olarak doğrulama ekranına yönlendirir.
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
      showBack: true,
      title: 'Hesap oluşturun',
      subtitle: 'Kayıttan sonra e-posta adresinize bir doğrulama bağlantısı göndereceğiz.',
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
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  validator: Validators.displayName,
                  decoration: const InputDecoration(
                    labelText: 'Ad soyad',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  autocorrect: false,
                  validator: Validators.email,
                  decoration: const InputDecoration(
                    labelText: 'E-posta',
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                PasswordField(
                  controller: _passwordController,
                  validator: Validators.newPassword,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  helperText: 'En az 8 karakter; harf ve rakam içermeli',
                ),
                const SizedBox(height: AppSpacing.md),
                PasswordField(
                  controller: _confirmController,
                  label: 'Şifre (tekrar)',
                  validator: Validators.confirmPassword(
                    () => _passwordController.text,
                  ),
                  autofillHints: const [AutofillHints.newPassword],
                  onSubmitted: (_) => _handleRegister(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        CheckboxListTile(
          value: _acceptedPolicy,
          onChanged: (v) => setState(() => _acceptedPolicy = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Verilerimin gizlilik politikasında açıklandığı şekilde işlenmesini kabul ediyorum.',
            style: context.textStyles.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: 'Hesap oluştur',
          onPressed: _handleRegister,
          isLoading: _isLoading,
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Zaten hesabınız var mı?',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            TextButton(
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/login'),
              child: const Text('Giriş yap'),
            ),
          ],
        ),
      ],
    );
  }
}
