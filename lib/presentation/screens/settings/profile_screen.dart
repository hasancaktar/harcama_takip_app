import 'package:harcama_takip/core/l10n/app_locale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/auth_providers.dart';
import '../../../application/providers/repository_providers.dart';
import '../../../application/services/account_service.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../widgets/app_card.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/state_views.dart';
import '../auth/auth_scaffold.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameFormKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: ref.read(currentUserProvider)?.displayName ?? '',
  );
  bool _savingName = false;
  bool _deleting = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    FocusScope.of(context).unfocus();
    if (!_nameFormKey.currentState!.validate()) return;
    setState(() => _savingName = true);
    try {
      await ref
          .read(accountServiceProvider)
          .updateDisplayName(_nameController.text.trim());
      if (mounted) context.showSuccess('Adınız güncellendi.'.tr);
    } catch (e) {
      if (mounted) context.showError(e);
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  Future<void> _changePassword() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ChangePasswordSheet(),
    );
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Hesabınız kalıcı olarak silinsin mi?'.tr,
      message: 'Tüm harcamalarınız, kartlarınız, taksit planlarınız, kişisel bütçeleriniz ve profiliniz kalıcı olarak silinir. Sahibi olduğunuz takımlar kapatılır, üyesi olduğunuz takımlardan çıkarılırsınız. Bu işlem geri alınamaz.'
          .tr,
      confirmLabel: 'Devam et'.tr,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final password = await showPasswordPrompt(
      context,
      title: 'Şifrenizi doğrulayın'.tr,
      message: 'Hesabı silmek için mevcut şifrenizi girin.'.tr,
      confirmLabel: 'Hesabımı sil'.tr,
      destructive: true,
    );
    if (password == null || !mounted) return;

    setState(() => _deleting = true);
    try {
      await ref.read(accountServiceProvider).deleteAccount(password: password);
      // Oturum kapanınca router giriş ekranına yönlendirir.
    } catch (e) {
      if (mounted) {
        context.showError(e);
        setState(() => _deleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final scheme = context.colors;

    if (_deleting) {
      return Scaffold(
        body: LoadingView(message: 'Hesabınız ve verileriniz siliniyor…'.tr),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Profil ve güvenlik'.tr)),
      body: PageListView(
        maxWidth: AppSpacing.maxFormWidth,
        children: [
          Center(
            child: UserAvatar(
              name: user?.displayName ?? user?.email ?? '?',
              radius: 40,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            user?.email ?? '',
            textAlign: TextAlign.center,
            style: context.textStyles.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Center(
            child: Pill(
              icon: Icons.verified_rounded,
              label: 'E-posta doğrulandı'.tr,
              color: context.semantic.success,
            ),
          ),
          SectionHeader(title: 'Kişisel bilgiler'.tr),
          Form(
            key: _nameFormKey,
            child: TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              validator: Validators.displayName,
              decoration: InputDecoration(
                labelText: 'Ad soyad'.tr,
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            initialValue: user?.email ?? '',
            readOnly: true,
            enabled: false,
            decoration: InputDecoration(
              labelText: 'E-posta',
              prefixIcon: Icon(Icons.alternate_email_rounded),
              helperText: 'E-posta adresi değiştirilemez.'.tr,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Adı kaydet'.tr,
            onPressed: _saveName,
            isLoading: _savingName,
          ),
          SectionHeader(title: 'Güvenlik'.tr),
          AppCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.password_rounded),
              title: Text('Şifreyi değiştir'.tr),
              subtitle: Text('Mevcut şifrenizle doğrulama gerekir'.tr),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _changePassword,
            ),
          ),
          SectionHeader(title: 'Tehlikeli bölge'.tr),
          AppCard(
            borderColor: scheme.error.withValues(alpha: 0.4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Hesabı sil'.tr,
                  style: context.textStyles.titleSmall?.copyWith(
                    color: scheme.error,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Hesabınız ve size ait tüm veriler kalıcı olarak silinir.'.tr,
                  style: context.textStyles.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'Hesabımı kalıcı olarak sil'.tr,
                  destructive: true,
                  icon: Icons.delete_forever_rounded,
                  onPressed: _deleteAccount,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangePasswordSheet extends ConsumerStatefulWidget {
  const _ChangePasswordSheet();

  @override
  ConsumerState<_ChangePasswordSheet> createState() =>
      _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .changePassword(
            currentPassword: _current.text,
            newPassword: _next.text,
          );
      if (!mounted) return;
      Navigator.pop(context);
      context.showSuccess('Şifreniz güncellendi.'.tr);
    } catch (e) {
      if (mounted) setState(() => _error = ErrorMessages.from(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Şifreyi değiştir'.tr,
                  style: context.textStyles.titleLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                if (_error != null) ...[
                  InlineMessage(message: _error!, tone: MessageTone.error),
                  const SizedBox(height: AppSpacing.md),
                ],
                PasswordField(
                  controller: _current,
                  label: 'Mevcut şifre'.tr,
                  validator: Validators.loginPassword,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppSpacing.md),
                PasswordField(
                  controller: _next,
                  label: 'Yeni şifre'.tr,
                  validator: Validators.newPassword,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  helperText: 'En az 8 karakter; harf ve rakam içermeli'.tr,
                ),
                const SizedBox(height: AppSpacing.md),
                PasswordField(
                  controller: _confirm,
                  label: 'Yeni şifre (tekrar)'.tr,
                  validator: Validators.confirmPassword(() => _next.text),
                  autofillHints: const [AutofillHints.newPassword],
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Şifreyi güncelle'.tr,
                  onPressed: _submit,
                  isLoading: _saving,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
