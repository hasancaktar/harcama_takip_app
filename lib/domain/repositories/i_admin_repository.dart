import '../../core/constants/app_constants.dart';
import '../entities/admin_models.dart';
import '../entities/app_user.dart';

/// Tüm doğrulanmış kullanıcıların okuyabildiği kategori listesi.
abstract class ICategoryRepository {
  /// Yönetici tanımlı tüm kategoriler (pasif ve silinmiş olanlar dahil).
  Stream<List<CategoryItem>> watchAll();
}

/// Yalnızca yöneticinin kullanabildiği işlemler. Yetki, Firestore kurallarında
/// (`isAdmin()`) ve Cloud Functions'ta zorlanır; her yazma işlemi aynı yığında
/// bir işlem kaydı (`adminLogs`) oluşturur.
abstract class IAdminRepository {
  // Kategoriler
  Future<void> saveCategory(
    AppUser admin,
    CategoryItem category, {
    required bool isNew,
  });
  Future<void> saveCategoryOrder(AppUser admin, List<CategoryItem> ordered);
  Future<void> setCategoryDeleted(
    AppUser admin,
    CategoryItem category, {
    required bool deleted,
  });
  Future<void> importDefaultCategories(AppUser admin);

  // Bildirimler
  Stream<ReminderConfig> watchReminderConfig();
  Future<void> saveReminderConfig(AppUser admin, ReminderConfig config);
  Stream<List<NotificationCampaign>> watchCampaigns({int limit = 50});
  Future<void> createCampaign(
    AppUser admin, {
    required String titleTr,
    required String bodyTr,
    required String titleEn,
    required String bodyEn,
    required String target,
    required List<String> targetUids,
  });

  // Kullanıcılar ve kayıtlar
  Future<List<AdminUserSummary>> fetchUsers({int limit = 500});
  Stream<List<AdminLogEntry>> watchLogs({int limit = 100});
}
