import 'package:flutter/material.dart';

import '../l10n/app_locale.dart';
import '../utils/color_utils.dart';
import '../utils/json_parsers.dart';

/// Kategori simgeleri. Firestore'da simgenin anahtarı saklanır; `IconData`
/// sabitleri burada tutulduğu için derlemede simge ağacı budanabilir.
abstract class CategoryIcons {
  static const String fallbackKey = 'category';

  static const Map<String, IconData> all = {
    'shopping_basket': Icons.shopping_basket_rounded,
    'restaurant': Icons.restaurant_rounded,
    'subway': Icons.directions_subway_rounded,
    'receipt': Icons.receipt_long_rounded,
    'home_work': Icons.home_work_rounded,
    'medical': Icons.medical_services_rounded,
    'school': Icons.school_rounded,
    'shopping_bag': Icons.shopping_bag_rounded,
    'movie': Icons.movie_filter_rounded,
    'flight': Icons.flight_takeoff_rounded,
    'subscriptions': Icons.subscriptions_rounded,
    'chair': Icons.chair_rounded,
    'spa': Icons.spa_rounded,
    'volunteer': Icons.volunteer_activism_rounded,
    'category': Icons.category_rounded,
    'car': Icons.directions_car_rounded,
    'fuel': Icons.local_gas_station_rounded,
    'pets': Icons.pets_rounded,
    'child': Icons.child_care_rounded,
    'fitness': Icons.fitness_center_rounded,
    'gift': Icons.card_giftcard_rounded,
    'coffee': Icons.local_cafe_rounded,
    'phone': Icons.smartphone_rounded,
    'wifi': Icons.wifi_rounded,
    'bolt': Icons.bolt_rounded,
    'water': Icons.water_drop_rounded,
    'book': Icons.menu_book_rounded,
    'music': Icons.music_note_rounded,
    'sports': Icons.sports_soccer_rounded,
    'clothes': Icons.checkroom_rounded,
    'tools': Icons.build_rounded,
    'savings': Icons.account_balance_wallet_rounded,
    'bank': Icons.account_balance_rounded,
    'work': Icons.work_rounded,
    'tax': Icons.gavel_rounded,
    'insurance': Icons.shield_rounded,
    'taxi': Icons.local_taxi_rounded,
    'hotel': Icons.hotel_rounded,
    'beach': Icons.beach_access_rounded,
    'pharmacy': Icons.local_pharmacy_rounded,
  };

  static IconData of(String key) => all[key] ?? Icons.category_rounded;
}

@immutable
class CategoryItem {
  final String id;
  final String nameTr;
  final String nameEn;
  final String iconKey;
  final String colorHex;
  final bool isActive;
  final bool isDeleted;
  final int order;

  const CategoryItem({
    required this.id,
    required this.nameTr,
    this.nameEn = '',
    this.iconKey = CategoryIcons.fallbackKey,
    this.colorHex = '#6B7280',
    this.isActive = true,
    this.isDeleted = false,
    this.order = 0,
  });

  /// Etkin dildeki ad (İngilizce ad boşsa Türkçe ad).
  String get name => AppLocale.isTurkish || nameEn.isEmpty ? nameTr : nameEn;
  IconData get icon => CategoryIcons.of(iconKey);
  Color get color =>
      ColorUtils.fromHex(colorHex, fallback: const Color(0xFF6B7280));

  /// Harcama girişinde seçilebilir mi?
  bool get isSelectable => isActive && !isDeleted;

  CategoryItem copyWith({
    String? nameTr,
    String? nameEn,
    String? iconKey,
    String? colorHex,
    bool? isActive,
    bool? isDeleted,
    int? order,
  }) {
    return CategoryItem(
      id: id,
      nameTr: nameTr ?? this.nameTr,
      nameEn: nameEn ?? this.nameEn,
      iconKey: iconKey ?? this.iconKey,
      colorHex: colorHex ?? this.colorHex,
      isActive: isActive ?? this.isActive,
      isDeleted: isDeleted ?? this.isDeleted,
      order: order ?? this.order,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'nameTr': nameTr,
    'nameEn': nameEn,
    'iconKey': iconKey,
    'colorHex': colorHex,
    'isActive': isActive,
    'isDeleted': isDeleted,
    'order': order,
  };

  factory CategoryItem.fromMap(Map<String, dynamic> map) {
    return CategoryItem(
      id: JsonParsers.string(map['id']),
      nameTr: JsonParsers.string(map['nameTr']),
      nameEn: JsonParsers.string(map['nameEn']),
      iconKey: JsonParsers.string(
        map['iconKey'],
        fallback: CategoryIcons.fallbackKey,
      ),
      colorHex: JsonParsers.string(map['colorHex'], fallback: '#6B7280'),
      isActive: JsonParsers.boolValue(map['isActive'], fallback: true),
      isDeleted: JsonParsers.boolValue(map['isDeleted']),
      order: JsonParsers.intValue(map['order']),
    );
  }
}

/// Uygulamanın o an geçerli kategori listesi.
///
/// Yönetici Firestore'da kategori tanımlamadıysa yerleşik varsayılanlar kullanılır.
/// Silinen (arşivlenen) veya pasif kategoriler seçicilerde görünmez ama geçmiş
/// harcamaların adı/simgesi çözülebilsin diye kayıt defterinde kalır.
abstract class CategoryRegistry {
  static List<CategoryItem> _all = AppConstants.defaultCategories;

