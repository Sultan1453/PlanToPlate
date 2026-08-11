import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Google AdMob reklamlarını (banner + ödüllü video) yöneten servis.
///
/// GERÇEK HESAP KURULUMU: `.env` dosyana `ADMOB_BANNER_AD_UNIT_ID` ve
/// `ADMOB_REWARDED_AD_UNIT_ID` değerlerini (kendi AdMob hesabından
/// aldığın gerçek reklam birimi kimlikleri) eklediğin anda, bu servis
/// OTOMATİK olarak onları kullanmaya başlar — Gemini/RevenueCat'te
/// olduğu gibi, tek bir Dart kod satırı değiştirmene gerek YOKTUR.
///
/// GÜVENLİK ÖNLEMİ (`kDebugMode` kontrolü): `.env`'e gerçek kimlikleri
/// yapıştırsan bile, uygulama DEBUG modunda (yani `flutter run` ile
/// geliştirme sırasında) çalışıyorsa HER ZAMAN Google'ın test
/// kimliklerini kullanır. Bunun nedeni: geliştirme sırasında GERÇEK
/// reklam kimliklerine tekrar tekrar tıklamak/izlemek, Google'ın
/// "geçersiz trafik" (invalid traffic) sistemini tetikleyip AdMob
/// hesabını askıya alabilir. Gerçek kimlikler SADECE `flutter build`
/// ile üretilen (Play Store'a yüklenecek) RELEASE sürümde devreye girer.
class AdsService {
  AdsService._();

  /// Uygulama açılışında (main.dart'ta) BİR KERE çağrılır; AdMob SDK'sını
  /// başlatır. Bu çağrı olmadan hiçbir reklam yüklenemez.
  static Future<void> init() async {
    await MobileAds.instance.initialize();
  }

  /// Google'ın HERKESE AÇIK, resmi TEST banner reklam kimliği (gerçek
  /// para/gelir üretmez, her zaman güvenle çalışır).
  static const String _testBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';

  /// Google'ın resmi TEST ödüllü video reklam kimliği.
  static const String _testRewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917';

  /// Ana ekran ve alışveriş listesi altında gösterilecek banner reklamın
  /// birim kimliği. `kDebugMode`'da her zaman test kimliği; release
  /// modda `.env`'deki gerçek kimlik (varsa) kullanılır.
  static String get bannerAdUnitId {
    if (kDebugMode) return _testBannerAdUnitId;
    final realId = dotenv.env['ADMOB_BANNER_AD_UNIT_ID']?.trim() ?? '';
    return realId.isNotEmpty ? realId : _testBannerAdUnitId;
  }

  /// "Reklam İzle, +1 AI Tarifi Kazan" özelliğinde kullanılan ödüllü video
  /// reklamın birim kimliği. Aynı `kDebugMode` güvenlik kuralı geçerlidir.
  static String get rewardedAdUnitId {
    if (kDebugMode) return _testRewardedAdUnitId;
    final realId = dotenv.env['ADMOB_REWARDED_AD_UNIT_ID']?.trim() ?? '';
    return realId.isNotEmpty ? realId : _testRewardedAdUnitId;
  }

  /// Ayarlar ekranında "şu an test mi, gerçek reklam mı gösteriliyor?"
  /// bilgisini şeffafça göstermek için kullanılır.
  static bool get isUsingRealAdUnits =>
      !kDebugMode && (dotenv.env['ADMOB_BANNER_AD_UNIT_ID']?.trim().isNotEmpty ?? false);

  /// Ödüllü bir reklamı yükler ve YÜKLENDİĞİ AN otomatik olarak gösterir.
  ///
  /// Kullanıcı videoyu SONUNA KADAR izlerse `onRewardEarned` çağrılır —
  /// ekran bu callback içinde `user.grantRewardedAdCredit()` (Adım 1'de
  /// yazmıştık) çağırıp +1 hak verecek.
  ///
  /// Reklam hiç yüklenemezse (örn. internet yok) veya kullanıcı videoyu
  /// ortada kapatıp SONUNA KADAR İZLEMEDEN çıkarsa, `onRewardEarned`
  /// ÇAĞRILMAZ — bu, "ödülü sadece videoyu bitirenler alsın" kuralının
  /// doğal bir sonucudur.
  static Future<void> loadAndShowRewardedAd({
    required void Function() onRewardEarned,
    required void Function(String message) onFailedToShow,
  }) async {
    await RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) => ad.dispose(),
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              onFailedToShow('Reklam gösterilemedi. Lütfen tekrar dene.');
            },
          );

          ad.show(
            onUserEarnedReward: (ad, reward) {
              onRewardEarned();
            },
          );
        },
        onAdFailedToLoad: (error) {
          onFailedToShow(
            'Şu an gösterilecek bir reklam bulunamadı. Lütfen daha sonra tekrar dene.',
          );
        },
      ),
    );
  }
}
