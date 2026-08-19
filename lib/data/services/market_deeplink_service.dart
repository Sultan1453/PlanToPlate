import '../../core/config/app_config.dart';
import '../../core/utils/turkish_text_utils.dart';
import '../models/ingredient.dart';

/// Desteklenen online market kanalları.
enum MarketChannel {
  getir,
  yemeksepeti,
  migros,
  trendyolGo,
}

extension MarketChannelLabel on MarketChannel {
  String get displayName {
    switch (this) {
      case MarketChannel.getir:
        return 'Getir';
      case MarketChannel.yemeksepeti:
        return 'Yemeksepeti Market';
      case MarketChannel.migros:
        return 'Migros Sanal Market';
      case MarketChannel.trendyolGo:
        return 'Trendyol Go';
    }
  }
}

/// Alışveriş listesini affiliate parametreli deep link / arama URL'lerine çevirir.
///
/// Gerçek sepet API'leri partner sözleşmesine bağlıdır; bu servis URL şeması
/// ve `ref_id` / `affiliate_tag` altyapısını hazır tutar.
class MarketDeeplinkService {
  MarketDeeplinkService._();

  static Uri buildSearchUri({
    required MarketChannel channel,
    required List<Ingredient> items,
    String? refId,
    String? affiliateTag,
  }) {
    final query = _formatQuery(items);
    final ref = (refId ?? AppConfig.affiliateRefId).trim();
    final tag = (affiliateTag ?? AppConfig.affiliateTag).trim();

    switch (channel) {
      case MarketChannel.getir:
        // Getir web arama + UTM/affiliate
        return Uri.https('getir.com', '/arama', {
          'q': query,
          if (ref.isNotEmpty) 'ref_id': ref,
          if (tag.isNotEmpty) 'affiliate_tag': tag,
          'utm_source': 'plantoplate',
          'utm_medium': 'affiliate',
        });
      case MarketChannel.yemeksepeti:
        return Uri.https('www.yemeksepeti.com', '/market/search', {
          'query': query,
          if (ref.isNotEmpty) 'ref_id': ref,
          if (tag.isNotEmpty) 'affiliate_tag': tag,
          'utm_source': 'plantoplate',
        });
      case MarketChannel.migros:
        return Uri.https('www.migros.com.tr', '/arama', {
          'q': query,
          if (ref.isNotEmpty) 'ref_id': ref,
          if (tag.isNotEmpty) 'affiliate_tag': tag,
          'utm_source': 'plantoplate',
        });
      case MarketChannel.trendyolGo:
        // Trendyol arama (Go / market deneyimine yönlenir). Resmi sepet API'si
        // partner sözleşmesine bağlı; şimdilik arama + affiliate parametreleri.
        // Uygulama yüklüyse tarayıcı Trendyol/Go'ya düşebilir.
        return Uri.https('www.trendyol.com', '/sr', {
          'q': query,
          'qt': query,
          'st': query,
          if (ref.isNotEmpty) 'ref_id': ref,
          if (tag.isNotEmpty) 'affiliate_tag': tag,
          'utm_source': 'plantoplate',
          'utm_medium': 'affiliate',
          'utm_campaign': 'trendyol_go_market',
        });
    }
  }

  /// Tek malzeme için arama URL'si.
  static Uri buildSingleItemUri({
    required MarketChannel channel,
    required Ingredient item,
  }) {
    return buildSearchUri(channel: channel, items: [item]);
  }

  static String _formatQuery(List<Ingredient> items) {
    final names = items
        .map((e) => e.name.trim())
        .where((e) => e.isNotEmpty)
        .take(12)
        .toList();
    if (names.isEmpty) return 'market';
    return names.join(' ');
  }

  /// Deep link debug / log için normalize özet.
  static String debugSummary(List<Ingredient> items) {
    return items
        .map((e) => '${normalizeTurkish(e.name)}|${e.quantity}${e.unit}')
        .join(',');
  }
}