  static List<CategoryItem> get all => _all;
  static List<CategoryItem> get selectable =>
      _all.where((c) => c.isSelectable).toList();

  static void update(List<CategoryItem> remote) {
    if (remote.isEmpty) {
      _all = AppConstants.defaultCategories;
      return;
    }
    // Yöneticinin listesinde olmayan sistem kategorileri eklenir; yönetici bunları
    // kendi listesinde pasif yaparak gizleyebilir.
    final ids = {for (final c in remote) c.id};
    _all = [
      ...remote,
      for (final c in AppConstants.defaultCategories)
        if (AppConstants.systemCategoryIds.contains(c.id) &&
            !ids.contains(c.id))
          c,
    ]..sort((a, b) => a.order.compareTo(b.order));
  }

  static CategoryItem byId(String id) {
    for (final c in _all) {
      if (c.id == id) return c;
    }
    for (final c in AppConstants.defaultCategories) {
      if (c.id == id) return c;
    }
    return AppConstants.otherCategory;
  }
}

@immutable
class PaymentMethodItem {
  final String id;
  final String _name;
  final IconData icon;

  const PaymentMethodItem({
    required this.id,
    required this._name,
    required this.icon,
  });

  String get name => _name.tr;
}

abstract class AppConstants {
  static const String appName = 'Harcama Takip';

  /// Uygulama sürümü. pubspec.yaml'daki `version` ile aynı olmalıdır
  /// (test/unit/app_version_test.dart denetler). "Yenilikler" penceresi bu
  /// sürüme göre gösterilir.
  static const String appVersion = '1.3.0';
  static const int appBuildNumber = 6;
  static String get appVersionLabel => '$appVersion ($appBuildNumber)';

  /// Kullanıcıların ulaşabileceği iletişim adresi (mağaza girişiyle aynı).
  static const String contactEmail = 'faydalab3@gmail.com';
  static const String defaultCurrency = 'TRY';
  static const String currencySymbol = '₺';
  static const String defaultTimezone = 'Europe/Istanbul';
  static const String privacyPolicyUrl =
      'https://harcama-takip-app-7ff66.web.app/privacy-policy.html';
  static const String webAppUrl = 'https://harcama-takip-app-7ff66.web.app';

  /// Push bildirimlerini gönderen Cloudflare Worker'ın adresi
  /// (bkz. docs/notification-worker.md). Boş verilirse gönderimler yalnızca
  /// kuyruğa yazılır ve sunucu dakikada bir taradığında gider. Derleme sırasında
  /// `--dart-define=NOTIFICATION_SERVER_URL=...` ile de verilebilir.
  static const String notificationServerUrl = String.fromEnvironment(
    'NOTIFICATION_SERVER_URL',
    defaultValue: 'https://harcama-bildirim.hasancaktar.workers.dev',
  );

  static String get appTagline => 'Harcama, kart ve taksitleriniz tek yerde'.tr;

  /// Yönetim paneline erişebilen tek hesap. Asıl yetki kontrolü Firestore
  /// kurallarında ve Cloud Functions'ta yapılır; bu sabit yalnızca arayüz içindir.
  static const String adminEmail = 'hasancaktar@gmail.com';

  // Alan sınırları (Firestore güvenlik kuralları ile birebir aynıdır)
  static const int maxTitleLength = 100;
  static const int maxNotesLength = 500;
  static const int maxNameLength = 60;
  static const int minInstallments = 2;
  static const int maxInstallments = 36;

  /// Yakıt takibinin bağlı olduğu kategori. Bu kategorideki harcamalarda litre,
  /// litre fiyatı, araç ve kilometre bilgisi tutulur.
  static const String fuelCategoryId = 'fuel';

