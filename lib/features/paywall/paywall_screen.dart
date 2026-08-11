import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../data/services/ads_service.dart';
import '../../data/services/subscription_service.dart';
import '../../data/services/user_provider.dart';

/// Kural 2'nin ekranı: kullanıcının haftalık ücretsiz AI hakkı dolduğunda
/// açılan Premium teklif ekranı. İki seçenek sunar:
///
/// A) "Premium'a Geç": RevenueCat üzerinden aylık/yıllık abonelik satın
///    alma (3 gün ücretsiz deneme dahil, gerçek süre/fiyat RevenueCat
///    panelinde tanımladığın ürüne göre otomatik gelir).
/// B) "Reklam İzle, +1 AI Tarifi Kazan": Google AdMob ödüllü reklamı
///    izleyip anında +1 hak kazanma.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  Future<Offering?>? _offeringFuture;
  bool _isPurchasing = false;
  bool _isWatchingAd = false;

  @override
  void initState() {
    super.initState();
    _offeringFuture = SubscriptionService.getCurrentOffering();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PlanToPlate Premium'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.workspace_premium, size: 72, color: AppColors.accentOrange),
          const SizedBox(height: 12),
          Text(
            'Bu haftaki ücretsiz AI tarifi hakkın doldu',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Sınırsız tarif üretmek için Premium\'a geç, ya da kısa bir reklam izleyerek +1 hak kazan.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 28),
          _buildOfferingSection(),
          const SizedBox(height: 20),
          _buildDivider(context),
          const SizedBox(height: 20),
          _buildWatchAdOption(),
        ],
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('VEYA', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.textMuted)),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }

  Widget _buildOfferingSection() {
    return FutureBuilder<Offering?>(
      future: _offeringFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final offering = snapshot.data;
        final packages = offering?.availablePackages ?? const <Package>[];

        if (packages.isEmpty) {
          // RevenueCat panelinde ürünler henüz oluşturulmadıysa (veya
          // `.env`'de REVENUECAT_API_KEY yoksa) buraya düşülür. Uygulama
          // ÇÖKMEZ, sadece dürüst bir bilgi mesajı gösterilir.
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.storefront_outlined, color: AppColors.textMuted, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    'Abonelik mağazası henüz yapılandırılmadı. RevenueCat panelinden ürünlerini oluşturup .env dosyasına anahtarını ekleyince bu alan otomatik dolacak.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: packages.map((package) => _PackageCard(
            package: package,
            isBusy: _isPurchasing,
            onSelect: () => _purchase(package),
          )).toList(),
        );
      },
    );
  }

  Widget _buildWatchAdOption() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.play_circle_fill, color: AppColors.primaryGreenDark, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Reklam İzle, +1 AI Tarifi Kazan',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Kısa bir video reklamı sonuna kadar izle, anında +1 tarif üretme hakkı kazan.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isWatchingAd ? null : _watchRewardedAd,
              icon: _isWatchingAd
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.ondemand_video),
              label: const Text('Reklam İzle'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _purchase(Package package) async {
    setState(() => _isPurchasing = true);
    try {
      final customerInfo = await SubscriptionService.purchase(package);
      ref.read(userProvider.notifier).applyCustomerInfo(customerInfo);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Premium\'a hoş geldin! Artık sınırsız tarif üretebilirsin.')),
      );
      Navigator.of(context).pop();
    } on PurchaseException catch (error) {
      if (!mounted || error.isUserCancelled) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  Future<void> _watchRewardedAd() async {
    setState(() => _isWatchingAd = true);
    await AdsService.loadAndShowRewardedAd(
      onRewardEarned: () {
        ref.read(userProvider.notifier).grantRewardedAdCredit();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('+1 AI tarifi hakkı kazandın! 🎉')),
        );
        Navigator.of(context).pop();
      },
      onFailedToShow: (message) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      },
    );
    if (mounted) setState(() => _isWatchingAd = false);
  }
}

/// Tek bir abonelik paketini (Aylık/Yıllık) gösteren kart.
class _PackageCard extends StatelessWidget {
  const _PackageCard({required this.package, required this.isBusy, required this.onSelect});

  final Package package;
  final bool isBusy;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final product = package.storeProduct;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.title.isNotEmpty ? product.title : package.identifier,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.priceString,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.primaryGreenDark,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    if (product.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          product.description,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: isBusy ? null : onSelect,
                child: const Text('Seç'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
