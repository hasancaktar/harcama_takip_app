import 'package:harcama_takip/core/l10n/app_locale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/repository_providers.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../widgets/common.dart';
import '../../widgets/state_views.dart';
import 'auth_scaffold.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  final String? initialEmail;

  const ForgotPasswordScreen({super.key, this.initialEmail});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _emailController = TextEditingController(
    text: widget.initialEmail ?? '',
  );
  bool _isLoading = false;
  bool _sent = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .sendPasswordResetEmail(_emailController.text);
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = ErrorMessages.from(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBack: true,
      title: 'Şifrenizi sıfırlayın'.tr,
      subtitle: 'Kayıtlı e-posta adresinizi girin; size bir sıfırlama bağlantısı gönderelim.'
          .tr,
      children: [
        if (_sent) ...[
          // Hesap varlığını ifşa etmemek için her durumda aynı mesaj gösterilir.
          InlineMessage(
            tone: MessageTone.success,
            title: 'E-postanızı kontrol edin'.tr,
            message: 'Bu adrese kayıtlı bir hesap varsa şifre sıfırlama bağlantısı gönderildi. Gelen kutunuzu ve istenmeyen klasörünü kontrol edin.'
                .tr,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Giriş ekranına dön'.tr,
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/login'),
          ),
        ] else ...[
          if (_errorMessage != null) ...[
            InlineMessage(message: _errorMessage!, tone: MessageTone.error),
            const SizedBox(height: AppSpacing.md),
          ],
          Form(
            key: _formKey,
            child: TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              autocorrect: false,
              validator: Validators.email,
              onFieldSubmitted: (_) => _handleReset(),
              decoration: InputDecoration(
                labelText: 'E-posta'.tr,
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Sıfırlama bağlantısı gönder'.tr,
            onPressed: _handleReset,
            isLoading: _isLoading,
          ),
        ],
      ],
    );
  }
}
