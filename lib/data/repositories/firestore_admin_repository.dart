import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/admin_models.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/i_admin_repository.dart';

class FirestoreCategoryRepository implements ICategoryRepository {
  final FirebaseFirestore _firestore;

  FirestoreCategoryRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<List<CategoryItem>> watchAll() {
    return _firestore.collection('categories').snapshots().map((s) {
      final list = s.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return CategoryItem.fromMap(data);
      }).toList()..sort((a, b) => a.order.compareTo(b.order));
      return list;
    });
  }
}

class FirestoreAdminRepository implements IAdminRepository {
  final FirebaseFirestore _firestore;

  FirestoreAdminRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _categories =>
      _firestore.collection('categories');
  CollectionReference<Map<String, dynamic>> get _campaigns =>
      _firestore.collection('notificationCampaigns');
  CollectionReference<Map<String, dynamic>> get _logs =>
      _firestore.collection('adminLogs');
  DocumentReference<Map<String, dynamic>> get _reminder =>
      _firestore.collection('appConfig').doc('dailyReminder');

  /// İşlem kaydını, asıl yazmayla aynı yığına ekler (ya ikisi de olur ya hiçbiri).
  void _log(WriteBatch batch, AppUser admin, String action, String summary) {
    final ref = _logs.doc();
    batch.set(ref, {
      'id': ref.id,
      'action': action,
      'summary': summary,
      'adminUid': admin.uid,
      'adminEmail': admin.email,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Map<String, dynamic> _categoryData(CategoryItem c) => {
    ...c.toMap(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  @override
  Future<void> saveCategory(
    AppUser admin,
    CategoryItem category, {
    required bool isNew,
  }) async {
    final batch = _firestore.batch();
    batch.set(
      _categories.doc(category.id),
      _categoryData(category),
      SetOptions(merge: true),
    );
    _log(
      batch,
      admin,
      isNew ? 'category.create' : 'category.update',
      '${category.nameTr} (${category.id})${category.isActive ? '' : ' · pasif'}',
    );
    await batch.commit();
  }

  @override
  Future<void> saveCategoryOrder(
    AppUser admin,
    List<CategoryItem> ordered,
  ) async {
    final batch = _firestore.batch();
    for (var i = 0; i < ordered.length; i++) {
      batch.set(_categories.doc(ordered[i].id), {
        'order': i,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    _log(
      batch,
      admin,
      'category.reorder',
      ordered.map((c) => c.nameTr).join(', '),
    );
    await batch.commit();
  }

  @override
  Future<void> setCategoryDeleted(
    AppUser admin,
    CategoryItem category, {
    required bool deleted,
  }) async {
    // Kategori belgesi asla silinmez: geçmiş harcamalar ad/simge/rengi buradan çözer.
    final batch = _firestore.batch();
    batch.set(_categories.doc(category.id), {
      'isDeleted': deleted,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    _log(
      batch,
      admin,
      deleted ? 'category.delete' : 'category.restore',
      '${category.nameTr} (${category.id})',
    );
    await batch.commit();
  }

  @override
  Future<void> importDefaultCategories(AppUser admin) async {
    final batch = _firestore.batch();
    final defaults = AppConstants.defaultCategories;
    for (var i = 0; i < defaults.length; i++) {
      batch.set(
        _categories.doc(defaults[i].id),
        _categoryData(defaults[i].copyWith(order: i)),
      );
    }
    _log(
      batch,
      admin,
      'category.import_defaults',
      '${defaults.length} kategori',
    );
    await batch.commit();
  }

  @override
  Stream<ReminderConfig> watchReminderConfig() {
    return _reminder.snapshots().map(
      (d) => d.exists
          ? ReminderConfig.fromMap(d.data() ?? {})
          : const ReminderConfig(),
    );
  }

  @override
  Future<void> saveReminderConfig(AppUser admin, ReminderConfig config) async {
    final batch = _firestore.batch();
    // merge: sunucunun yazdığı `lastSentDate` / `lastSentTime` korunur (aynı saat için
    // ikinci gönderimi önler).
    batch.set(_reminder, {
      ...config.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': admin.uid,
    }, SetOptions(merge: true));
    final time =
        '${config.hour.toString().padLeft(2, '0')}:${config.minute.toString().padLeft(2, '0')}';
    _log(
      batch,
      admin,
      'reminder.update',
      '${config.enabled ? 'açık' : 'kapalı'} · $time · ${config.target == 'all' ? 'tüm kullanıcılar' : '${config.targetUids.length} kullanıcı'}',
    );
    await batch.commit();
  }

  @override
  Stream<List<NotificationCampaign>> watchCampaigns({int limit = 50}) {
    return _campaigns
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (s) => s.docs.map((d) {
            final data = d.data();
            data['id'] = d.id;
            return NotificationCampaign.fromMap(data);
          }).toList(),
        );
  }

  @override
  Future<String> createCampaign(
    AppUser admin, {
    required String titleTr,
    required String bodyTr,
    required String titleEn,
    required String bodyEn,
    required String target,
    required List<String> targetUids,
  }) async {
    final ref = _campaigns.doc();
    final batch = _firestore.batch();
    // Gönderimi bildirim sunucusu yapar; istemci yalnızca kuyruğa ekler.
    batch.set(ref, {
      'id': ref.id,
      'type': 'manual',
      'titleTr': titleTr,
      'bodyTr': bodyTr,
      'titleEn': titleEn,
      'bodyEn': bodyEn,
      'target': target,
      'targetUids': target == 'selected' ? targetUids : <String>[],
      'status': 'queued',
      'createdBy': admin.uid,
      'createdByEmail': admin.email,
      'createdAt': FieldValue.serverTimestamp(),
    });
    _log(
      batch,
      admin,
      'notification.send',
      '"$titleTr" · ${target == 'all' ? 'tüm kullanıcılar' : '${targetUids.length} kullanıcı'}',
    );
    await batch.commit();
    return ref.id;
  }

  @override
  Future<List<AdminUserSummary>> fetchUsers({int limit = 500}) async {
    final snapshot = await _firestore.collection('users').limit(limit).get();
    final users =
        snapshot.docs.map((d) {
          final data = d.data();
          data['uid'] = d.id;
          return AdminUserSummary.fromMap(data);
        }).toList()..sort(
          (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
        );
    return users;
  }

  @override
  Stream<List<AdminLogEntry>> watchLogs({int limit = 100}) {
    return _logs
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (s) => s.docs.map((d) {
            final data = d.data();
            data['id'] = d.id;
            return AdminLogEntry.fromMap(data);
          }).toList(),
        );
  }

  @override
  Future<void> setUserDisabled(
    AppUser admin,
    AdminUserSummary user, {
    required bool disabled,
  }) async {
    final batch = _firestore.batch();
    batch.update(_firestore.collection('users').doc(user.uid), {
      'disabled': disabled,
      'disabledAt': disabled ? FieldValue.serverTimestamp() : null,
      'disabledBy': disabled ? admin.uid : null,
    });
    _log(
      batch,
      admin,
      disabled ? 'user.disable' : 'user.enable',
      '${user.label} <${user.email}>',
    );
    await batch.commit();
  }

  CollectionReference<Map<String, dynamic>> get _feedback =>
      _firestore.collection('feedback');

  @override
  Stream<List<FeedbackEntry>> watchFeedback({int limit = 200}) {
    return _feedback
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (s) => s.docs.map((d) {
            final data = d.data();
            data['id'] = d.id;
            return FeedbackEntry.fromMap(data);
          }).toList(),
        );
  }

  @override
  Future<void> markFeedbackRead(AppUser admin, FeedbackEntry entry) =>
      _feedback.doc(entry.id).update({'status': 'read'});

  CollectionReference<Map<String, dynamic>> get _releaseNotes =>
      _firestore.collection('releaseNotes');

  @override
  Stream<List<ReleaseNotes>> watchAllReleaseNotes() {
    return _releaseNotes.snapshots().map(
      (s) =>
          s.docs.map((d) {
            final data = d.data();
            data['version'] = d.id;
            return ReleaseNotes.fromMap(data);
          }).toList()..sort(
            (a, b) => ReleaseNotes.compareVersions(b.version, a.version),
          ),
    );
  }

  @override
  Future<void> saveReleaseNotes(AppUser admin, ReleaseNotes notes) async {
    final ref = _releaseNotes.doc(notes.version);
    final existing = await ref.get();
    final wasPublished =
        existing.exists && (existing.data()?['published'] == true);
    final batch = _firestore.batch();
    batch.set(ref, {
      ...notes.toMap(),
      // İlk yayınlandığı an korunur; "kimlere gösterilecek" buna göre belirlenir.
      if (notes.published && !wasPublished)
        'publishedAt': FieldValue.serverTimestamp(),
      if (!notes.published) 'publishedAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    _log(
      batch,
      admin,
      'release_notes.save',
      '${notes.version} · ${notes.published ? 'yayında' : 'taslak'}',
    );
    await batch.commit();
  }
}

class FirestoreAppContentRepository implements IAppContentRepository {
  final FirebaseFirestore _firestore;

  FirestoreAppContentRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> sendFeedback({
    required AppUser user,
    required String message,
    required String appVersion,
    required String platform,
  }) async {
    final ref = _firestore.collection('feedback').doc();
    await ref.set({
      'id': ref.id,
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'message': message,
      'appVersion': appVersion,
      'platform': platform,
      'status': 'new',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Stream<ReleaseNotes?> watchReleaseNotes(String version) {
    return _firestore.collection('releaseNotes').doc(version).snapshots().map((
      d,
    ) {
      if (!d.exists) return null;
      final data = d.data() ?? <String, dynamic>{};
      data['version'] = d.id;
      return ReleaseNotes.fromMap(data);
    });
  }
}
