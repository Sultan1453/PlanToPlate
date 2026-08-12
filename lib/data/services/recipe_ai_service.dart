import 'dart:typed_data';

import '../models/recipe.dart';

/// Bir `RecipeAiService` uygulaması (özellikle gerçek Gemini motoru) tarif
/// üretemediğinde fırlatılan, KULLANICIYA GÖSTERİLMEYE HAZIR (Türkçe,
/// anlaşılır) bir hata.
///
/// NEDEN ÖZEL BİR HATA SINIFI? Gemini API'sinden dönebilecek teknik hatalar
/// (ağ zaman aşımı, geçersiz API anahtarı, sunucu hatası, bozuk JSON...)
/// çok çeşitlidir ve İngilizce/teknik mesajlar içerir. Ekranın (UI'ın) bu
/// teknik detaylarla hiç ilgilenmesine gerek yok; sadece kullanıcıya
/// gösterilecek TEK, temiz bir Türkçe mesaj (`message`) ile ilgilenir.
class RecipeGenerationException implements Exception {
  RecipeGenerationException(this.message);

  /// Kullanıcıya doğrudan gösterilebilecek, Türkçe hata mesajı.
  final String message;

  @override
  String toString() => message;
}

/// "Bir yemek adından veya fotoğraftan tarif üreten herhangi bir motorun
/// uyması gereken sözleşme" (contract/interface).
abstract class RecipeAiService {
  /// Verilen yemek adı (`mealName`) için yapay zekadan/yerel veri setinden
  /// tam bir tarif üretir.
  Future<Recipe> generateRecipe({
    required String id,
    required String mealName,
    required MealType mealType,
  });

  /// Kullanıcının çektiği/galeriden seçtiği yemek fotoğrafından tarif üretir.
  ///
  /// `imageBytes`: fotoğrafın ham baytları (JPEG/PNG).
  /// `mimeType`: örn. `image/jpeg` veya `image/png`.
  Future<Recipe> generateRecipeFromPhoto({
    required String id,
    required Uint8List imageBytes,
    required String mimeType,
    required MealType mealType,
  });
}
