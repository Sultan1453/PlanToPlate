import '../../core/utils/turkish_text_utils.dart';
import '../models/ingredient.dart';
import 'purchase_catalog.dart';

/// Türkiye market / pazar için yaklaşık birim fiyatlar (TRY, 2026 tahmini).
///
/// Bu bir **tahmin**dir; gerçek fiyat bölgeye ve markete göre değişir.
/// Alışveriş listesindeki (normalize edilmiş) birim × miktar ile çarpılır.
class MarketPriceCatalog {
  MarketPriceCatalog._();

  /// Tek satır için tahmini tutar (TL).
  static double estimateLine(Ingredient ingredient) {
    final name = normalizeTurkish(ingredient.name);
    final unit = normalizeTurkish(ingredient.unit);
    final qty = ingredient.quantity <= 0 ? 1.0 : ingredient.quantity;

    final perUnit = _pricePerUnit(name, unit, ingredient.category);
    return perUnit * qty;
  }

  static double _pricePerUnit(
    String name,
    String unit,
    IngredientCategory category,
  ) {
    final named = _namedPrice(name, unit);
    if (named != null) return named;

    // Birime göre genel varsayılan
    if (unit == 'kg' || unit == 'kilogram') {
      return _fallbackKg(category);
    }
    if (unit.contains('litre') || unit == 'lt') return 45;
    if (unit.contains('sise')) return 120;
    if (unit.contains('paket')) return 55;
    if (unit.contains('kutu')) return 65;
    if (unit.contains('kova')) return 90;
    if (unit == 'demet') return 20;
    if (unit.contains('gram')) return 0.08; // ~80 TL/kg
    if (unit == 'adet' || unit == 'tane') {
      return category == IngredientCategory.dairy ? 6 : 25;
    }
    return 40;
  }

  static double? _namedPrice(String name, String unit) {
    // Uzun anahtar önce
    final entries = _prices.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));

    for (final e in entries) {
      final key = e.key;
      if (name == key || name.startsWith('$key ') || name.contains(key)) {
        final byUnit = e.value;
        if (byUnit.containsKey(unit)) return byUnit[unit];
        // Birim eşleşmezse en yaygın birimi kullan
        if (byUnit.containsKey('kg') && (unit == 'kg' || unit.contains('gram'))) {
          if (unit.contains('gram')) return byUnit['kg']! / 1000;
          return byUnit['kg'];
        }
        return byUnit.values.first;
      }
    }

    // Katalog kuralından birim ipucu
    final rule = PurchaseCatalog.findRule(name);
    if (rule != null && _prices.containsKey(rule.keys.first)) {
      return _prices[rule.keys.first]!.values.first;
    }
    return null;
  }

  static double _fallbackKg(IngredientCategory category) {
    switch (category) {
      case IngredientCategory.produce:
        return 35;
      case IngredientCategory.butcher:
        return 320;
      case IngredientCategory.dairy:
        return 180;
      case IngredientCategory.pantry:
        return 50;
      case IngredientCategory.bakery:
        return 40;
      case IngredientCategory.other:
        return 40;
    }
  }

  /// Anahtar: normalize ürün adı parçası → { birim: TL }
  static const Map<String, Map<String, double>> _prices = {
    // Manav
    'patates': {'kg': 22},
    'sogan': {'kg': 28},
    'domates': {'kg': 45},
    'salatalik': {'kg': 35},
    'havuc': {'kg': 30},
    'biber': {'kg': 55},
    'patlican': {'kg': 40},
    'kabak': {'kg': 30},
    'limon': {'kg': 50},
    'elma': {'kg': 45},
    'muz': {'kg': 55},
    'portakal': {'kg': 40},
    'sarimsak': {'adet': 15, 'kg': 180},
    'maydanoz': {'demet': 15},
    'dereotu': {'demet': 15},
    'nane': {'demet': 15, 'paket': 25},
    'roka': {'demet': 20},
    'marul': {'demet': 25},
    'ispinak': {'demet': 30, 'kg': 40},
    'mantar': {'kg': 120},
    // Kasap
    'kiyma': {'kg': 480},
    'tavuk': {'kg': 160},
    'dana': {'kg': 520},
    'kuzu': {'kg': 580},
    'balik': {'kg': 350},
    'somon': {'kg': 650},
    'sucuk': {'paket': 120},
    // Süt
    'sut': {'litre': 42},
    'yogurt': {'kova': 95, 'adet': 45},
    'peynir': {'paket': 110, 'kg': 280},
    'tereyag': {'paket': 95},
    'yumurta': {'adet': 5.5},
    'labne': {'paket': 70},
    // Market
    'zeytinyag': {'sise': 220},
    'aycicek': {'sise': 95},
    'yag': {'sise': 95},
    'un': {'kg': 32},
    'seker': {'kg': 45},
    'pirinc': {'kg': 75},
    'bulgur': {'kg': 55},
    'mercimek': {'kg': 60},
    'nohut': {'kg': 70},
    'makarna': {'paket': 35},
    'tuz': {'paket': 25},
    'karabiber': {'paket': 40},
    'salca': {'kutu': 55},
    'sirke': {'sise': 45},
    'cay': {'paket': 90},
    'ekmek': {'adet': 15},
    'zeytin': {'kg': 160, 'paket': 80},
  };
}
