/// Push bildirimlerini gönderen sunucu (Cloudflare Worker).
abstract class INotificationServer {
  /// Sunucu adresi tanımlı mı? Değilse gönderim yalnızca kuyruğa yazılır.
  bool get isConfigured;

  /// Kuyruktaki kampanyanın hemen gönderilmesini ister. Başarısız olursa
  /// `false` döner; sunucu kuyruğu yine de dakikada bir işler.
  Future<bool> triggerSend(String campaignId);
}
