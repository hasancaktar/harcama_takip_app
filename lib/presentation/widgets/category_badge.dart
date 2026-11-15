import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

/// Kategori adıyla birlikte renkli etiket.
class CategoryBadge extends StatelessWidget {
  final String categoryId;

  const CategoryBadge({super.key, required this.categoryId});

  @override
  Widget build(BuildContext context) {
    final category = AppConstants.getCategoryById(categoryId);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: category.color.withValues(alpha: isDark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(category.icon, size: 16, color: category.color),
          const SizedBox(width: 6),
          Text(
            category.name,
            style: context.textStyles.labelLarge?.copyWith(
              color: isDark ? context.colors.onSurface : category.color,
            ),
          ),
        ],
      ),
    );
  }
}
