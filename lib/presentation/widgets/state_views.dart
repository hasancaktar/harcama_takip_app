import 'package:harcama_takip/core/l10n/app_locale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/error_messages.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';

/// Boş durum: ikon, başlık, açıklama ve isteğe bağlı eylem.
class EmptyStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final bool compact;

  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(compact ? AppSpacing.md : AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(compact ? AppSpacing.md : 20),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: compact ? 28 : 40,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                style: context.textStyles.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                message,
                style: context.textStyles.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: Icon(actionIcon ?? Icons.add_rounded),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Hata durumu: kullanıcı dostu mesaj ve "Tekrar dene".
class ErrorStateView extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;
  final bool compact;

  const ErrorStateView({
    super.key,
    required this.error,
    this.onRetry,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? AppSpacing.md : AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: compact ? 32 : 44,
                color: scheme.error,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Veriler yüklenemedi'.tr,
                style: context.textStyles.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                ErrorMessages.from(error),
                style: context.textStyles.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text('Tekrar dene'.tr),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Merkezde yükleniyor göstergesi.
class LoadingView extends StatelessWidget {
  final String? message;
  const LoadingView({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(message!, style: context.textStyles.bodyMedium),
          ],
        ],
      ),
    );
  }
}

/// Liste yüklenirken gösterilen iskelet satırlar (algılanan performansı artırır).
class SkeletonList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  final EdgeInsetsGeometry padding;

  const SkeletonList({
    super.key,
    this.itemCount = 6,
    this.itemHeight = 64,
    this.padding = const EdgeInsets.all(AppSpacing.md),
  });

  @override
  Widget build(BuildContext context) {
    final color = context.colors.surfaceContainerHigh;
    return Semantics(
      label: 'Yükleniyor'.tr,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppSpacing.maxContentWidth,
          ),
          child: ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            padding: padding,
            itemCount: itemCount,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, i) => Container(
              height: itemHeight,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 1 - i * 0.12),
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// [AsyncValue] için standart yükleniyor/hata/veri gösterimi.
class AsyncValueView<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final Widget? loading;
  final VoidCallback? onRetry;

  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    this.loading,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnReload: false,
      skipLoadingOnRefresh: true,
      data: data,
      loading: () => loading ?? const LoadingView(),
      error: (e, _) => ErrorStateView(error: e, onRetry: onRetry),
    );
  }
}

enum MessageTone { info, success, warning, error }

/// Form üstü bilgi / hata / başarı bandı.
class InlineMessage extends StatelessWidget {
  final String message;
  final MessageTone tone;
  final String? title;
  final Widget? action;

  const InlineMessage({
    super.key,
    required this.message,
    this.tone = MessageTone.info,
    this.title,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final semantic = context.semantic;
    final (Color bg, Color fg, IconData icon) = switch (tone) {
      MessageTone.info => (
        semantic.infoContainer,
        semantic.info,
        Icons.info_outline_rounded,
      ),
      MessageTone.success => (
        semantic.successContainer,
        semantic.success,
        Icons.check_circle_outline_rounded,
      ),
      MessageTone.warning => (
        semantic.warningContainer,
        semantic.warning,
        Icons.warning_amber_rounded,
      ),
      MessageTone.error => (
        scheme.errorContainer,
        scheme.onErrorContainer,
        Icons.error_outline_rounded,
      ),
    };
    return Semantics(
      liveRegion: tone == MessageTone.error,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm + 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: fg, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        title!,
                        style: context.textStyles.titleSmall?.copyWith(
                          color: fg,
                        ),
                      ),
                    ),
                  Text(
                    message,
                    style: context.textStyles.bodyMedium?.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                  if (action != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    action!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
