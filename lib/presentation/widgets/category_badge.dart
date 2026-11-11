import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

class CategoryBadge extends StatelessWidget {
  final String categoryId;
  final bool showLabel;

  const CategoryBadge({
    super.key,
    required this.categoryId,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final category = AppConstants.getCategoryById(categoryId);

    if (!showLabel) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: category.color.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(category.icon, size: 20, color: category.color),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: category.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(category.icon, size: 16, color: category.color),
          const SizedBox(width: 6),
          Text(
            category.name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: category.color,
            ),
          ),
        ],
      ),
    );
  }
}
