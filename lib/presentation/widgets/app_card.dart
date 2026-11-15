import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// Uygulamanın temel kart bileşeni. Dokunma efekti kart sınırları içinde kırpılır.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final Gradient? gradient;
  final double radius;
  final String? semanticLabel;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.onTap,
    this.color,
    this.borderColor,
    this.gradient,
    this.radius = AppSpacing.radiusLg,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: gradient != null
          ? BorderSide.none
          : BorderSide(color: borderColor ?? scheme.outlineVariant),
    );

    Widget content = Padding(padding: padding, child: child);
    if (onTap != null) {
      content = InkWell(onTap: onTap, customBorder: shape, child: content);
    }

    Widget card = Material(
      color: gradient != null
          ? Colors.transparent
          : (color ?? scheme.surfaceContainerLowest),
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: gradient != null
          ? Ink(
              decoration: BoxDecoration(gradient: gradient),
              child: content,
            )
          : content,
    );

    if (semanticLabel != null) {
      card = Semantics(
        label: semanticLabel,
        button: onTap != null,
        child: card,
      );
    }
    return card;
  }
}
