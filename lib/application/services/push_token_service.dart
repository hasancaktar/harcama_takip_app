import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../domain/repositories/i_user_repository.dart';
import 'notification_service.dart';

/// Takım harcaması bildirimleri (Cloud Functions -> FCM) için cihaz anahtarını kaydeder.
///
/// İzin istemez; bildirim izni kullanıcı hatırlatıcıları açtığında bağlamsal olarak
/// istenir. Web'de VAPID anahtarı gerektirdiği için devre dışıdır.
class PushTokenService {
  final IUserRepository _userRepository;
  final FirebaseMessaging Function() _messaging;
  StreamSubscription<String>? _refreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedSub;
  final NotificationService? _notifications;
  String? _registeredUid;
  String? _token;

  PushTokenService(
    this._userRepository, {
    FirebaseMessaging Function()? messaging,
    this._notifications,
  }) : _messaging = messaging ?? (() => FirebaseMessaging.instance);

  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> register(String uid) async {
    if (!isSupported || _registeredUid == uid) return;
    try {
      final token = await _messaging().getToken();
      if (token == null) return;
      _token = token;
      _registeredUid = uid;
      await _userRepository.addPushToken(uid, token);
      await _refreshSub?.cancel();
      _refreshSub = _messaging().onTokenRefresh.listen((fresh) async {
        final old = _token;
        _token = fresh;
        await _userRepository.addPushToken(uid, fresh);
        if (old != null && old != fresh) {
          await _userRepository.removePushToken(uid, old);
        }
      });
      _listenMessages();
    } catch (e) {
      debugPrint('[PushTokenService] Token kaydedilemedi: $e');
    }
  }

  void _listenMessages() {
    final notifications = _notifications;
    if (notifications == null || _foregroundSub != null) return;
    // Uygulama açıkken gelen bildirimi yerel bildirim olarak göster.
    _foregroundSub = FirebaseMessaging.onMessage.listen((message) {
      final n = message.notification;
      if (n == null) return;
      notifications.showNow(
        title: n.title ?? '',
        body: n.body ?? '',
        route: message.data['route'] as String?,
        channelId: n.android?.channelId ?? 'announcements',
      );
    });
    // Arka plandayken bildirime dokunulursa ilgili sayfayı aç.
    _openedSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final route = message.data['route'];
      if (route is String) notifications.emitTap(route);
    });
  }

  /// Oturum kapatılmadan önce çağrılır; bu cihaza artık bildirim gönderilmez.
  Future<void> unregister() async {
    if (!isSupported) return;
    try {
      final uid = _registeredUid;
      final token = _token;
      await _refreshSub?.cancel();
      await _foregroundSub?.cancel();
      await _openedSub?.cancel();
      _refreshSub = null;
      _foregroundSub = null;
      _openedSub = null;
      _registeredUid = null;
      if (uid == null || token == null) return;
      await _userRepository.removePushToken(uid, token);
    } catch (e) {
      debugPrint('[PushTokenService] unregister hatası: $e');
    }
  }
}
