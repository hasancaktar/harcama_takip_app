import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/auth_providers.dart';
import '../../../application/providers/repository_providers.dart';
import '../../../application/services/account_service.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/state_views.dart';
import 'auth_scaffold.dart';

/// E-posta doğrulaması tamamlanmamış kullanıcılar yalnızca bu ekranı görebilir.
///
/// - Doğrulama durumu birkaç saniyede bir arka planda kontrol edilir.
/// - "Doğruladım" düğmesi anında kontrol eder.
/// - Doğrulama e-postası 60 saniyelik bekleme süresiyle yeniden gönderilebilir.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen>
    with WidgetsBindingObserver {
  static const _resendCooldown = 60;
  static const _pollInterval = Duration(seconds: 5);

  Timer? _pollTimer;
  Timer? _cooldownTimer;
  int _cooldownLeft = 0;
  bool _checking = false;
  bool _resending = false;
  String? _message;
  MessageTone _tone = MessageTone.info;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pollTimer = Timer.periodic(_pollInterval, (_) => _check(silent: true));
    _startCooldown(); // Kayıt sırasında e-posta zaten gönderildi.
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Kullanıcı e-posta uygulamasından döndüğünde hemen kontrol et.
    if (state == AppLifecycleState.resumed) _check(silent: true);
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownLeft = _resendCooldown);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _cooldownLeft--);
      if (_cooldownLeft <= 0) timer.cancel();
    });
  }

  Future<void> _check({bool silent = false}) async {
    if (_checking) return;
    if (!silent) setState(() => _checking = true);
    try {
      final user = await ref.read(authRepositoryProvider).reloadUser();
      if (!mounted) return;
      if (user != null && !user.emailVerified && !silent) {
        setState(() {
          _tone = MessageTone.warning;
          _message = 'E-posta adresiniz henüz doğrulanmamış görünüyor. Bağlantıya tıkladıktan sonra tekrar deneyin.';
        });
      }
      // Doğrulandıysa router otomatik olarak ana sayfaya yönlendirir.
    } catch (e) {
      if (mounted && !silent) {
        setState(() {
          _tone = MessageTone.error;
          _message = ErrorMessages.from(e);
        });
      }
    } finally {
      if (mounted && !silent) setState(() => _checking = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      await ref.read(authRepositoryProvider).sendEmailVerification();
      if (!mounted) return;
      _startCooldown();
      setState(() {
        _tone = MessageTone.success;
        _message = 'Doğrulama e-postası yeniden gönderildi.';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _tone = MessageTone.error;
          _message = ErrorMessages.from(e);
        });
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final scheme = context.colors;

    return AuthScaffold(
      title: 'E-postanızı doğrulayın',
      subtitle:
          'Hesabınızı korumak için e-posta adresinizi doğrulamanız gerekiyor.',
      header: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.mark_email_unread_outlined,
          size: 40,
          color: scheme.onPrimaryContainer,
        ),
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Column(
            children: [
              Text(
                'Doğrulama bağlantısı gönderildi:',
                style: context.textStyles.bodyMedium,
              ),
              const SizedBox(height: 4),
              SelectableText(
                user?.email ?? '',
                textAlign: TextAlign.center,
                style: context.textStyles.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'E-postadaki bağlantıya tıklayın, ardından bu ekrana dönün. Birkaç dakika içinde gelmezse istenmeyen (spam) klasörünü kontrol edin.',
                textAlign: TextAlign.center,
                style: context.textStyles.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (_message != null) ...[
          const SizedBox(height: AppSpacing.md),
          InlineMessage(message: _message!, tone: _tone),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'E-postamı doğruladım',
          icon: Icons.verified_outlined,
          onPressed: () => _check(),
          isLoading: _checking,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: _cooldownLeft > 0
              ? 'Tekrar gönder ($_cooldownLeft sn)'
              : 'Doğrulama e-postasını tekrar gönder',
          outlined: true,
          icon: Icons.refresh_rounded,
          isLoading: _resending,
          onPressed: _cooldownLeft > 0 ? null : _resend,
        ),
        const SizedBox(height: AppSpacing.md),
        TextButton.icon(
          onPressed: () => ref.read(accountServiceProvider).signOut(),
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Farklı bir hesapla giriş yap'),
        ),
      ],
    );
  }
}
