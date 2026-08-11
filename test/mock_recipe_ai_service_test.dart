import 'package:flutter_test/flutter_test.dart';
import 'package:plan_to_plate/data/models/recipe.dart';
import 'package:plan_to_plate/data/services/mock_recipe_ai_service.dart';

/// Bu test dosyası, `MockRecipeAiService`'in doğru çalıştığını KANITLAR.
/// Yazılım bilmeyen biri için bile önemli: Bu testler yeşil (başarılı)
/// göründüğü sürece, "Adım 2" bittiğinde sistemin gerçekten çalıştığından
/// eminiz — arayüzü (ekranları) henüz yazmadan bile.
///
/// Çalıştırmak için: `flutter test test/mock_recipe_ai_service_test.dart`
void main() {
  final service = MockRecipeAiService();

  test('Bilinen bir yemek adı (Menemen) doğru tarifle eşleşmeli', () async {
    final recipe = await service.generateRecipe(
      id: 'test-1',
      mealName: 'Menemen',
      mealType: MealType.breakfast,
    );

    expect(recipe.title, 'Menemen');
    expect(recipe.mealType, MealType.breakfast);
    expect(recipe.ingredients, isNotEmpty);
    expect(recipe.steps, isNotEmpty);
    expect(recipe.nutrient.calories, greaterThan(0));
  });

  test('Türkçe karakter/büyük-küçük harf farkı eşleşmeyi bozmamalı', () async {
    final recipe = await service.generateRecipe(
      id: 'test-2',
      mealName: 'FIRINDA TAVUK BUT',
      mealType: MealType.dinner,
    );

    expect(recipe.title, 'Fırında Tavuk But');
  });

  test('Veri setinde olmayan bir yemek adı bile HATA VERMEMELİ ve bir tarif dönmeli', () async {
    final recipe = await service.generateRecipe(
      id: 'test-3',
      mealName: 'Uzayda Pizza',
      mealType: MealType.lunch,
    );

    expect(recipe.title, isNotEmpty);
    expect(recipe.ingredients, isNotEmpty);
  });

  test('Aynı bilinmeyen yemek adı her zaman AYNI yedek tarifi vermeli (deterministik)', () async {
    final first = await service.generateRecipe(
      id: 'test-4a',
      mealName: 'Bilinmeyen Yemek 123',
      mealType: MealType.lunch,
    );
    final second = await service.generateRecipe(
      id: 'test-4b',
      mealName: 'Bilinmeyen Yemek 123',
      mealType: MealType.lunch,
    );

    expect(first.title, second.title);
  });
}
