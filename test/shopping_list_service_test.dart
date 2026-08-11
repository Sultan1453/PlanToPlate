import 'package:flutter_test/flutter_test.dart';
import 'package:plan_to_plate/data/models/ingredient.dart';
import 'package:plan_to_plate/data/models/nutrient.dart';
import 'package:plan_to_plate/data/models/recipe.dart';
import 'package:plan_to_plate/data/models/weekly_plan.dart';
import 'package:plan_to_plate/data/services/ingredient_aggregator_service.dart';
import 'package:plan_to_plate/data/services/shopping_list_service.dart';

/// `ShoppingListService`, kullanıcının istediği "evde olan malzemelerin
/// üzeri çizilebilecek, manuel ekstra ürünler eklenebilecek" özelliğini
/// test eder.
///
/// NOT: Bu servis normalde `plan.save()` çağırır (gerçek uygulamada Hive
/// kutusuna kalıcı yazar). Bu testlerde `WeeklyPlan` nesnesi hiçbir Hive
/// kutusuna eklenmediği (`box.put(...)` çağrılmadığı) için,
/// `ShoppingListService`'in dahili `_saveIfInBox` kontrolü `.save()`
/// çağrısını atlar; bu sayede test, gerçek bir Hive kutusu açmadan (yani
/// `HiveService.init()` çağırmadan) çalışabilir. Uygulama gerçekten
/// çalışırken `WeeklyPlan` her zaman bir kutuya ait olacağı için kayıt
/// normal şekilde gerçekleşir.
void main() {
  Recipe buildRecipe(List<Ingredient> ingredients) {
    return Recipe(
      id: 'r1',
      title: 'Test Tarifi',
      mealType: MealType.dinner,
      ingredients: ingredients,
      steps: const ['Adım'],
      nutrient: Nutrient(calories: 100, protein: 5, carbs: 10, fat: 5),
      cookingMethod: CookingMethod.stovetop,
      servings: 2,
    );
  }

  test('Otomatik bir malzeme işaretlenince checkedAutoItemKeys güncellenmeli ve kalıcı görünmeli', () {
    final plan = WeeklyPlan(id: 'p1', weekStartDate: DateTime(2026, 8, 10));
    plan.mealFor(DayOfWeek.monday, MealType.dinner).recipe = buildRecipe([
      Ingredient(name: 'Soğan', quantity: 2, unit: 'adet', category: IngredientCategory.produce),
    ]);

    var grouped = ShoppingListService.buildShoppingList(plan);
    final onionEntry = grouped[IngredientCategory.produce]!.first;
    expect(onionEntry.ingredient.isChecked, isFalse);

    ShoppingListService.toggleChecked(plan, onionEntry);

    // Listeyi YENİDEN oluşturuyoruz (gerçek ekranda da her açılışta böyle
    // olur); "Soğan" hâlâ işaretli görünmeli çünkü anahtarı
    // `checkedAutoItemKeys`'e kaydedildi.
    grouped = ShoppingListService.buildShoppingList(plan);
    final onionEntryAfter = grouped[IngredientCategory.produce]!.first;
    expect(onionEntryAfter.ingredient.isChecked, isTrue);
    expect(plan.checkedAutoItemKeys, contains(IngredientAggregatorService.mergeKeyFor(onionEntry.ingredient)));
  });

  test('Manuel ürün ekleme, listeye görünür ve doğru kategoriye düşmeli', () {
    final plan = WeeklyPlan(id: 'p2', weekStartDate: DateTime(2026, 8, 10));

    ShoppingListService.addManualItem(
      plan: plan,
      name: 'Bulaşık Deterjanı',
      quantity: 1,
      unit: 'adet',
      category: IngredientCategory.other,
    );

    final grouped = ShoppingListService.buildShoppingList(plan);
    expect(grouped[IngredientCategory.other], isNotNull);
    expect(grouped[IngredientCategory.other]!.single.ingredient.name, 'Bulaşık Deterjanı');
    expect(grouped[IngredientCategory.other]!.single.isManual, isTrue);
  });

  test('Manuel ürün işaretlenip kaldırılabilmeli', () {
    final plan = WeeklyPlan(id: 'p3', weekStartDate: DateTime(2026, 8, 10));
    ShoppingListService.addManualItem(
      plan: plan,
      name: 'Peçete',
      quantity: 1,
      unit: 'paket',
      category: IngredientCategory.pantry,
    );

    final entry = ShoppingListService.buildShoppingList(plan)[IngredientCategory.pantry]!.single;
    ShoppingListService.toggleChecked(plan, entry);
    expect(entry.ingredient.isChecked, isTrue);

    ShoppingListService.removeManualItem(plan, entry.ingredient);
    final groupedAfterRemoval = ShoppingListService.buildShoppingList(plan);
    expect(groupedAfterRemoval[IngredientCategory.pantry], isNull);
  });

  test('Otomatik ve manuel ürünler aynı listede birlikte görünebilmeli', () {
    final plan = WeeklyPlan(id: 'p4', weekStartDate: DateTime(2026, 8, 10));
    plan.mealFor(DayOfWeek.tuesday, MealType.lunch).recipe = buildRecipe([
      Ingredient(name: 'Domates', quantity: 2, unit: 'adet', category: IngredientCategory.produce),
    ]);
    ShoppingListService.addManualItem(
      plan: plan,
      name: 'Limon',
      quantity: 1,
      unit: 'adet',
      category: IngredientCategory.produce,
    );

    final entries = ShoppingListService.buildShoppingList(plan)[IngredientCategory.produce]!;
    expect(entries.length, 2);
    expect(entries.where((e) => e.isManual).length, 1);
    expect(entries.where((e) => !e.isManual).length, 1);
  });
}