  /// Yönetici kendi kategori listesini tanımlamış olsa da her zaman bulunan
  /// kategoriler (uygulama özellikleri bunlara bağlıdır).
  static const Set<String> systemCategoryIds = {fuelCategoryId};

  static const CategoryItem otherCategory = CategoryItem(
    id: 'other',
    nameTr: 'Diğer',
    nameEn: 'Other',
    iconKey: 'category',
    colorHex: '#6B7280',
    order: 999,
  );

  /// Yerleşik kategoriler (Firestore'da yönetici tanımı yoksa kullanılır).
  static const List<CategoryItem> defaultCategories = [
    CategoryItem(
      id: 'market',
      nameTr: 'Market',
      nameEn: 'Groceries',
      iconKey: 'shopping_basket',
      colorHex: '#10B981',
      order: 0,
    ),
    CategoryItem(
      id: 'restaurant',
      nameTr: 'Restoran / Kafe',
      nameEn: 'Restaurant / Café',
      iconKey: 'restaurant',
      colorHex: '#F97316',
      order: 1,
    ),
    CategoryItem(
      id: 'transportation',
      nameTr: 'Ulaşım',
      nameEn: 'Transport',
      iconKey: 'subway',
      colorHex: '#3B82F6',
      order: 2,
    ),
    CategoryItem(
      id: fuelCategoryId,
      nameTr: 'Akaryakıt',
      nameEn: 'Fuel',
      iconKey: 'fuel',
      colorHex: '#C2410C',
      order: 3,
    ),
    CategoryItem(
      id: 'bills',
      nameTr: 'Fatura',
      nameEn: 'Bills',
      iconKey: 'receipt',
      colorHex: '#EF4444',
      order: 4,
    ),
    CategoryItem(
      id: 'rent',
      nameTr: 'Kira',
      nameEn: 'Rent',
      iconKey: 'home_work',
      colorHex: '#8B5CF6',
      order: 5,
    ),
    CategoryItem(
      id: 'health',
      nameTr: 'Sağlık',
      nameEn: 'Health',
      iconKey: 'medical',
      colorHex: '#06B6D4',
      order: 6,
    ),
    CategoryItem(
      id: 'education',
      nameTr: 'Eğitim',
      nameEn: 'Education',
      iconKey: 'school',
      colorHex: '#6366F1',
      order: 7,
    ),
    CategoryItem(
      id: 'shopping',
      nameTr: 'Alışveriş',
      nameEn: 'Shopping',
      iconKey: 'shopping_bag',
      colorHex: '#F59E0B',
      order: 8,
    ),
    CategoryItem(
      id: 'entertainment',
      nameTr: 'Eğlence',
      nameEn: 'Entertainment',
      iconKey: 'movie',
      colorHex: '#EC4899',
      order: 9,
    ),
    CategoryItem(
      id: 'travel',
      nameTr: 'Seyahat',
      nameEn: 'Travel',
      iconKey: 'flight',
      colorHex: '#14B8A6',
      order: 10,
    ),
    CategoryItem(
      id: 'subscription',
      nameTr: 'Abonelik',
      nameEn: 'Subscriptions',
      iconKey: 'subscriptions',
      colorHex: '#84CC16',
      order: 11,
    ),
    CategoryItem(
      id: 'home',
      nameTr: 'Ev',
      nameEn: 'Home',
      iconKey: 'chair',
      colorHex: '#EAB308',
      order: 12,
    ),
    CategoryItem(
      id: 'personal_care',
      nameTr: 'Kişisel Bakım',
      nameEn: 'Personal care',
      iconKey: 'spa',
      colorHex: '#A855F7',
      order: 13,
    ),
    CategoryItem(
      id: 'donation',
      nameTr: 'Bağış',
      nameEn: 'Donation',
      iconKey: 'volunteer',
      colorHex: '#E11D48',
      order: 14,
    ),
    CategoryItem(
      id: 'pets',
      nameTr: 'Evcil Hayvan',
      nameEn: 'Pets',
      iconKey: 'pets',
      colorHex: '#B45309',
      order: 15,
    ),
    otherCategory,
  ];

  /// Harcama girişinde seçilebilen (aktif) kategoriler.
  static List<CategoryItem> get categories => CategoryRegistry.selectable;

  static CategoryItem getCategoryById(String id) => CategoryRegistry.byId(id);

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

  static PaymentMethodItem getPaymentMethod(String id) {
    for (final m in paymentMethodItems) {
      if (m.id == id) return m;
    }
    return paymentMethodItems.last;
  }

  static String teamRoleName(String role) => switch (role) {
    'owner' => 'Sahip'.tr,
    'admin' => 'Yönetici'.tr,
    _ => 'Üye'.tr,
  };
}
