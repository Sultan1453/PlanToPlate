import '../../core/utils/turkish_text_utils.dart';
import '../models/ingredient.dart';
import 'ingredient_aggregator_service.dart';
import 'purchase_catalog.dart';

/// Tarif ölçülerini Türkiye'de markette/pazarda satılan birimlere çevirir.
///
/// Örnekler:
/// - 3 adet soğan → 0.5 kg Soğan
/// - 2 yemek kaşığı zeytinyağı → 1 şişe Zeytinyağı
/// - 1 tutam maydanoz → 1 demet Maydanoz
/// - 500 gram kıyma → 0.5 kg Kıyma
class PurchaseUnitNormalizer {
  PurchaseUnitNormalizer._();

  static List<Ingredient> normalizeList(List<Ingredient> ingredients) {
    final Map<String, Ingredient> merged = {};

    for (final ingredient in ingredients) {
      final purchase = toPurchaseUnit(ingredient);
      final key = IngredientAggregatorService.mergeKeyFor(purchase);
      final existing = merged[key];
      if (existing == null) {
        merged[key] = purchase;
        continue;
      }

      final unit = normalizeTurkish(existing.unit);
      final sale = _saleUnitFromLabel(unit);

      if (sale?.isDiscretePackage ?? _isDiscreteLabel(unit)) {
        if (purchase.quantity > existing.quantity) {
          existing.quantity = purchase.quantity;
        }
      } else {
        existing.quantity += purchase.quantity;
        existing.quantity = _roundForSale(existing.quantity, sale ?? MarketSaleUnit.adet);
      }
    }

    return merged.values.toList();
  }

  static Ingredient toPurchaseUnit(Ingredient ingredient) {
    final nameKey = PurchaseCatalog.normalizeName(ingredient.name);
    final unitKey = normalizeTurkish(ingredient.unit);
    final qty = ingredient.quantity <= 0 ? 1.0 : ingredient.quantity;

    final rule = PurchaseCatalog.findRule(nameKey);
    final saleUnit = rule?.saleUnit ??
        PurchaseCatalog.fallbackForCategory(ingredient.category.name);

    final converted = _convertToSaleUnit(
      qty: qty,
      recipeUnit: unitKey,
      saleUnit: saleUnit,
      kgPerPiece: rule?.kgPerPiece,
      nameKey: nameKey,
    );

    return Ingredient(
      name: ingredient.name,
      quantity: converted,
      unit: saleUnit.label,
      category: ingredient.category,
      isChecked: ingredient.isChecked,
    );
  }

  /// Tarif miktarını satış birimine çevirir.
  static double _convertToSaleUnit({
    required double qty,
    required String recipeUnit,
    required MarketSaleUnit saleUnit,
    required double? kgPerPiece,
    required String nameKey,
  }) {
    // —— Hedef: kg ——
    if (saleUnit == MarketSaleUnit.kg) {
      if (_isKg(recipeUnit)) {
        return _roundForSale(qty, MarketSaleUnit.kg);
      }
      if (_isGram(recipeUnit)) {
        return _roundForSale(qty / 1000.0, MarketSaleUnit.kg);
      }
      if (_isAdet(recipeUnit) || recipeUnit.contains('dis')) {
        // Sarımsak dişi: ~4 diş = 1 baş; baş adet satılıyorsa ayrıca ele alınır
        if (recipeUnit.contains('dis') && nameKey.contains('sarimsak')) {
          final heads = (qty / 4).ceil().toDouble();
          final kg = (kgPerPiece ?? 0.05) * heads;
          return _roundForSale(kg, MarketSaleUnit.kg);
        }
        final per = kgPerPiece ?? 0.15;
        return _roundForSale(qty * per, MarketSaleUnit.kg);
      }
      if (_isCookingUnit(recipeUnit)) {
        // Kaşık/bardak ile tariflenen kg ürün → en az 1 kg paket/tartım
        return _roundForSale(1.0, MarketSaleUnit.kg);
      }
      if (_isMl(recipeUnit)) {
        // Sıvı → litre değil de kg hedefi nadir; yaklaşık 1:1
        return _roundForSale(qty / 1000.0, MarketSaleUnit.kg);
      }
      // Bilinmeyen birim + kg satılan ürün
      return _roundForSale(kgPerPiece != null ? qty * kgPerPiece : qty, MarketSaleUnit.kg);
    }

    // —— Hedef: demet (yeşillik) ——
    if (saleUnit == MarketSaleUnit.demet) {
      if (recipeUnit.contains('demet')) {
        return qty.ceilToDouble().clamp(1, 20);
      }
      // tutam / kaşık / adet / yaprak → en az 1 demet
      return 1;
    }

    // —— Hedef: adet ——
    if (saleUnit == MarketSaleUnit.adet) {
      if (_isAdet(recipeUnit)) {
        return qty.ceilToDouble().clamp(1, 99);
      }
      if (recipeUnit.contains('dis') && nameKey.contains('sarimsak')) {
        return (qty / 4).ceil().toDouble().clamp(1, 20);
      }
      if (_isCookingUnit(recipeUnit) || recipeUnit.contains('dilim')) {
        // Dilim ekmek / kaşık → 1 adet ürün
        return 1;
      }
      if (_isKg(recipeUnit)) {
        // Nadir: kg verilmiş ama adet satılan (lahana) → 1 adet
        return qty.ceilToDouble().clamp(1, 10);
      }
      if (_isGram(recipeUnit)) {
        return 1;
      }
      return qty.ceilToDouble().clamp(1, 99);
    }

    // —— Hedef: litre ——
    if (saleUnit == MarketSaleUnit.litre) {
      if (recipeUnit.contains('litre') || recipeUnit == 'lt' || recipeUnit == 'l') {
        return _roundForSale(qty, MarketSaleUnit.litre);
      }
      if (_isMl(recipeUnit)) {
        return _roundForSale(qty / 1000.0, MarketSaleUnit.litre);
      }
      if (recipeUnit.contains('bardag') ||
          recipeUnit.contains('bardak') ||
          recipeUnit.contains('fincan')) {
        return _roundForSale((qty * 0.2).clamp(1, 6), MarketSaleUnit.litre);
      }
      if (_isCookingUnit(recipeUnit)) {
        return 1;
      }
      return _roundForSale(qty < 1 ? 1 : qty, MarketSaleUnit.litre);
    }

    // —— Hedef: şişe / kutu / paket / kova ——
    if (saleUnit == MarketSaleUnit.sise ||
        saleUnit == MarketSaleUnit.kutu ||
        saleUnit == MarketSaleUnit.paket ||
        saleUnit == MarketSaleUnit.kova) {
      if (normalizeTurkish(saleUnit.label) == recipeUnit ||
          recipeUnit.contains(normalizeTurkish(saleUnit.label))) {
        return qty.ceilToDouble().clamp(1, 10);
      }
      // Tarif kaşık/gram/ml/tutam → 1 paket/şişe yeter
      return 1;
    }

    // —— Hedef: gram (nadir; kıyma bazen) ——
    if (saleUnit == MarketSaleUnit.gram) {
      if (_isGram(recipeUnit)) {
        return _shopRoundGrams(qty);
      }
      if (_isKg(recipeUnit)) {
        return _shopRoundGrams(qty * 1000);
      }
      return _shopRoundGrams(qty);
    }

    return qty;
  }

