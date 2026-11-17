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
    // merge: sunucunun yazdığı `lastSentDate` korunur (aynı gün ikinci gönderimi önler).
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
  Future<void> createCampaign(
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
    // Gönderimi Cloud Function yapar; istemci yalnızca kuyruğa ekler.
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
}
