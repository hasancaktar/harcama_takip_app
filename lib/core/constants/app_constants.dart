import 'package:flutter/material.dart';
import 'app_colors.dart';

class CategoryItem {
  final String id;
  final String name;
  final IconData icon;
  final Color color;

  const CategoryItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });
}

abstract class AppConstants {
  static const String appName = 'Harcama & Taksit Takip';
  static const String defaultCurrency = 'TRY';
  static const String currencySymbol = '₺';
  static const String defaultTimezone = 'Europe/Istanbul';
  static const String defaultLocale = 'tr_TR';

  // Ön Tanımlı Kategoriler (Madde 6)
  static const List<CategoryItem> defaultCategories = [
    CategoryItem(id: 'market', name: 'Market', icon: Icons.shopping_basket_rounded, color: AppColors.categoryMarket),
    CategoryItem(id: 'restaurant', name: 'Restoran / Kafe', icon: Icons.restaurant_rounded, color: AppColors.categoryRestaurant),
    CategoryItem(id: 'transportation', name: 'Ulaşım', icon: Icons.directions_subway_rounded, color: AppColors.categoryTransport),
    CategoryItem(id: 'bills', name: 'Fatura', icon: Icons.receipt_long_rounded, color: AppColors.categoryBills),
    CategoryItem(id: 'rent', name: 'Kira', icon: Icons.home_work_rounded, color: AppColors.categoryRent),
    CategoryItem(id: 'health', name: 'Sağlık', icon: Icons.medical_services_rounded, color: AppColors.categoryHealth),
    CategoryItem(id: 'education', name: 'Eğitim', icon: Icons.school_rounded, color: AppColors.categoryEducation),
    CategoryItem(id: 'shopping', name: 'Alışveriş', icon: Icons.shopping_bag_rounded, color: AppColors.categoryShopping),
    CategoryItem(id: 'entertainment', name: 'Eğlence', icon: Icons.movie_filter_rounded, color: AppColors.categoryEntertainment),
    CategoryItem(id: 'travel', name: 'Seyahat', icon: Icons.flight_takeoff_rounded, color: AppColors.categoryTravel),
    CategoryItem(id: 'subscription', name: 'Abonelik', icon: Icons.subscriptions_rounded, color: AppColors.categorySubscription),
    CategoryItem(id: 'home', name: 'Ev', icon: Icons.chair_rounded, color: AppColors.categoryHome),
    CategoryItem(id: 'personal_care', name: 'Kişisel Bakım', icon: Icons.spa_rounded, color: AppColors.categoryPersonalCare),
    CategoryItem(id: 'other', name: 'Diğer', icon: Icons.category_rounded, color: AppColors.categoryOther),
  ];

  static CategoryItem getCategoryById(String id) {
    return defaultCategories.firstWhere(
      (cat) => cat.id == id,
      orElse: () => const CategoryItem(
        id: 'other',
        name: 'Diğer',
        icon: Icons.category_rounded,
        color: AppColors.categoryOther,
      ),
    );
  }

  // Ödeme Yöntemleri (Madde 6)
  static const Map<String, String> paymentMethods = {
    'cash': 'Nakit',
    'debit_card': 'Banka Kartı',
    'credit_card': 'Kredi Kartı',
    'bank_transfer': 'Havale / EFT',
    'auto_payment': 'Otomatik Ödeme',
    'other': 'Diğer',
  };
}
