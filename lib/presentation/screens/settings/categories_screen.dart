import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../widgets/app_card.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kategori Yönetimi')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Ön Tanımlı ve Özel Kategoriler',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),
          const Text(
            'Harcamalarınızı sınıflandırabileceğiniz aktif kategoriler:',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ...AppConstants.defaultCategories.map((cat) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cat.color.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(cat.icon, color: cat.color, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        cat.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 20),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
