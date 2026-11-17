import 'package:harcama_takip/core/l10n/app_locale.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/color_utils.dart';
import '../../domain/entities/app_user.dart';

/// Geniş ekranlarda içeriği ortalayıp genişliğini sınırlar.
class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = AppSpacing.maxContentWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Ortalanmış, genişliği sınırlı kaydırılabilir sayfa gövdesi.
class PageListView extends StatelessWidget {
  final List<Widget> children;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final ScrollPhysics? physics;

  const PageListView({
    super.key,
    required this.children,
    this.maxWidth = AppSpacing.maxContentWidth,
    this.padding = AppSpacing.screenPadding,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: physics,
      padding: padding,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}

/// Bölüm başlığı ve isteğe bağlı sağ eylem.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.only(
      top: AppSpacing.lg,
      bottom: AppSpacing.xs,
    ),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: context.textStyles.titleMedium),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

/// Yükleniyor durumunu destekleyen ana buton.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool expand;
  final bool outlined;
  final bool destructive;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.expand = true,
    this.outlined = false,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final effectiveOnPressed = isLoading ? null : onPressed;

    final bg = destructive ? scheme.error : scheme.primary;
    final fg = destructive ? scheme.onError : scheme.onPrimary;
    final outlineColor = destructive ? scheme.error : scheme.primary;

    final child = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(
                outlined ? outlineColor : fg,
              ),
              semanticsLabel: 'İşleniyor'.tr,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: AppSpacing.xs),
              ],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );

    Widget button;
    if (outlined) {
      final baseStyle = OutlinedButton.styleFrom(
        foregroundColor: outlineColor,
        side: BorderSide(
          color: destructive
              ? scheme.error.withValues(alpha: 0.6)
              : scheme.outline,
        ),
      );

      final loadingStyle = OutlinedButton.styleFrom(
        disabledForegroundColor: outlineColor,
        side: BorderSide(
          color: outlineColor.withValues(alpha: 0.8),
          width: 1.5,
        ),
      );

      button = OutlinedButton(
        onPressed: effectiveOnPressed,
        style: isLoading ? loadingStyle : (destructive ? baseStyle : null),
        child: child,
      );
    } else {
      final baseStyle = destructive
          ? FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            )
          : null;

      final loadingStyle = FilledButton.styleFrom(
        disabledBackgroundColor: bg,
        disabledForegroundColor: fg,
      );

      button = FilledButton(
        onPressed: effectiveOnPressed,
        style: isLoading ? loadingStyle : baseStyle,
        child: child,
      );
    }
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Kullanıcı / üye avatarı (baş harfler).
class UserAvatar extends StatelessWidget {
  final String name;
  final double radius;
  final Color? color;

  const UserAvatar({
    super.key,
    required this.name,
    this.radius = 20,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final bg = color ?? scheme.primaryContainer;
    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      child: Text(
        AppUser.initialsOf(name),
        style: TextStyle(
          color: color != null
              ? ColorUtils.onColor(bg)
              : scheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.75,
        ),
      ),
    );
  }
}

/// Renk seçici (kart ve takım renkleri için). Erişilebilirlik etiketli.
class ColorPickerRow extends StatelessWidget {
  final String selectedHex;
  final ValueChanged<String> onSelected;
  final List<String> colors;

  const ColorPickerRow({
    super.key,
    required this.selectedHex,
    required this.onSelected,
    this.colors = AppColors.pickerHexColors,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (var i = 0; i < colors.length; i++)
          Semantics(
            label: 'Renk {0}'.trArgs([i + 1]),
            selected: colors[i] == selectedHex,
            button: true,
            child: InkResponse(
              onTap: () => onSelected(colors[i]),
              radius: 26,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: ColorUtils.fromHex(colors[i]),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors[i] == selectedHex
                        ? scheme.onSurface
                        : Colors.transparent,
                    width: 3,
                  ),
                ),
                child: colors[i] == selectedHex
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 22,
                      )
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}

/// Kategori simgesi rozeti.
class CategoryIcon extends StatelessWidget {
  final String categoryId;
  final double size;

  const CategoryIcon({super.key, required this.categoryId, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final category = AppConstants.getCategoryById(categoryId);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      label: category.name,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: category.color.withValues(alpha: isDark ? 0.22 : 0.14),
          borderRadius: BorderRadius.circular(size * 0.32),
        ),
        child: Icon(category.icon, size: size * 0.5, color: category.color),
      ),
    );
  }
}

/// Küçük durum etiketi (ör. "Takım", "3/6 taksit").
class Pill extends StatelessWidget {
  final String label;
  final Color? color;
  final IconData? icon;

  const Pill({super.key, required this.label, this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final fg = color ?? scheme.onSurfaceVariant;
    return Container(
      // Sınırsız genişlik verilen satırlarda da ekranın yarısını aşmaz.
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.5,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (color ?? scheme.onSurfaceVariant).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 3),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: context.textStyles.labelSmall?.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bütçe / limit kullanımı için renkli ilerleme çubuğu.
class UsageBar extends StatelessWidget {
  final double ratio;
  final Color? color;
  final double height;
  final String? semanticsLabel;

  const UsageBar({
    super.key,
    required this.ratio,
    this.color,
    this.height = 8,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final semantic = context.semantic;
    final effective =
        color ??
        (ratio > 1
            ? scheme.error
            : ratio >= 0.9
            ? semantic.warning
            : scheme.primary);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: ratio.clamp(0.0, 1.0),
        minHeight: height,
        color: effective,
        backgroundColor: scheme.surfaceContainerHigh,
        semanticsLabel: semanticsLabel,
      ),
    );
  }
}
