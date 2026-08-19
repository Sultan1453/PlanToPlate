import '../../core/utils/turkish_text_utils.dart';

/// Markette / pazarda ürünün satıldığı birim.
enum MarketSaleUnit {
  kg,
  adet,
  demet,
  paket,
  sise,
  kutu,
  litre,
  kova,
  gram,
}

extension MarketSaleUnitLabel on MarketSaleUnit {
  String get label {
    switch (this) {
      case MarketSaleUnit.kg:
        return 'kg';
      case MarketSaleUnit.adet:
        return 'adet';
      case MarketSaleUnit.demet:
        return 'demet';
      case MarketSaleUnit.paket:
        return 'paket';
      case MarketSaleUnit.sise:
        return 'şişe';
      case MarketSaleUnit.kutu:
        return 'kutu';
      case MarketSaleUnit.litre:
        return 'litre';
      case MarketSaleUnit.kova:
        return 'kova';
      case MarketSaleUnit.gram:
        return 'gram';
    }
  }

  /// Paket/şişe gibi: birden fazla tarif aynı üründen istese genelde 1 yeter.
  bool get isDiscretePackage {
    switch (this) {
      case MarketSaleUnit.paket:
      case MarketSaleUnit.sise:
      case MarketSaleUnit.kutu:
      case MarketSaleUnit.kova:
      case MarketSaleUnit.demet:
        return true;
      case MarketSaleUnit.kg:
      case MarketSaleUnit.adet:
      case MarketSaleUnit.litre:
      case MarketSaleUnit.gram:
        return false;
    }
  }
}

/// Tek bir ürün ailesinin market satış kuralı.
class ProductPurchaseRule {
  const ProductPurchaseRule({
    required this.keys,
    required this.saleUnit,
    this.kgPerPiece,
    this.exact = false,
    this.priority = 0,
  });

  /// normalizeTurkish isim eşleşmeleri (contains veya exact).
  final List<String> keys;

  final MarketSaleUnit saleUnit;

  /// Tarif "adet" verdiğinde kg'a çevirmek için ortalama ağırlık.
  final double? kgPerPiece;

  /// true ise yalnızca tam isim eşleşir (örn. "un" → "uzun fasulye" olmasın).
  final bool exact;

  /// Aynı isimde birden fazla kural varsa yüksek olan kazanır.
  final int priority;
}

/// Türkiye pazar / manav / market satış birimleri kataloğu.
///
/// Amaç: alışveriş listesinde tariften gelen kaşık/adet/gram ölçülerini,
/// tezgahta gerçekten satılan birime çevirmek.
class PurchaseCatalog {
  PurchaseCatalog._();

  static ProductPurchaseRule? findRule(String normalizedName) {
    ProductPurchaseRule? best;
    var bestScore = -1;

    for (final rule in rules) {
      for (final key in rule.keys) {
        final matches = rule.exact
            ? normalizedName == key || normalizedName.startsWith('$key ')
            : normalizedName == key ||
                normalizedName.startsWith('$key ') ||
                normalizedName.contains(key);
        if (!matches) continue;

        // Daha uzun anahtar = daha spesifik (örn. "pul biber" > "biber")
        final score = key.length * 10 + rule.priority;
        if (score > bestScore) {
          bestScore = score;
          best = rule;
        }
      }
    }
    return best;
  }

