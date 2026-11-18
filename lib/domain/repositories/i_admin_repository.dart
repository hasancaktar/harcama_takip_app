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

  /// Kampanyayı kuyruğa ekler ve kimliğini döner.
  Future<String> createCampaign(
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

  /// Kullanıcıyı pasife alır veya yeniden aktif eder.
  Future<void> setUserDisabled(
    AppUser admin,
    AdminUserSummary user, {
    required bool disabled,
  });

  // Öneriler
  Stream<List<FeedbackEntry>> watchFeedback({int limit = 200});
  Future<void> markFeedbackRead(AppUser admin, FeedbackEntry entry);

  // Sürüm notları ("Yenilikler")
  Stream<List<ReleaseNotes>> watchAllReleaseNotes();
  Future<void> saveReleaseNotes(AppUser admin, ReleaseNotes notes);
}

/// Tüm kullanıcıların kullandığı, yönetimle ilgili içerik: öneri gönderme ve
/// sürüm notlarını okuma.
abstract class IAppContentRepository {
  Future<void> sendFeedback({
    required AppUser user,
    required String message,
    required String appVersion,
    required String platform,
  });

  Stream<ReleaseNotes?> watchReleaseNotes(String version);
}
