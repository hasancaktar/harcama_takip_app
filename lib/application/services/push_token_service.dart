import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../domain/repositories/i_user_repository.dart';

/// Takım harcaması bildirimleri (Cloud Functions -> FCM) için cihaz anahtarını kaydeder.
///
/// İzin istemez; bildirim izni kullanıcı hatırlatıcıları açtığında bağlamsal olarak
/// istenir. Web'de VAPID anahtarı gerektirdiği için devre dışıdır.
class PushTokenService {
  final IUserRepository _userRepository;
  final FirebaseMessaging Function() _messaging;
  StreamSubscription<String>? _refreshSub;
  String? _registeredUid;
  String? _token;

  PushTokenService(
    this._userRepository, {
    FirebaseMessaging Function()? messaging,
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
    } catch (e) {
      debugPrint('[PushTokenService] Token kaydedilemedi: $e');
    }
  }

  /// Oturum kapatılmadan önce çağrılır; bu cihaza artık bildirim gönderilmez.
  Future<void> unregister() async {
    final uid = _registeredUid;
    final token = _token;
    await _refreshSub?.cancel();
    _refreshSub = null;
    _registeredUid = null;
    if (uid == null || token == null) return;
    try {
      await _userRepository.removePushToken(uid, token);
    } catch (e) {
      debugPrint('[PushTokenService] Token silinemedi: $e');
    }
  }
}
