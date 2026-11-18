import 'package:harcama_takip/core/l10n/app_locale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/auth_providers.dart';
import '../../../application/providers/repository_providers.dart';
import '../../../application/providers/settings_providers.dart';
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
  void initState() {
    super.initState();
    final savedEmail = ref
        .read(sharedPreferencesProvider)
        ?.getString('last_login_email');
    if (savedEmail != null && savedEmail.isNotEmpty) {
      _emailController.text = savedEmail;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_emailController.text.isEmpty) {
        final postSaved = ref
            .read(sharedPreferencesProvider)
            ?.getString('last_login_email');
        if (postSaved != null && postSaved.isNotEmpty) {
          setState(() {
            _emailController.text = postSaved;
          });
        }
      }
    });
  }

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
      final email = _emailController.text.trim();
      final auth = ref.read(authRepositoryProvider);
      final users = ref.read(userRepositoryProvider);
      final disabledNotice = ref.read(accountDisabledNoticeProvider.notifier);
      disabledNotice.state = false;
      await auth.signIn(email: email, password: _passwordController.text);
      // Pasife alınmış hesap: oturumu hemen kapat ve nedenini göster.
      final uid = auth.currentUser?.uid;
      final profile = uid == null ? null : await users.getProfile(uid);
      if (profile?.disabled == true) {
        disabledNotice.state = true;
        await auth.signOut();
        if (mounted) {
          setState(() => _errorMessage = ErrorMessages.accountDisabled);
        }
        return;
      }
      await ref
          .read(sharedPreferencesProvider)
          ?.setString('last_login_email', email);
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
    final disabledNotice = ref.watch(accountDisabledNoticeProvider);
    final error =
        _errorMessage ??
        (disabledNotice ? ErrorMessages.accountDisabled : null);
    return AuthScaffold(
      title: 'Tekrar hoş geldiniz'.tr,
      subtitle:
          'Harcama, kart ve taksitlerinizi takip etmek için giriş yapın.'.tr,
      children: [
        if (error != null) ...[
          InlineMessage(message: error, tone: MessageTone.error),
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
