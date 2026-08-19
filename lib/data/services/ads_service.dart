import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../core/config/app_config.dart';

/// Google AdMob reklamlarını (banner + ödüllü video) yöneten servis.
///
/// Gerçek birim kimlikleri `--dart-define` / `--dart-define-from-file=.env`
/// ile verilir; APK içine `.env` gömülmez.
///
/// DEBUG modda her zaman Google test kimlikleri kullanılır (geçersiz trafik
/// riskini önlemek için). Gerçek kimlikler yalnızca release derlemede.
class AdsService {
  AdsService._();

  static Future<void> init() async {
    try {
      await MobileAds.instance.initialize();
    } catch (_) {
      // SDK başlatılamasa bile uygulama reklamsız çalışmaya devam eder.
    }
  }

  static const String _testBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';

  static const String _testRewardedAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';

  static String get bannerAdUnitId {
    if (kDebugMode) return _testBannerAdUnitId;
    final realId = AppConfig.admobBannerAdUnitId.trim();
    return realId.isNotEmpty ? realId : _testBannerAdUnitId;
  }

  static String get rewardedAdUnitId {
    if (kDebugMode) return _testRewardedAdUnitId;
    final realId = AppConfig.admobRewardedAdUnitId.trim();
    return realId.isNotEmpty ? realId : _testRewardedAdUnitId;
  }

  static bool get isUsingRealAdUnits =>
      !kDebugMode && AppConfig.admobBannerAdUnitId.trim().isNotEmpty;

  static Future<void> loadAndShowRewardedAd({
    required void Function() onRewardEarned,
    required void Function(String message) onFailedToShow,
  }) async {
    final done = Completer<void>();

    void completeOnce() {
      if (!done.isCompleted) done.complete();
    }

    try {
      await RewardedAd.load(
        adUnitId: rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
                completeOnce();
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                ad.dispose();
                onFailedToShow('Reklam gösterilemedi. Lütfen tekrar dene.');
                completeOnce();
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
            completeOnce();
          },
        ),
      );
    } catch (_) {
      onFailedToShow('Reklam gösterilemedi. Lütfen tekrar dene.');
      completeOnce();
    }

    await done.future;
  }
}
