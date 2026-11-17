import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../domain/repositories/i_notification_server.dart';

/// Cloudflare'deki bildirim sunucusuna "bu kampanyayı şimdi gönder" der.
///
/// İstek, oturumdaki kullanıcının Firebase kimlik anahtarıyla gönderilir; sunucu
/// yönetici olup olmadığını kendisi doğrular. Çağrı başarısız olsa da sunucu
/// kuyruğu dakikada bir tarar; bildirim en geç bir dakika içinde gider.
class HttpNotificationServer implements INotificationServer {
  final String baseUrl;
  final http.Client _client;
  final Future<String?> Function() _idToken;

  HttpNotificationServer({
    required this.baseUrl,
    http.Client? client,
    Future<String?> Function()? idToken,
  }) : _client = client ?? http.Client(),
       _idToken =
           idToken ??
           (() async => FirebaseAuth.instance.currentUser?.getIdToken());

  @override
  bool get isConfigured => baseUrl.trim().isNotEmpty;

  @override
  Future<bool> triggerSend(String campaignId) async {
    if (!isConfigured) return false;
    try {
      final token = await _idToken();
      if (token == null) return false;
      final uri = Uri.parse(baseUrl).resolve('/send');
      final res = await _client
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'campaignId': campaignId}),
          )
          .timeout(const Duration(seconds: 25));
      if (res.statusCode != 200) {
        debugPrint(
          '[NotificationServer] Gönderim tetiklenemedi: ${res.statusCode}',
        );
      }
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[NotificationServer] Sunucuya ulaşılamadı: $e');
      return false;
    }
  }
}
