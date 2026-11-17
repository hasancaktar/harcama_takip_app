import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:harcama_takip/data/services/notification_server_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'kimlik anahtarıyla /send çağrılır ve kampanya kimliği gönderilir',
    () async {
      late http.Request captured;
      final server = HttpNotificationServer(
        baseUrl: 'https://harcama-bildirim.example.workers.dev',
        idToken: () async => 'kimlik-anahtari',
        client: MockClient((req) async {
          captured = req;
          return http.Response('{"status":"sent"}', 200);
        }),
      );

      expect(await server.triggerSend('c1'), isTrue);
      expect(
        captured.url.toString(),
        'https://harcama-bildirim.example.workers.dev/send',
      );
      expect(captured.method, 'POST');
      expect(captured.headers['Authorization'], 'Bearer kimlik-anahtari');
      expect(jsonDecode(captured.body), {'campaignId': 'c1'});
    },
  );

  test('adres tanımlı değilse veya oturum yoksa istek yapılmaz', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response('{}', 200);
    });
    final noUrl = HttpNotificationServer(
      baseUrl: '',
      idToken: () async => 't',
      client: client,
    );
    expect(noUrl.isConfigured, isFalse);
    expect(await noUrl.triggerSend('c1'), isFalse);

    final noUser = HttpNotificationServer(
      baseUrl: 'https://x.example',
      idToken: () async => null,
      client: client,
    );
    expect(await noUser.triggerSend('c1'), isFalse);
    expect(calls, 0);
  });

  test('sunucu hatası veya ağ hatası uygulamayı çökertmez', () async {
    final rejected = HttpNotificationServer(
      baseUrl: 'https://x.example',
      idToken: () async => 't',
      client: MockClient(
        (_) async => http.Response('{"error":"forbidden"}', 403),
      ),
    );
    expect(await rejected.triggerSend('c1'), isFalse);

    final offline = HttpNotificationServer(
      baseUrl: 'https://x.example',
      idToken: () async => 't',
      client: MockClient(
        (_) async => throw http.ClientException('bağlantı yok'),
      ),
    );
    expect(await offline.triggerSend('c1'), isFalse);
  });
}
