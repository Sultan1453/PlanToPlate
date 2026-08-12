import 'dart:typed_data';

import '../../core/utils/turkish_text_utils.dart';
import '../models/recipe.dart';
import 'mock_recipe_dataset.dart';
import 'recipe_ai_service.dart';

/// `RecipeAiService` sözleşmesinin, İNTERNETE HİÇ BAĞLANMADAN çalışan sahte
/// (mock) uygulaması.
///
/// Kullanıcının yazdığı yemek adını `mockRecipeDataset` içindeki 9 popüler
/// yemekle karşılaştırır; bir eşleşme bulursa o tarifi döner. Eşleşme
/// bulamazsa (kullanıcı veri setinde OLMAYAN bir şey yazdıysa) uygulama asla
/// çökmez veya hata göstermez — bunun yerine, yazdığı metne göre SABİT
/// (deterministik) bir yemek seçip onu döner. "Deterministik" olması önemli:
/// aynı kelimeyi her yazışında hep AYNI tarif gelir, rastgelelik kafa
/// karıştırmaz.
class MockRecipeAiService implements RecipeAiService {
  @override
  Future<Recipe> generateRecipe({
    required String id,
    required String mealName,
    required MealType mealType,
  }) async {
    // Gerçek bir API çağrısının 1 saniye kadar sürebileceğini simüle
    // ediyoruz. Bu, ekranımızda "yükleniyor" göstergesini (spinner) test
    // etmemizi sağlar; ileride gerçek Gemini API'sine geçtiğimizde ekran
    // kodunda HİÇBİR değişiklik gerekmeyecek çünkü zaten "asenkron/bekleme
    // var" senaryosuna göre yazılmış olacak.
    await Future.delayed(const Duration(milliseconds: 900));

    final normalizedInput = normalizeTurkish(mealName);

    final matchedEntry =
        _findByKeyword(normalizedInput) ?? _pickDeterministicFallback(normalizedInput);

    // `Recipe.fromJson`, hem bu mock veriyi hem de gerçek Gemini API'sinden
    // gelecek JSON'ı AYNI ŞEKİLDE okuyabilir; çünkü ikisi de aynı formatta
    // (title/ingredients/steps/nutrient/...) yazılmıştır.
    return Recipe.fromJson(matchedEntry, id: id, mealType: mealType);
  }

  @override
  Future<Recipe> generateRecipeFromPhoto({
    required String id,
    required Uint8List imageBytes,
    required String mimeType,
    required MealType mealType,
  }) async {
    // Mock modda gerçek görüntü tanıma yok; fotoğraf baytlarının toplamına
    // göre deterministik bir tarif seçeriz ki her denemede aynı fotoğraf
    // aynı sonucu versin. Gerçek Gemini anahtarı eklenince bu yol otomatik
    // olarak gerçek görüntü analizine geçer.
    await Future.delayed(const Duration(milliseconds: 900));
    final fingerprint = imageBytes.fold<int>(0, (sum, b) => sum + b);
    final index = fingerprint % mockRecipeDataset.length;
    final entry = Map<String, dynamic>.from(mockRecipeDataset[index]);
    entry['title'] = '${entry['title']} (Fotoğraftan)';
    return Recipe.fromJson(entry, id: id, mealType: mealType);
  }

  /// Veri setindeki her yemeğin `keywords` listesini tarar; kullanıcının
  /// yazdığı (normalize edilmiş) metin bu kelimelerden birini İÇERİYORSA
  /// (`contains`) o yemeği eşleşmiş sayar.
  Map<String, dynamic>? _findByKeyword(String normalizedInput) {
    for (final entry in mockRecipeDataset) {
      final keywords = entry['keywords'] as List<String>;
      for (final keyword in keywords) {
        if (normalizedInput.contains(normalizeTurkish(keyword))) {
          return entry;
        }
      }
    }
    return null;
  }

  /// Hiçbir kelime eşleşmediğinde çağrılır. Kullanıcının yazdığı metnin
  /// harflerini sayısal bir değere çevirip deterministik indeks üretir.
  Map<String, dynamic> _pickDeterministicFallback(String normalizedInput) {
    if (normalizedInput.isEmpty) return mockRecipeDataset.first;
    final sumOfCharCodes = normalizedInput.codeUnits.fold<int>(
      0,
      (total, charCode) => total + charCode,
    );
    final index = sumOfCharCodes % mockRecipeDataset.length;
    return mockRecipeDataset[index];
  }
}
