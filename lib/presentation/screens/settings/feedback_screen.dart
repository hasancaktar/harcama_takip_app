import 'package:harcama_takip/core/l10n/app_locale.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/providers/auth_providers.dart';
import '../../../application/providers/repository_providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/admin_models.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/state_views.dart';

/// Kullanıcının uygulama içinden öneri / geri bildirim gönderdiği ekran.
/// Gönderilenler yönetim panelindeki "Öneriler" bölümünde görünür.
class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static String get _platform =>
      kIsWeb ? 'web' : defaultTargetPlatform.name.toLowerCase();

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final repo = ref.read(appContentRepositoryProvider);
    setState(() => _sending = true);
    try {
      await repo.sendFeedback(
        user: user,
        message: _controller.text.trim(),
        appVersion: AppConstants.appVersion,
        platform: _platform,
      );
      if (!mounted) return;
      context.showSuccess('Öneriniz gönderildi. Teşekkür ederiz!'.tr);
      context.pop();
    } catch (e) {
      if (mounted) {
        context.showError(e);
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Öneri gönder'.tr)),
      body: Form(
        key: _formKey,
        child: PageListView(
          maxWidth: AppSpacing.maxFormWidth,
          children: [
            InlineMessage(
              tone: MessageTone.info,
              message: 'Hata, eksik veya yeni özellik önerilerinizi yazın. Mesajınız uygulama sürümüyle birlikte geliştiriciye iletilir.'
                  .tr,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _controller,
              autofocus: true,
              minLines: 6,
              maxLines: 12,
              maxLength: FeedbackEntry.maxLength,
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: [
                LengthLimitingTextInputFormatter(FeedbackEntry.maxLength),
              ],
              validator: (v) => (v == null || v.trim().length < 3)
                  ? 'Lütfen önerinizi yazın.'.tr
                  : null,
              decoration: InputDecoration(
                labelText: 'Öneriniz'.tr,
                hintText: 'Örn. Raporlarda yıllık görünüm olsun'.tr,
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Gönder'.tr,
              icon: Icons.send_rounded,
              onPressed: _send,
              isLoading: _sending,
            ),
          ],
        ),
      ),
    );
  }
}
