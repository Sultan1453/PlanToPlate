import 'dart:convert';

import 'package:google_generative_ai/google_generative_ai.dart';

import '../models/recipe.dart';
import 'recipe_ai_service.dart';

/// `RecipeAiService` sözleşmesinin GERÇEK Google Gemini API'sini kullanan
/// uygulaması.
///
/// Adım 2'de yazdığımız `MockRecipeAiService` ile bu sınıfın ekrana giden
/// arayüzü (metod imzası) TAMAMEN AYNIDIR — çünkü ikisi de aynı
/// `RecipeAiService` sözleşmesini uygular. Aralarındaki tek fark, tarifi
/// NEREDEN aldıklarıdır: biri sabit bir listeden, biri gerçek yapay
/// zekadan. Bu sayede Adım 2'de kurduğumuz "tek satırda motor değiştirme"
/// planı burada meyvesini veriyor.
class GeminiRecipeAiService implements RecipeAiService {
  GeminiRecipeAiService({required String apiKey})
    : _model = GenerativeModel(
        model: _modelName,
        apiKey: apiKey,
        // `responseMimeType: 'application/json'`: Gemini'ye "cevabını
        // SADECE geçerli JSON olarak ver, düz metin/markdown karıştırma"
        // diyoruz. Bu, "JSON Modu" olarak bilinir ve modelin bizim
        // beklediğimiz formatı bozma ihtimalini büyük ölçüde azaltır.
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          // Daha düşük sıcaklık (temperature), modelin daha "tutarlı ve
          // tahmin edilebilir" cevaplar vermesini sağlar; bir tarif
          // üretirken yaratıcılıktan çok DOĞRULUK/TUTARLILIK önemlidir.
          temperature: 0.6,
        ),
      );

  /// Kullanılan Gemini model adı. Google zaman zaman yeni model sürümleri
  /// çıkarır; ileride daha yeni/güçlü bir modele geçmek istersen SADECE bu
  /// satırı değiştirmen yeterli olacak.
  static const String _modelName = 'gemini-2.5-flash';

  final GenerativeModel _model;

  @override
  Future<Recipe> generateRecipe({
    required String id,
    required String mealName,
    required MealType mealType,
  }) async {
    try {
      final response = await _model.generateContent([
        Content.text(_buildPrompt(mealName)),
      ]);

      final rawText = response.text;
      if (rawText == null || rawText.trim().isEmpty) {
        throw RecipeGenerationException(
          'Yapay zeka boş bir cevap döndürdü. Lütfen tekrar dene.',
        );
      }

      final decodedJson = jsonDecode(_stripMarkdownFences(rawText)) as Map<String, dynamic>;
      return Recipe.fromJson(decodedJson, id: id, mealType: mealType);
    } on RecipeGenerationException {
      // Kendi fırlattığımız hatayı (yukarıdaki "boş cevap" durumu gibi)
      // olduğu gibi yukarı iletiyoruz; aşağıdaki genel `catch` bloğu
      // tarafından tekrar SARILMASINI istemiyoruz.
      rethrow;
    } on FormatException {
      // `jsonDecode` bozuk/eksik bir JSON ile karşılaşırsa bu hatayı verir.
      throw RecipeGenerationException(
        'Yapay zekadan gelen cevap okunamadı. Lütfen tekrar dene.',
      );
    } on InvalidApiKey {
      throw RecipeGenerationException(
        'Gemini API anahtarı geçersiz. Lütfen .env dosyandaki '
        'GEMINI_API_KEY değerini kontrol et.',
      );
    } on GenerativeAIException {
      // Sunucu hatası, konum kısıtlaması gibi Gemini'ye özgü diğer TÜM
      // hatalar için ortak, anlaşılır bir mesaj gösteriyoruz.
      throw RecipeGenerationException(
        'Yapay zeka servisine şu an ulaşılamıyor. Lütfen daha sonra tekrar dene.',
      );
    } catch (_) {
      // Buraya genellikle İNTERNET BAĞLANTISI olmadığında düşülür
      // (örn. `SocketException`). Kullanıcıya teknik terim göstermek
      // yerine en olası nedeni söylüyoruz.
      throw RecipeGenerationException(
        'İnternet bağlantında bir sorun olabilir. Lütfen bağlantını '
        'kontrol edip tekrar dene.',
      );
    }
  }

  /// Gemini'ye JSON modu istesek de, model bazen cevabı yine de
  /// ```json ... ``` gibi bir markdown kod bloğunun içine sarabilir. Bu
  /// yardımcı fonksiyon, `jsonDecode` çağırmadan ÖNCE bu sarmalayıcıyı
  /// güvenle temizler; yoksa dokunmadan olduğu gibi bırakır.
  String _stripMarkdownFences(String text) {
    var trimmed = text.trim();
    if (trimmed.startsWith('```')) {
      trimmed = trimmed.replaceFirst(RegExp(r'^```[a-zA-Z]*\n?'), '');
      trimmed = trimmed.replaceFirst(RegExp(r'```\s*$'), '');
    }
    return trimmed.trim();
  }

  /// Gemini'ye gönderilecek tam talimat metni (prompt).
  ///
  /// Burada ÇOK NET bir JSON şablonu ve kurallar veriyoruz; çünkü AI'dan
  /// gelen cevabı doğrudan Adım 1'de yazdığımız `Recipe.fromJson` fabrikasına
  /// besleyeceğiz — alan adları (title, ingredients, steps, nutrient,
  /// cookingMethod...) ve değer seçenekleri (örn. "airfryer", "produce")
  /// `Recipe`/`Ingredient` modelleriyle BİREBİR uyuşmalı.
  String _buildPrompt(String mealName) {
    return '''
Sen profesyonel bir Türk mutfağı şefi ve diyetisyensin. Kullanıcının istediği
yemek için, SADECE aşağıdaki JSON şablonuna uyan, başka HİÇBİR açıklama,
markdown işaretleyici veya yorum içermeyen bir cevap üret.

İstenen yemek: "$mealName"

JSON şablonu (TÜM alanlar zorunludur):
{
  "title": "Yemeğin düzgün yazılmış tam adı",
  "servings": <kaç kişilik olduğu, tam sayı>,
  "prepTimeMinutes": <hazırlık süresi, dakika, tam sayı>,
  "cookTimeMinutes": <pişirme süresi, dakika, tam sayı>,
  "cookingMethod": "<airfryer | oven | stovetop | grill | no_cook | other>",
  "nutrient": {
    "calories": <1 porsiyon başına kalori, sayı>,
    "protein": <1 porsiyon başına protein (gram), sayı>,
    "carbs": <1 porsiyon başına karbonhidrat (gram), sayı>,
    "fat": <1 porsiyon başına yağ (gram), sayı>
  },
  "ingredients": [
    {
      "name": "Malzeme adı (Türkçe, örn. Soğan)",
      "quantity": <sayı>,
      "unit": "adet | gram | yemek kaşığı | su bardağı | tatlı kaşığı | tutam | dilim | kutu | paket | litre",
      "category": "<produce | butcher | dairy | pantry | bakery | other>"
    }
  ],
  "steps": ["1. adımın açıklaması", "2. adımın açıklaması", "..."]
}

Kurallar:
- "cookingMethod": bu yemeğin en lezzetli/pratik pişirileceği YÖNTEMİ seç.
  Pişirme gerektirmiyorsa (salata gibi) "no_cook" kullan.
- "category": malzemenin market reyonunu belirtir — sebze/meyve: produce,
  et/tavuk/balık: butcher, süt ürünleri/yumurta: dairy,
  bakliyat/konserve/baharat/kuru gıda: pantry, ekmek/unlu mamul: bakery,
  hiçbirine uymuyorsa: other.
- Besin değerleri GERÇEKÇİ tahminler olmalı ve HER ZAMAN 1 porsiyona göre
  hesaplanmalı (toplam tencere değil).
- Cevabında SADECE geçerli JSON olsun; ```json kod bloğu, açıklama cümlesi
  veya ekstra metin EKLEME.
''';
  }
}
