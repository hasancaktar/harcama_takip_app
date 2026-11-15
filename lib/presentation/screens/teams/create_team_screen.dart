import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../application/providers/auth_providers.dart';
import '../../../application/providers/repository_providers.dart';
import '../../../application/providers/team_providers.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../domain/entities/team.dart';
import '../../../domain/entities/team_member.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';

class CreateTeamScreen extends ConsumerStatefulWidget {
  const CreateTeamScreen({super.key});

  @override
  ConsumerState<CreateTeamScreen> createState() => _CreateTeamScreenState();
}

class _CreateTeamScreenState extends ConsumerState<CreateTeamScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _colorHex = AppColors.pickerHexColors[1];
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() => _saving = true);
    final now = DateTime.now();
    final teamId = const Uuid().v4();
    try {
      await ref
          .read(teamRepositoryProvider)
          .createTeam(
            Team(
              id: teamId,
              name: _nameController.text.trim(),
              description: _descriptionController.text.trim().isEmpty
                  ? null
                  : _descriptionController.text.trim(),
              colorHex: _colorHex,
              ownerUid: user.uid,
              memberUids: [user.uid],
              createdAt: now,
              updatedAt: now,
            ),
            TeamMember(
              uid: user.uid,
              teamId: teamId,
              displayName: user.displayName,
              email: user.email.toLowerCase(),
              role: 'owner',
              joinedAt: now,
              invitedBy: user.uid,
            ),
          );
      await ref.read(workspaceControllerProvider).select(teamId);
      if (!mounted) return;
      context.showSuccess(
        'Takım oluşturuldu. Şimdi üyeleri davet edebilirsiniz.',
      );
      context.pushReplacement('/teams/$teamId');
    } catch (e) {
      if (mounted) {
        context.showError(e);
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yeni takım')),
      body: Form(
        key: _formKey,
        child: PageListView(
          maxWidth: AppSpacing.maxFormWidth,
          children: [
            TextFormField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              inputFormatters: [
                LengthLimitingTextInputFormatter(AppConstants.maxNameLength),
              ],
              validator: Validators.requiredText(
                'Takım adı',
                maxLength: AppConstants.maxNameLength,
              ),
              decoration: const InputDecoration(
                labelText: 'Takım adı',
                hintText: 'Örn. Evimiz, Aile bütçesi',
                prefixIcon: Icon(Icons.groups_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _descriptionController,
              maxLines: 2,
              inputFormatters: [LengthLimitingTextInputFormatter(200)],
              decoration: const InputDecoration(
                labelText: 'Açıklama (isteğe bağlı)',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Takım rengi', style: context.textStyles.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            ColorPickerRow(
              selectedHex: _colorHex,
              onSelected: (h) => setState(() => _colorHex = h),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Takımı oluştur',
              icon: Icons.check_rounded,
              onPressed: _create,
              isLoading: _saving,
            ),
          ],
        ),
      ),
    );
  }
}
