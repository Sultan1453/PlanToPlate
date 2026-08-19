import 'package:flutter_test/flutter_test.dart';
import 'package:plan_to_plate/data/models/ingredient.dart';
import 'package:plan_to_plate/data/services/purchase_unit_normalizer.dart';

void main() {
  group('Manav → kg', () {
    test('Adet soğan markette kg olur', () {
      final r = PurchaseUnitNormalizer.toPurchaseUnit(
        Ingredient(
          name: 'Soğan',
          quantity: 3,
          unit: 'adet',
          category: IngredientCategory.produce,
        ),
      );
      expect(r.unit, 'kg');
      expect(r.quantity, greaterThanOrEqualTo(0.25));
    });

    test('Adet patates → kg', () {
      final r = PurchaseUnitNormalizer.toPurchaseUnit(
        Ingredient(
          name: 'Patates',
          quantity: 5,
          unit: 'adet',
          category: IngredientCategory.produce,
        ),
      );
      expect(r.unit, 'kg');
      expect(r.quantity, greaterThanOrEqualTo(0.5));
    });

    test('Domates gram → kg', () {
      final r = PurchaseUnitNormalizer.toPurchaseUnit(
        Ingredient(
          name: 'Domates',
          quantity: 600,
          unit: 'gram',
          category: IngredientCategory.produce,
        ),
      );
      expect(r.unit, 'kg');
      expect(r.quantity, 0.75);
    });

    test('Maydanoz tutam → demet', () {
      final r = PurchaseUnitNormalizer.toPurchaseUnit(
        Ingredient(
          name: 'Maydanoz',
          quantity: 1,
          unit: 'tutam',
          category: IngredientCategory.produce,
        ),
      );
      expect(r.unit, 'demet');
      expect(r.quantity, 1);
    });
  });

  group('Market paketleri', () {
    test('Yemek kaşığı zeytinyağı → şişe', () {
      final r = PurchaseUnitNormalizer.toPurchaseUnit(
        Ingredient(
          name: 'Zeytinyağı',
          quantity: 2,
          unit: 'yemek kaşığı',
          category: IngredientCategory.pantry,
        ),
      );
      expect(r.unit, 'şişe');
      expect(r.quantity, 1);
    });

    test('Gram tuz → paket', () {
      final r = PurchaseUnitNormalizer.toPurchaseUnit(
        Ingredient(
          name: 'Tuz',
          quantity: 5,
          unit: 'gram',
          category: IngredientCategory.pantry,
        ),
      );
      expect(r.unit, 'paket');
      expect(r.quantity, 1);
    });

    test('Su bardağı un → kg', () {
      final r = PurchaseUnitNormalizer.toPurchaseUnit(
        Ingredient(
          name: 'Un',
          quantity: 2,
          unit: 'su bardağı',
          category: IngredientCategory.pantry,
        ),
      );
      expect(r.unit, 'kg');
      expect(r.quantity, 1);
    });
  });

  group('Kasap / süt / fırın', () {
    test('Kıyma gram → kg', () {
      final r = PurchaseUnitNormalizer.toPurchaseUnit(
        Ingredient(
          name: 'Dana kıyma',
          quantity: 500,
          unit: 'gram',
          category: IngredientCategory.butcher,
        ),
      );
      expect(r.unit, 'kg');
      expect(r.quantity, 0.5);
    });

    test('Süt bardak → litre', () {
      final r = PurchaseUnitNormalizer.toPurchaseUnit(
        Ingredient(
          name: 'Süt',
          quantity: 2,
          unit: 'su bardağı',
          category: IngredientCategory.dairy,
        ),
      );
      expect(r.unit, 'litre');
      expect(r.quantity, greaterThanOrEqualTo(1));
    });

    test('Dilim ekmek → adet', () {
      final r = PurchaseUnitNormalizer.toPurchaseUnit(
        Ingredient(
          name: 'Ekmek',
          quantity: 4,
          unit: 'dilim',
          category: IngredientCategory.bakery,
        ),
      );
      expect(r.unit, 'adet');
      expect(r.quantity, 1);
    });

    test('Yumurta adet kalır', () {
      final r = PurchaseUnitNormalizer.toPurchaseUnit(
        Ingredient(
          name: 'Yumurta',
          quantity: 6,
          unit: 'adet',
          category: IngredientCategory.dairy,
        ),
      );
      expect(r.unit, 'adet');
      expect(r.quantity, 6);
    });
  });

  group('Birleştirme', () {
    test('İki soğan satırı tek kg satırında toplanır', () {
      final list = PurchaseUnitNormalizer.normalizeList([
        Ingredient(
          name: 'Soğan',
          quantity: 2,
          unit: 'adet',
          category: IngredientCategory.produce,
        ),
        Ingredient(
          name: 'Soğan',
          quantity: 3,
          unit: 'adet',
          category: IngredientCategory.produce,
        ),
      ]);
      expect(list.length, 1);
      expect(list.first.unit, 'kg');
      expect(list.first.quantity, greaterThanOrEqualTo(0.5));
    });

    test('Kaşık + bardak yağ → tek şişe', () {
      final list = PurchaseUnitNormalizer.normalizeList([
        Ingredient(
          name: 'Zeytinyağı',
          quantity: 2,
          unit: 'yemek kaşığı',
          category: IngredientCategory.pantry,
        ),
        Ingredient(
          name: 'Zeytinyağı',
          quantity: 1,
          unit: 'su bardağı',
          category: IngredientCategory.pantry,
        ),
      ]);
      expect(list.length, 1);
      expect(list.first.unit, 'şişe');
      expect(list.first.quantity, 1);
    });
  });
}
