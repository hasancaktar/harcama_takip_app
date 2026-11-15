import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/auth_providers.dart';
import '../../../application/providers/repository_providers.dart';
import '../../../application/providers/team_providers.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/state_views.dart';

/// Davet koduyla takıma katılma. Davetler e-posta adresine bağlıdır; kod yalnızca
/// davet edilen e-posta adresiyle oturum açmış kullanıcı için geçerlidir.
class AcceptInviteScreen extends ConsumerStatefulWidget {
  final String? initialCode;
  const AcceptInviteScreen({super.key, this.initialCode});

  @override
  ConsumerState<AcceptInviteScreen> createState() => _AcceptInviteScreenState();
}

class _AcceptInviteScreenState extends ConsumerState<AcceptInviteScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _codeController = TextEditingController(
    text: widget.initialCode?.toUpperCase() ?? '',
  );
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final repo = ref.read(teamRepositoryProvider);
    final workspace = ref.read(workspaceControllerProvider);
    final invitesFuture = ref.read(myPendingInvitesProvider.future);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final invites = await invitesFuture;
      final code = _codeController.text.trim().toUpperCase();
      final matches = invites.where((i) => i.code == code);
      if (matches.isEmpty) {
        setState(
          () => _error =
              'Bu kodla e-posta adresinize (${user.email}) gönderilmiş geçerli bir davet bulunamadı. '
              'Kodu kontrol edin veya takım sahibinden sizi bu adresle davet etmesini isteyin.',
        );
        return;
      }
      final invite = matches.first;
      await repo.acceptInvite(invite: invite, user: user);
      await workspace.select(invite.teamId);
      if (!mounted) return;
      context.showSuccess('"${invite.teamName}" takımına katıldınız.');
      context.pushReplacement('/teams/${invite.teamId}');
    } catch (e) {
      if (mounted) setState(() => _error = ErrorMessages.from(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(currentUserProvider)?.email ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Takıma katıl')),
      body: PageListView(
        maxWidth: AppSpacing.maxFormWidth,
        children: [
          Text('Davet kodunu girin', style: context.textStyles.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Takım sahibinin sizinle paylaştığı 8 karakterlik kodu girin. Davet, $email adresine gönderilmiş olmalıdır.',
            style: context.textStyles.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_error != null) ...[
            InlineMessage(message: _error!, tone: MessageTone.error),
            const SizedBox(height: AppSpacing.md),
          ],
          Form(
            key: _formKey,
            child: TextFormField(
              controller: _codeController,
              autofocus: widget.initialCode == null,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                LengthLimitingTextInputFormatter(8),
                TextInputFormatter.withFunction(
                  (o, n) => n.copyWith(text: n.text.toUpperCase()),
                ),
              ],
              validator: Validators.inviteCode,
              onFieldSubmitted: (_) => _join(),
              style: context.textStyles.titleLarge?.copyWith(letterSpacing: 4),
              decoration: const InputDecoration(
                labelText: 'Davet kodu',
                hintText: 'ABCD2345',
                prefixIcon: Icon(Icons.vpn_key_outlined),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Takıma katıl',
            icon: Icons.login_rounded,
            onPressed: _join,
            isLoading: _busy,
          ),
        ],
      ),
    );
  }
}
