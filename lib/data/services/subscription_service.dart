import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../models/user.dart';

/// Bir satın alma/geri yükleme işlemi başarısız olduğunda fırlatılan,
/// KULLANICIYA GÖSTERİLMEYE HAZIR (Türkçe) hata.
///
/// `isUserCancelled`: Kullanıcı satın alma penceresini kendi isteğiyle
/// kapattıysa `true` olur. Bu durumda ekranın kullanıcıya "bir hata oluştu"
/// gibi ürkütücü bir mesaj göstermesine GEREK YOKTUR — kullanıcı zaten ne
/// yaptığını biliyor, sessizce paywall ekranında kalması yeterlidir.
class PurchaseException implements Exception {
  PurchaseException(this.message, {this.isUserCancelled = false});

  final String message;
  final bool isUserCancelled;

  @override
  String toString() => message;
}

/// RevenueCat (`purchases_flutter` paketi) ile Google Play üzerinden Premium
/// abonelik satışını yöneten servis.
///
/// NEDEN REVENUECAT? Google Play'in kendi satın alma sistemini (Billing
/// Library) DOĞRUDAN kullanmak, abonelik durumunu (yenilendi mi, iptal
/// edildi mi, deneme süresi bitti mi...) takip etmeyi oldukça
/// karmaşıklaştırır. RevenueCat, bu karmaşıklığı arka planda yönetip bize
/// tek bir soru sormamızı sağlar: "Bu kullanıcının `premium` yetkisi aktif
/// mi?" — bu yüzden Play Store'a çıkacak küçük/orta ölçekli uygulamalarda
/// endüstri standardı haline gelmiştir.
class SubscriptionService {
  SubscriptionService._();

  /// RevenueCat panelinde (dashboard) tanımladığın "yetki" (entitlement)
  /// kimliği. Panelde BUNU BİREBİR AYNI İSİMLE oluşturman gerekiyor
  /// ("Entitlements" sekmesinde "premium" adında bir yetki eklemelisin ve
  /// Aylık/Yıllık ürünlerini bu yetkiye bağlamalısın).
  static const String entitlementId = 'premium';

  /// Uygulama açılışında (main.dart'ta) BİR KERE çağrılır. `.env`
  /// dosyasındaki `REVENUECAT_API_KEY` boşsa (henüz RevenueCat hesabı
  /// kurulmadıysa) hiçbir şey yapmadan sessizce çıkar — uygulama Premium
  /// özellikleri olmadan (ama ÇÖKMEDEN) çalışmaya devam eder.
  static Future<void> init(String apiKey) async {
    if (apiKey.isEmpty) return;

    // Geliştirme sırasında RevenueCat'in konsola ayrıntılı log basmasını
    // sağlar; Play Store'a yayınlarken bu satırı kaldırmana gerek yok,
    // sadece gürültü azaltmak istersen `LogLevel.error` yapabilirsin.
    await Purchases.setLogLevel(LogLevel.warn);
    await Purchases.configure(PurchasesConfiguration(apiKey));
  }

  /// RevenueCat panelinde tanımlı "şu an aktif" teklifi (Offering) getirir.
  /// Bu teklifin içinde `.monthly` ve `.annual` gibi hazır paketler
  /// (Package) bulunur — Paywall ekranını (Adım 7'de) bu paketler
  /// üzerinden çizeceğiz.
  static Future<Offering?> getCurrentOffering() async {
    final offerings = await Purchases.getOfferings();
    return offerings.current;
  }

  /// Kullanıcı "Premium'a Geç" butonuna bastığında çağrılır. Google
  /// Play'in kendi satın alma penceresini açar; işlem tamamlanınca güncel
  /// `CustomerInfo`'yu döner.
  static Future<CustomerInfo> purchase(Package package) async {
    try {
      final result = await Purchases.purchase(PurchaseParams.package(package));
      return result.customerInfo;
    } on PlatformException catch (error) {
      final errorCode = PurchasesErrorHelper.getErrorCode(error);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        throw PurchaseException(
          'Satın alma işlemi iptal edildi.',
          isUserCancelled: true,
        );
      }
      throw PurchaseException(
        'Satın alma tamamlanamadı. Lütfen tekrar dene.',
      );
    }
  }

  /// Kullanıcı telefon değiştirdiğinde veya uygulamayı silip tekrar
  /// kurduğunda, daha önce yaptığı satın alımı geri yükler ("Satın
  /// Alımları Geri Yükle" butonu için).
  static Future<CustomerInfo> restorePurchases() async {
    try {
      return await Purchases.restorePurchases();
    } catch (_) {
      throw PurchaseException(
        'Önceki satın alımların geri yüklenemedi. Lütfen tekrar dene.',
      );
    }
  }

  /// RevenueCat'in "abonelik durumu her değiştiğinde beni haberdar et"
  /// dinleyicisine kaydolur. Örn. abonelik arka planda otomatik yenilenirse
  /// veya bir ödeme sorunu tespit edilirse, ekranımız kullanıcıyı yeniden
  /// açması gerekmeden ANINDA güncellenir.
  static void listenToCustomerInfoUpdates(
    void Function(CustomerInfo customerInfo) onUpdate,
  ) {
    Purchases.addCustomerInfoUpdateListener(onUpdate);
  }

  /// RevenueCat'ten gelen `CustomerInfo`'yu okuyup, Adım 1'de yazdığımız
  /// yerel `User` kaydını GÜNCELLER.
  ///
  /// NEDEN BÖYLE BİR "KÖPRÜ" METODA İHTİYACIMIZ VAR? Çünkü uygulamanın
  /// geri kalanı (limit kontrolleri, paywall, reklam gösterme kararı)
  /// RevenueCat'i hiç tanımıyor; sadece Adım 1'deki basit `User.isPremium`
  /// getter'ını okuyor. Bu metod, RevenueCat'in karmaşık dünyasını, o basit
  /// `User` moduna çevirir.
  static void applyCustomerInfoToUser(User user, CustomerInfo customerInfo) {
    final activeEntitlement = customerInfo.entitlements.active[entitlementId];

    if (activeEntitlement == null) {
      user.subscriptionPlan = SubscriptionPlan.free;
      user.premiumExpiryDate = null;
    } else {
      user.subscriptionPlan = _planFromProductIdentifier(
        activeEntitlement.productIdentifier,
      );
      user.premiumExpiryDate = activeEntitlement.expirationDate != null
          ? DateTime.tryParse(activeEntitlement.expirationDate!)
          : null;
    }

    if (user.isInBox) {
      user.save();
    }
  }

  /// RevenueCat'ten gelen ürün kimliği (örn. "plan_to_plate_yearly"), Aylık
  /// mı Yıllık mı bir abonelik olduğunu anlamak için taranır.
  ///
  /// NOT: Sen RevenueCat panelinde ürünlerini oluştururken kimliklerinin
  /// içinde "yıllık"/"annual"/"year" ya da "aylık"/"monthly"/"month"
  /// geçmesine dikkat et; bu basit kural sayesinde burada ek bir eşleştirme
  /// tablosu tutmaya gerek kalmıyor.
  static SubscriptionPlan _planFromProductIdentifier(String productIdentifier) {
    final normalized = productIdentifier.toLowerCase();
    if (normalized.contains('year') || normalized.contains('annual') || normalized.contains('yillik')) {
      return SubscriptionPlan.yearly;
    }
    return SubscriptionPlan.monthly;
  }
}
