import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../data/models/user.dart';
import '../../data/services/ads_service.dart';
import '../../data/services/navigation_provider.dart';
import '../../data/services/user_provider.dart';

/// Banner reklam. Sekme değişince ağaçtan SİLİNMEZ (Offstage ile gizlenir);
/// aksi halde AdWidget dispose yarışı `_dependents.isEmpty` kırmızısına yol açar.
class BannerAdWidget extends ConsumerStatefulWidget {
  const BannerAdWidget({super.key});

  @override
  ConsumerState<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends ConsumerState<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  ProviderSubscription<User>? _userSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!ref.read(userProvider).isPremium) {
        _loadBanner();
      }
    });

    _userSub = ref.listenManual(userProvider, (previous, next) {
      if (!mounted) return;
      if (next.isPremium) {
        if (_bannerAd != null) {
          _disposeBanner();
          setState(() {});
        }
      } else if (_bannerAd == null) {
        _loadBanner();
      }
    });
  }

  void _disposeBanner() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _isLoaded = false;
  }

  void _loadBanner() {
    if (_bannerAd != null) return;

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
          ad.dispose();
          if (_bannerAd == ad) {
            _bannerAd = null;
            _isLoaded = false;
          }
        },
      ),
    );
    _bannerAd = banner;
    banner.load();
  }

  @override
  void dispose() {
    _userSub?.close();
    _userSub = null;
    _disposeBanner();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = ref.watch(userProvider.select((user) => user.isPremium));
    final tabIndex = ref.watch(shellTabIndexProvider);
    const settingsIndex = 3;
    final hideForTab = tabIndex == settingsIndex;

    if (isPremium) return const SizedBox.shrink();

    final ad = _bannerAd;
    if (!_isLoaded || ad == null) return const SizedBox.shrink();

    // Offstage: widget ağaçta kalır, dispose edilmez → AdWidget çökmesi önlenir.
    return Offstage(
      offstage: hideForTab,
      child: SafeArea(
        top: false,
        child: Container(
          alignment: Alignment.center,
          width: ad.size.width.toDouble(),
          height: ad.size.height.toDouble(),
          margin: const EdgeInsets.only(top: 4),
          child: AdWidget(ad: ad),
        ),
      ),
    );
  }
}