  /// Kapsamlı katalog — manav, kasap, süt, fırın, market.
  static final List<ProductPurchaseRule> rules = [
    // ——— MANAV: kg (tezgahta tartılan) ———
    const ProductPurchaseRule(
      keys: ['patates'],
      saleUnit: MarketSaleUnit.kg,
      kgPerPiece: 0.2,
      priority: 20,
    ),
    const ProductPurchaseRule(
      keys: ['sogan', 'kuru sogan', 'taze sogan'],
      saleUnit: MarketSaleUnit.kg,
      kgPerPiece: 0.15,
      priority: 20,
    ),
    const ProductPurchaseRule(
      keys: ['domates'],
      saleUnit: MarketSaleUnit.kg,
      kgPerPiece: 0.15,
      priority: 20,
    ),
    const ProductPurchaseRule(
      keys: ['salatalik', 'hiyar'],
      saleUnit: MarketSaleUnit.kg,
      kgPerPiece: 0.2,
      priority: 20,
    ),
    const ProductPurchaseRule(
      keys: ['havuc'],
      saleUnit: MarketSaleUnit.kg,
      kgPerPiece: 0.12,
      priority: 20,
    ),
    const ProductPurchaseRule(
      keys: ['kabak', 'sakiz kabak', 'balkabagi', 'bal kabagi'],
      saleUnit: MarketSaleUnit.kg,
      kgPerPiece: 0.25,
      priority: 20,
    ),
    const ProductPurchaseRule(
      keys: ['patlican'],
      saleUnit: MarketSaleUnit.kg,
      kgPerPiece: 0.3,
      priority: 20,
    ),
    const ProductPurchaseRule(
      keys: [
        'sivri biber',
        'dolma biber',
        'kapya',
        'kirmizi biber',
        'yesil biber',
        'biber',
      ],
      saleUnit: MarketSaleUnit.kg,
      kgPerPiece: 0.08,
      priority: 15,
    ),
    const ProductPurchaseRule(
      keys: ['fasulye', 'taze fasulye', 'boru fasulye'],
      saleUnit: MarketSaleUnit.kg,
      kgPerPiece: 0.01,
      priority: 20,
    ),
    const ProductPurchaseRule(
      keys: ['bezelye', 'taze bezelye'],
      saleUnit: MarketSaleUnit.kg,
      priority: 20,
    ),
    const ProductPurchaseRule(
      keys: ['bamya'],
      saleUnit: MarketSaleUnit.kg,
      priority: 20,
    ),
    const ProductPurchaseRule(
      keys: ['enginar'],
      saleUnit: MarketSaleUnit.adet,
      priority: 20,
    ),
    const ProductPurchaseRule(
      keys: ['pirasa'],
      saleUnit: MarketSaleUnit.kg,
      kgPerPiece: 0.25,
      priority: 20,
    ),
    const ProductPurchaseRule(
      keys: ['kereviz'],
      saleUnit: MarketSaleUnit.kg,
      kgPerPiece: 0.4,
      priority: 20,
    ),
    const ProductPurchaseRule(
      keys: ['turp', 'kirmizi turp', 'beyaz turp'],
      saleUnit: MarketSaleUnit.kg,
      kgPerPiece: 0.15,
      priority: 20,
    ),
    const ProductPurchaseRule(
      keys: ['pancar'],
      saleUnit: MarketSaleUnit.kg,
      kgPerPiece: 0.2,
      priority: 20,
    ),
    const ProductPurchaseRule(
      keys: ['mantar', 'kultur mantar', 'istiridye mantar'],
      saleUnit: MarketSaleUnit.kg,
      kgPerPiece: 0.02,
      priority: 20,
    ),
    const ProductPurchaseRule(
      keys: ['misir', 'kochan misir'],
      saleUnit: MarketSaleUnit.adet,
      priority: 20,
    ),
    const ProductPurchaseRule(
      keys: ['lahana', 'kirmizi lahana', 'beyaz lahana'],
      saleUnit: MarketSaleUnit.adet,
      priority: 20,
    ),
    const ProductPurchaseRule(
      keys: ['karnabahar'],
      saleUnit: MarketSaleUnit.adet,
      priority: 20,
    ),
    const ProductPurchaseRule(
      keys: ['brokoli'],
      saleUnit: MarketSaleUnit.adet,
      priority: 20,
    ),
    const ProductPurchaseRule(
      keys: ['sarimsak'],
      saleUnit: MarketSaleUnit.adet, // baş olarak
      kgPerPiece: 0.05,
      priority: 25,
    ),
    const ProductPurchaseRule(
      keys: ['zencefil'],
      saleUnit: MarketSaleUnit.kg,
      priority: 20,
    ),
    const ProductPurchaseRule(
      keys: ['limon'],
      saleUnit: MarketSaleUnit.kg,
      kgPerPiece: 0.1,
      priority: 20,
    ),
    const ProductPurchaseRule(
      keys: ['portakal'],
      saleUnit: MarketSaleUnit.kg,
      kgPerPiece: 0.2,
      priority: 20,
    ),
    const ProductPurchaseRule(
      keys: ['mandalina'],
      saleUnit: MarketSaleUnit.kg,
      kgPerPiece: 0.08,
      priority: 20,
    ),
    const ProductPurchaseRule(
      keys: ['greyfurt'],
      saleUnit: MarketSaleUnit.kg,
      kgPerPiece: 0.3,
      priority: 20,
    ),
    const ProductPurchaseRule(
      keys: ['elma'],
      saleUnit: MarketSaleUnit.kg,
      kgPerPiece: 0.2,
      priority: 20,
    ),
    const ProductPurchaseRule(
      keys: ['armut'],
      saleUnit: MarketSaleUnit.kg,
      kgPerPiece: 0.2,
      priority: 20,
    ),
    const ProductPurchaseRule(
      keys: ['muz'],
      saleUnit: MarketSaleUnit.kg,
      kgPerPiece: 0.15,
      priority: 20,
    ),
    const ProductPurchaseRule(
      keys: ['uzum'],
      saleUnit: MarketSaleUnit.kg,
      priority: 20,
    ),
    const ProductPurchaseRule(
      keys: ['cilek'],
      saleUnit: MarketSaleUnit.kg,
      priority: 20,
    ),
    const ProductPurchaseRule(
      keys: ['kiraz', 'visne'],
      saleUnit: MarketSaleUnit.kg,
      priority: 20,
    ),
    const ProductPurchaseRule(
      keys: ['seftali', 'nektarin'],
      saleUnit: MarketSaleUnit.kg,
      kgPerPiece: 0.15,
      priority: 20,
    ),
    const ProductPurchaseRule(
      keys: ['kayisi'],
      saleUnit: MarketSaleUnit.kg,
      kgPerPiece: 0.04,
      priority: 20,
    ),
    const ProductPurchaseRule(
      keys: ['erik'],
      saleUnit: MarketSaleUnit.kg,
      kgPerPiece: 0.04,
      priority: 20,
    ),
    const ProductPurchaseRule(
      keys: ['incir'],
      saleUnit: MarketSaleUnit.kg,
      kgPerPiece: 0.05,
      priority: 20,
    ),
    const ProductPurchaseRule(
      keys: ['nar'],
      saleUnit: MarketSaleUnit.adet,
      priority: 20,
    ),
    const ProductPurchaseRule(
      keys: ['kavun'],
      saleUnit: MarketSaleUnit.adet,
      priority: 20,
    ),
    const ProductPurchaseRule(
      keys: ['karpuz'],
      saleUnit: MarketSaleUnit.adet,
      priority: 20,
    ),
    const ProductPurchaseRule(
      keys: ['ananas'],
      saleUnit: MarketSaleUnit.adet,
      priority: 20,
    ),
    const ProductPurchaseRule(
      keys: ['avokado'],
      saleUnit: MarketSaleUnit.adet,
      priority: 20,
    ),
    const ProductPurchaseRule(
      keys: ['kivi'],
      saleUnit: MarketSaleUnit.kg,
      kgPerPiece: 0.1,
      priority: 20,
    ),

    // Kuru nane baharat; taze nane demet
    const ProductPurchaseRule(
      keys: ['kuru nane'],
      saleUnit: MarketSaleUnit.paket,
      priority: 35,
    ),
    // ——— MANAV: demet (yeşillik) ———
    const ProductPurchaseRule(
      keys: [
        'maydanoz',
        'dereotu',
        'nane',
        'roka',
        'tere',
        'marul',
        'gobek',
        'ispinak',
        'pazi',
        'semizotu',
        'feslegen',
        'taze kekik',
        'yesil sogan',
        'taze sogan',
      ],
      saleUnit: MarketSaleUnit.demet,
      priority: 30,
    ),

    // ——— KASAP / BALIK: kg ———
    const ProductPurchaseRule(
      keys: [
        'kiyma',
        'dana',
        'kuzu',
        'koyun',
        'bonfile',
        'antrikot',
        'pirzola',
        'kusbası',
        'kusbasi',
        'biftek',
        'rosto',
        'ciğer',
        'ciger',
        'koftelik',
      ],
      saleUnit: MarketSaleUnit.kg,
      priority: 25,
    ),
    const ProductPurchaseRule(
      keys: [
        'tavuk',
        'gogus',
        'but',
        'kanat',
        'pirzola tavuk',
        'tavuk baget',
      ],
      saleUnit: MarketSaleUnit.kg,
      priority: 25,
    ),
    const ProductPurchaseRule(
      keys: [
        'balik',
        'somon',
        'hamsi',
        'levrek',
        'cipura',
        'palamut',
        'uskumru',
        'ton',
      ],
      saleUnit: MarketSaleUnit.kg,
      priority: 25,
    ),
    const ProductPurchaseRule(
      keys: ['kofte'],
      saleUnit: MarketSaleUnit.kg,
      priority: 20,
    ),
    const ProductPurchaseRule(
      keys: ['sucuk', 'sosis', 'salam', 'pastirma', 'jambon'],
      saleUnit: MarketSaleUnit.paket,
      priority: 20,
    ),

    // ——— SÜT ÜRÜNLERİ ———
    const ProductPurchaseRule(
      keys: ['sut'],
      saleUnit: MarketSaleUnit.litre,
      exact: true,
      priority: 40,
    ),
    const ProductPurchaseRule(
      keys: ['yogurt'],
      saleUnit: MarketSaleUnit.kova,
      priority: 30,
    ),
    const ProductPurchaseRule(
      keys: ['ayran'],
      saleUnit: MarketSaleUnit.litre,
      priority: 25,
    ),
    const ProductPurchaseRule(
      keys: ['peynir', 'beyaz peynir', 'kasar', 'lor', 'labne', 'dil peynir'],
      saleUnit: MarketSaleUnit.paket,
      priority: 25,
    ),
    const ProductPurchaseRule(
      keys: ['tereyag', 'margarin'],
      saleUnit: MarketSaleUnit.paket,
      priority: 30,
    ),
    const ProductPurchaseRule(
      keys: ['kaymak', 'krema', 'sut kremasi'],
      saleUnit: MarketSaleUnit.paket,
      priority: 25,
    ),
    const ProductPurchaseRule(
      keys: ['yumurta'],
      saleUnit: MarketSaleUnit.adet,
      exact: true,
      priority: 40,
    ),

    // ——— FIRIN ———
    const ProductPurchaseRule(
      keys: ['ekmek', 'somun', 'lavas', 'yufka', 'bazlama', 'pide'],
      saleUnit: MarketSaleUnit.adet,
      priority: 25,
    ),

    // ——— YAĞ / SIVI ———
    const ProductPurchaseRule(
      keys: [
        'zeytinyag',
        'aycicek',
        'sivi yag',
        'misir yag',
        'kanola',
      ],
      saleUnit: MarketSaleUnit.sise,
      priority: 35,
    ),
    const ProductPurchaseRule(
      keys: ['yag'],
      saleUnit: MarketSaleUnit.sise,
      exact: true,
      priority: 10,
    ),
    const ProductPurchaseRule(
      keys: ['sirke', 'limon suyu', 'nar eksisi', 'nar eks'],
      saleUnit: MarketSaleUnit.sise,
      priority: 30,
    ),

    // ——— SALÇA / SOS ———
    const ProductPurchaseRule(
      keys: ['salca', 'domates salcasi', 'biber salcasi', 'tahin', 'pekmez'],
      saleUnit: MarketSaleUnit.kutu,
      priority: 30,
    ),
    const ProductPurchaseRule(
      keys: ['mayonez', 'ketcap', 'hardal', 'soy sos'],
      saleUnit: MarketSaleUnit.sise,
      priority: 25,
    ),

    // ——— BAHARAT / KURU ———
    const ProductPurchaseRule(
      keys: [
        'tuz',
        'karabiber',
        'kimyon',
        'pul biber',
        'toz biber',
        'kirmizi toz',
        'baharat',
        'kekik',
        'tarcin',
        'sumak',
        'zerdecal',
        'kori',
        'yenibahar',
        'karanfil',
        'defne',
        'biberiye',
        'susam',
        'hashas',
        'corek otu',
        'mahana',
        'kakao',
        'vanilin',
        'kabartma tozu',
        'karbonat',
        'nisasta',
      ],
      saleUnit: MarketSaleUnit.paket,
      priority: 30,
    ),

    // ——— KURU GIDA / KG PAKET ———
    const ProductPurchaseRule(
      keys: ['un'],
      saleUnit: MarketSaleUnit.kg,
      exact: true,
      priority: 40,
    ),
    const ProductPurchaseRule(
      keys: ['seker', 'toz seker', 'esmer seker'],
      saleUnit: MarketSaleUnit.kg,
      priority: 30,
    ),
    const ProductPurchaseRule(
      keys: ['pirinc'],
      saleUnit: MarketSaleUnit.kg,
      exact: true,
      priority: 40,
    ),
    const ProductPurchaseRule(
      keys: ['bulgur'],
      saleUnit: MarketSaleUnit.kg,
      priority: 30,
    ),
    const ProductPurchaseRule(
      keys: ['mercimek', 'kirmizi mercimek', 'yesil mercimek'],
      saleUnit: MarketSaleUnit.kg,
      priority: 30,
    ),
    const ProductPurchaseRule(
      keys: ['nohut', 'kuru fasulye', 'kuru bakla', 'boru'],
      saleUnit: MarketSaleUnit.kg,
      priority: 25,
    ),
    const ProductPurchaseRule(
      keys: ['makarna', 'sehirye', 'eriste', 'irmik'],
      saleUnit: MarketSaleUnit.paket,
      priority: 25,
    ),
    const ProductPurchaseRule(
      keys: ['konserve', 'ton baligi', 'misir konserve', 'bezelye konserve'],
      saleUnit: MarketSaleUnit.kutu,
      priority: 20,
    ),
    const ProductPurchaseRule(
      keys: ['zeytin'],
      saleUnit: MarketSaleUnit.kg,
      priority: 25,
    ),
    const ProductPurchaseRule(
      keys: ['ceviz', 'findik', 'badem', 'fistik', 'kaju', 'kuru uzum'],
      saleUnit: MarketSaleUnit.kg,
      priority: 20,
    ),
    const ProductPurchaseRule(
      keys: ['bal', 'recel', 'nutella'],
      saleUnit: MarketSaleUnit.kutu,
      priority: 20,
    ),
    const ProductPurchaseRule(
      keys: ['cay', 'kahve', 'turk kahvesi'],
      saleUnit: MarketSaleUnit.paket,
      priority: 25,
    ),
  ];

  /// Kategoriye göre varsayılan satış birimi (katalogda yoksa).
  static MarketSaleUnit fallbackForCategory(String categoryName) {
    switch (categoryName) {
      case 'produce':
        return MarketSaleUnit.kg;
      case 'butcher':
        return MarketSaleUnit.kg;
      case 'dairy':
        return MarketSaleUnit.adet;
      case 'pantry':
        return MarketSaleUnit.paket;
      case 'bakery':
        return MarketSaleUnit.adet;
      default:
        return MarketSaleUnit.adet;
    }
  }

  static String normalizeName(String name) => normalizeTurkish(name);
}
