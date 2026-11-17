import 'package:harcama_takip/core/l10n/app_locale.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/common.dart';

/// Harcama kategorileri. Kategori limitleri Bütçe ekranından yönetilir.
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Kategoriler'.tr)),
      body: PageListView(
        children: [
          Text(
            'Harcamalarınızı aşağıdaki kategorilerle sınıflandırabilirsiniz. Kategori bazlı limitleri Bütçe ekranından belirleyebilirsiniz.'
                .tr,
            style: context.textStyles.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
            child: Column(
              children: [
                for (final c in AppConstants.categories)
                  ListTile(
                    leading: CategoryIcon(categoryId: c.id, size: 36),
                    title: Text(c.name),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