  static double _roundForSale(double qty, MarketSaleUnit unit) {
    if (qty <= 0) return unit == MarketSaleUnit.kg ? 0.5 : 1;

    switch (unit) {
      case MarketSaleUnit.kg:
        // Market tartımı: 0.25 / 0.5 / 0.75 / 1 / 1.5 / 2 ...
        if (qty <= 0.25) return 0.25;
        if (qty <= 0.5) return 0.5;
        if (qty <= 0.75) return 0.75;
        if (qty <= 1) return 1;
        if (qty <= 1.5) return 1.5;
        if (qty <= 2) return 2;
        return (qty * 2).ceil() / 2.0; // 0.5 adımlarla yukarı
      case MarketSaleUnit.litre:
        if (qty <= 1) return 1;
        return qty.ceilToDouble();
      case MarketSaleUnit.adet:
      case MarketSaleUnit.demet:
      case MarketSaleUnit.paket:
      case MarketSaleUnit.sise:
      case MarketSaleUnit.kutu:
      case MarketSaleUnit.kova:
        return qty.ceilToDouble().clamp(1, 99);
      case MarketSaleUnit.gram:
        return _shopRoundGrams(qty);
    }
  }

  static double _shopRoundGrams(double qty) {
    if (qty <= 150) return 150;
    if (qty <= 300) return 250;
    if (qty <= 600) return 500;
    if (qty <= 1000) return 1000;
    return (qty / 100).ceil() * 100.0;
  }

  static bool _isKg(String u) =>
      u == 'kg' || u == 'kilogram' || u == 'kilo';

  static bool _isGram(String u) =>
      u == 'g' || u == 'gr' || u.contains('gram');

  static bool _isMl(String u) =>
      u == 'ml' || u.contains('mililitre');

  static bool _isAdet(String u) =>
      u == 'adet' || u == 'tane' || u == 'piece' || u == 'pcs';

  static bool _isCookingUnit(String u) {
    return u.contains('kasig') ||
        u.contains('kasik') ||
        u.contains('tutam') ||
        u.contains('bardag') ||
        u.contains('bardak') ||
        u.contains('fincan') ||
        u.contains('dilim') ||
        u.contains('avuc') ||
        u.contains('damla') ||
        u.contains('yaprak') ||
        u.contains('pinch') ||
        u.contains('tbsp') ||
        u.contains('tsp') ||
        u.contains('cup');
  }

  static bool _isDiscreteLabel(String unit) {
    return unit.contains('paket') ||
        unit.contains('sise') ||
        unit.contains('kutu') ||
        unit.contains('kova') ||
        unit == 'demet';
  }

  static MarketSaleUnit? _saleUnitFromLabel(String unit) {
    if (unit == 'kg' || unit == 'kilogram') return MarketSaleUnit.kg;
    if (unit == 'adet' || unit == 'tane') return MarketSaleUnit.adet;
    if (unit == 'demet') return MarketSaleUnit.demet;
    if (unit.contains('paket')) return MarketSaleUnit.paket;
    if (unit.contains('sise')) return MarketSaleUnit.sise;
    if (unit.contains('kutu')) return MarketSaleUnit.kutu;
    if (unit.contains('litre') || unit == 'lt') return MarketSaleUnit.litre;
    if (unit.contains('kova')) return MarketSaleUnit.kova;
    if (unit.contains('gram')) return MarketSaleUnit.gram;
    return null;
  }
}
