import 'package:flutter/material.dart';

import 'app_colors.dart';

@immutable
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

@immutable
class PaymentMethodItem {
  final String id;
  final String name;
  final IconData icon;

  const PaymentMethodItem({
    required this.id,
    required this.name,
    required this.icon,
  });
}

abstract class AppConstants {
  static const String appName = 'Harcama Takip';
  static const String appTagline = 'Harcama, kart ve taksitleriniz tek yerde';
  static const String defaultCurrency = 'TRY';
  static const String currencySymbol = '₺';
  static const String defaultTimezone = 'Europe/Istanbul';
  static const String defaultLocale = 'tr_TR';
  static const String privacyPolicyUrl =
      'https://harcama-takip-app-7ff66.web.app/privacy-policy.html';

  // Alan sınırları (Firestore güvenlik kuralları ile birebir aynıdır)
  static const int maxTitleLength = 100;
  static const int maxNotesLength = 500;
  static const int maxNameLength = 60;
  static const int minInstallments = 2;
  static const int maxInstallments = 36;

  static const CategoryItem otherCategory = CategoryItem(
    id: 'other',
    name: 'Diğer',
    icon: Icons.category_rounded,
    color: AppColors.categoryOther,
  );

  static const List<CategoryItem> defaultCategories = [
    CategoryItem(
      id: 'market',
      name: 'Market',
      icon: Icons.shopping_basket_rounded,
      color: AppColors.categoryMarket,
    ),
    CategoryItem(
      id: 'restaurant',
      name: 'Restoran / Kafe',
      icon: Icons.restaurant_rounded,
      color: AppColors.categoryRestaurant,
    ),
    CategoryItem(
      id: 'transportation',
      name: 'Ulaşım',
      icon: Icons.directions_subway_rounded,
      color: AppColors.categoryTransport,
    ),
    CategoryItem(
      id: 'bills',
      name: 'Fatura',
      icon: Icons.receipt_long_rounded,
      color: AppColors.categoryBills,
    ),
    CategoryItem(
      id: 'rent',
      name: 'Kira',
      icon: Icons.home_work_rounded,
      color: AppColors.categoryRent,
    ),
    CategoryItem(
      id: 'health',
      name: 'Sağlık',
      icon: Icons.medical_services_rounded,
      color: AppColors.categoryHealth,
    ),
    CategoryItem(
      id: 'education',
      name: 'Eğitim',
      icon: Icons.school_rounded,
      color: AppColors.categoryEducation,
    ),
    CategoryItem(
      id: 'shopping',
      name: 'Alışveriş',
      icon: Icons.shopping_bag_rounded,
      color: AppColors.categoryShopping,
    ),
    CategoryItem(
      id: 'entertainment',
      name: 'Eğlence',
      icon: Icons.movie_filter_rounded,
      color: AppColors.categoryEntertainment,
    ),
    CategoryItem(
      id: 'travel',
      name: 'Seyahat',
      icon: Icons.flight_takeoff_rounded,
      color: AppColors.categoryTravel,
    ),
    CategoryItem(
      id: 'subscription',
      name: 'Abonelik',
      icon: Icons.subscriptions_rounded,
      color: AppColors.categorySubscription,
    ),
    CategoryItem(
      id: 'home',
      name: 'Ev',
      icon: Icons.chair_rounded,
      color: AppColors.categoryHome,
    ),
    CategoryItem(
      id: 'personal_care',
      name: 'Kişisel Bakım',
      icon: Icons.spa_rounded,
      color: AppColors.categoryPersonalCare,
    ),
    CategoryItem(
      id: 'donation',
      name: 'Bağış',
      icon: Icons.volunteer_activism_rounded,
      color: AppColors.categoryDonation,
    ),
    otherCategory,
  ];

  static CategoryItem getCategoryById(String id) {
    for (final cat in defaultCategories) {
      if (cat.id == id) return cat;
    }
    return otherCategory;
  }

  static const List<PaymentMethodItem> paymentMethodItems = [
    PaymentMethodItem(
      id: 'credit_card',
      name: 'Kredi Kartı',
      icon: Icons.credit_card_rounded,
    ),
    PaymentMethodItem(id: 'cash', name: 'Nakit', icon: Icons.payments_rounded),
    PaymentMethodItem(
      id: 'debit_card',
      name: 'Banka Kartı',
      icon: Icons.account_balance_wallet_rounded,
    ),
    PaymentMethodItem(
      id: 'bank_transfer',
      name: 'Havale / EFT',
      icon: Icons.swap_horiz_rounded,
    ),
    PaymentMethodItem(
      id: 'auto_payment',
      name: 'Otomatik Ödeme',
      icon: Icons.autorenew_rounded,
    ),
    PaymentMethodItem(
      id: 'other',
      name: 'Diğer',
      icon: Icons.more_horiz_rounded,
    ),
  ];

  static final Map<String, String> paymentMethods = {
    for (final m in paymentMethodItems) m.id: m.name,
  };

  static PaymentMethodItem getPaymentMethod(String id) {
    for (final m in paymentMethodItems) {
      if (m.id == id) return m;
    }
    return paymentMethodItems.last;
  }

  static const Map<String, String> teamRoles = {
    'owner': 'Sahip',
    'admin': 'Yönetici',
    'member': 'Üye',
  };
}
