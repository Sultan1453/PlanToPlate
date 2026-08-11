import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../data/services/ads_service.dart';
import '../../data/services/user_provider.dart';

/// Ücretsiz kullanıcılara ana ekran ve alışveriş listesinin ALTINDA
/// gösterilen banner reklam (Kural 3).
///
/// Premium kullanıcılar için bu widget HİÇBİR ŞEY çizmez
/// (`SizedBox.shrink`) — reklam alanı tamamen kaldırılır, ekranda yer
/// bile kaplamaz.
///
/// `ConsumerStatefulWidget` olması ŞART: banner reklamlar (`BannerAd`)
/// KENDİ yaşam döngüsünü (`load`, `dispose`) yönetir; bu, "her build'de
/// sıfırdan oluşturma" mantığına uymaz — reklamı SADECE BİR KEZ
/// (`initState`'te) yüklemeliyiz.
class BannerAdWidget extends ConsumerStatefulWidget {
  const BannerAdWidget({super.key});

  @override
  ConsumerState<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends ConsumerState<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBanner();
  }

  void _loadBanner() {
    final banner = BannerAd(
      adUnitId: AdsService.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (!mounted) return;
          setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          // İnternet yoksa veya reklam bulunamazsa: sessizce vazgeç, ana
          // ekranı hiçbir şekilde ETKİLEME (kullanıcı reklamsız da olsa
          // uygulamayı sorunsuz kullanabilmeli).
          ad.dispose();
        },
      ),
    );
    banner.load();
    _bannerAd = banner;
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    if (user.isPremium) return const SizedBox.shrink();

    final ad = _bannerAd;
    if (!_isLoaded || ad == null) return const SizedBox.shrink();

    return SafeArea(
      top: false,
      child: Container(
        alignment: Alignment.center,
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        margin: const EdgeInsets.only(top: 4),
        child: AdWidget(ad: ad),
      ),
    );
  }
}
