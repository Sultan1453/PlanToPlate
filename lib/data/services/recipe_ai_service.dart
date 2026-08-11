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

/// "Bir yemek adından tarif üreten herhangi bir motorun uyması gereken
/// sözleşme" (contract/interface).
///
/// BU SINIF NEDEN ÖNEMLİ? Bugün `MockRecipeAiService` (sahte, yerel veri
/// tabanlı) motoru kullanıyoruz; Adım 5'te gerçek Google Gemini API'sine
/// bağlandığımızda `GeminiRecipeAiService` adında YENİ bir sınıf yazacağız.
/// Eğer uygulamanın diğer bölümleri (ekranlar) doğrudan
/// "MockRecipeAiService" sınıfını tanısaydı, Gemini'ye geçerken o
/// ekranlardaki KOD SATIRLARINI da değiştirmemiz gerekirdi.
///
/// Bunun yerine ekranlar sadece bu soyut (abstract) `RecipeAiService`
/// sözleşmesini tanır. Hangi motorun ("Mock" mu "Gemini" mi) gerçekten
/// çalıştığı, sadece TEK bir satırda (bağımlılık enjeksiyonu / dependency
/// injection noktasında, `mock_recipe_ai_service.dart` dosyasının en
/// altındaki `recipeAiServiceProvider`da) belirlenir. Böylece motoru
/// değiştirmek, uygulamanın geri kalanını hiç etkilemez.
///
/// Bu yaklaşıma yazılımda "Clean Architecture" / "Dependency Inversion"
/// (Bağımlılığın Tersine Çevrilmesi) prensibi denir: üst seviye kod (ekranlar)
/// alt seviye detaylara (Mock mu, Gemini mi) değil, ORTAK BİR SÖZLEŞMEYE
/// bağımlı olur.
abstract class RecipeAiService {
  /// Verilen yemek adı (`mealName`) için yapay zekadan/yerel veri setinden
  /// tam bir tarif üretir.
  ///
  /// - `id`: Üretilecek `Recipe` nesnesine verilecek benzersiz kimlik.
  ///   Bunu motor KENDİSİ üretmez; çağıran taraf (ekran/repository) verir,
  ///   çünkü hangi haftalık plan hücresine ait olduğunu sadece o bilir.
  /// - `mealName`: Kullanıcının yazdığı veya seçtiği yemek adı. Örn: "Fırında
  ///   Tavuk But".
  /// - `mealType`: Bu tarifin Kahvaltı/Öğle/Akşam için üretildiği bilgisi.
  ///
  /// Dönüş tipi `Future<Recipe>` olduğu için bu metod ASENKRON'dur (zaman
  /// alabilir); hem gerçek API çağrısı hem de (kullanıcı deneyimini gerçekçi
  /// tutmak için gecikme simüle eden) mock motoru bu şekilde çalışır.
  Future<Recipe> generateRecipe({
    required String id,
    required String mealName,
    required MealType mealType,
  });
}
