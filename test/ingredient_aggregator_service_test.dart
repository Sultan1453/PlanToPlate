import 'package:flutter_test/flutter_test.dart';
import 'package:plan_to_plate/data/models/ingredient.dart';
import 'package:plan_to_plate/data/models/nutrient.dart';
import 'package:plan_to_plate/data/models/recipe.dart';
import 'package:plan_to_plate/data/models/weekly_plan.dart';
import 'package:plan_to_plate/data/services/ingredient_aggregator_service.dart';

/// Bu test dosyası, kullanıcının istediği ÖRNEK SENARYOYU birebir doğrular:
/// "Farklı günlerde toplam 5 soğan varsa, listede tek satırda '5 Adet Soğan'
/// yazacak."
void main() {
  /// Testlerde her seferinde aynı, basit bir tarif üretmek için yardımcı
  /// fonksiyon. `ingredients` dışındaki alanlar test için önemsiz, o yüzden
  /// sabit/kısa değerler veriyoruz.
  Recipe buildRecipe({
    required String id,
    required MealType mealType,
    required List<Ingredient> ingredients,
  }) {
    return Recipe(
      id: id,
      title: 'Test Tarifi $id',
      mealType: mealType,
      ingredients: ingredients,
      steps: const ['Test adımı'],
      nutrient: Nutrient(calories: 100, protein: 5, carbs: 10, fat: 5),
      cookingMethod: CookingMethod.stovetop,
      servings: 2,
    );
  }

  test('Aynı isim + aynı birimdeki malzemeler tek satırda toplanmalı', () {
    final plan = WeeklyPlan(id: 'plan-1', weekStartDate: DateTime(2026, 8, 10));

    // Pazartesi akşam: 2 Adet Soğan içeren bir tarif atıyoruz.
    plan.mealFor(DayOfWeek.monday, MealType.dinner).recipe = buildRecipe(
      id: 'r1',
      mealType: MealType.dinner,
      ingredients: [
        Ingredient(name: 'Soğan', quantity: 2, unit: 'adet', category: IngredientCategory.produce),
      ],
    );

    // Perşembe öğle: 3 Adet Soğan içeren FARKLI bir tarif atıyoruz.
    plan.mealFor(DayOfWeek.thursday, MealType.lunch).recipe = buildRecipe(
      id: 'r2',
      mealType: MealType.lunch,
      ingredients: [
        Ingredient(name: 'Soğan', quantity: 3, unit: 'adet', category: IngredientCategory.produce),
      ],
    );

    final aggregated = IngredientAggregatorService.aggregate(plan);

    // Sonuçta TEK BİR "Soğan" satırı olmalı, toplam miktar 5 olmalı.
    expect(aggregated.length, 1);
    expect(aggregated.first.name, 'Soğan');
    expect(aggregated.first.quantity, 5);
    expect(aggregated.first.unit, 'adet');
  });

  test('Aynı isim ama FARKLI birimdeki malzemeler ayrı satır olarak kalmalı', () {
    final plan = WeeklyPlan(id: 'plan-2', weekStartDate: DateTime(2026, 8, 10));

    plan.mealFor(DayOfWeek.monday, MealType.dinner).recipe = buildRecipe(
      id: 'r1',
      mealType: MealType.dinner,
      ingredients: [
        Ingredient(name: 'Soğan', quantity: 2, unit: 'adet', category: IngredientCategory.produce),
      ],
    );

    plan.mealFor(DayOfWeek.tuesday, MealType.lunch).recipe = buildRecipe(
      id: 'r2',
      mealType: MealType.lunch,
      ingredients: [
        Ingredient(name: 'Soğan', quantity: 500, unit: 'gram', category: IngredientCategory.produce),
      ],
    );

    final aggregated = IngredientAggregatorService.aggregate(plan);

    expect(aggregated.length, 2);
  });

  test('Boş hücreler (tarifsiz öğünler) hataya sebep olmamalı', () {
    final plan = WeeklyPlan(id: 'plan-3', weekStartDate: DateTime(2026, 8, 10));
    // Hiçbir hücreye tarif atamıyoruz; tüm hücreler `recipe: null`.

    final aggregated = IngredientAggregatorService.aggregate(plan);

    expect(aggregated, isEmpty);
  });

  test('groupByCategory, malzemeleri doğru reyonlara ve market gezme sırasına göre gruplamalı', () {
    final ingredients = [
      Ingredient(name: 'Süt', quantity: 1, unit: 'litre', category: IngredientCategory.dairy),
      Ingredient(name: 'Soğan', quantity: 2, unit: 'adet', category: IngredientCategory.produce),
      Ingredient(name: 'Tavuk But', quantity: 4, unit: 'adet', category: IngredientCategory.butcher),
    ];

    final grouped = IngredientAggregatorService.groupByCategory(ingredients);

    // Manav (produce), Kasap (butcher), Süt Ürünleri (dairy) sırasıyla
    // gelmeli (marketVisitOrder'daki sıraya göre); boş kategoriler
    // (bakery, pantry, other) sonuçta HİÇ görünmemeli.
    expect(grouped.keys.toList(), [
      IngredientCategory.produce,
      IngredientCategory.butcher,
      IngredientCategory.dairy,
    ]);
    expect(grouped[IngredientCategory.produce]!.first.name, 'Soğan');
    expect(grouped[IngredientCategory.butcher]!.first.name, 'Tavuk But');
    expect(grouped[IngredientCategory.dairy]!.first.name, 'Süt');
  });
}
