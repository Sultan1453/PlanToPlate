import 'dart:convert';
import 'dart:typed_data';

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

  /// Kullanılan Gemini model adı. Yeni Google AI Studio hesaplarında
  /// `gemini-2.5-flash` artık kapatıldığı için (API 404 döner), hızlı ve
  /// ücretsiz kota dostu `gemini-2.5-flash-lite` modelini kullanıyoruz.
  static const String _modelName = 'gemini-2.5-flash-lite';

  final GenerativeModel _model;

  @override
  Future<Recipe> generateRecipe({
    required String id,
    required String mealName,
    required MealType mealType,
  }) async {
    return _generateFromContents(
      contents: [Content.text(_buildTextPrompt(mealName))],
      id: id,
      mealType: mealType,
    );
  }

  @override
  Future<Recipe> generateRecipeFromPhoto({
    required String id,
    required Uint8List imageBytes,
    required String mimeType,
    required MealType mealType,
  }) async {
    // Multimodal içerik: metin talimat + fotoğraf baytları birlikte gider.
    // Gemini görüntüyü okuyup yemeği tanır ve aynı JSON şablonunda tarif üretir.
    return _generateFromContents(
      contents: [
        Content.multi([
          TextPart(_buildPhotoPrompt(mealType)),
          DataPart(mimeType, imageBytes),
        ]),
      ],
      id: id,
      mealType: mealType,
    );
  }

  Future<Recipe> _generateFromContents({
    required List<Content> contents,
    required String id,
    required MealType mealType,
  }) async {
    try {
      final response = await _model.generateContent(contents);

      final rawText = response.text;
      if (rawText == null || rawText.trim().isEmpty) {
        throw RecipeGenerationException(
          'Yapay zeka boş bir cevap döndürdü. Lütfen tekrar dene.',
        );
      }

      final decodedJson = jsonDecode(_stripMarkdownFences(rawText)) as Map<String, dynamic>;
      return Recipe.fromJson(decodedJson, id: id, mealType: mealType);
    } on RecipeGenerationException {
      rethrow;
    } on FormatException {
      throw RecipeGenerationException(
        'Yapay zekadan gelen cevap okunamadı. Lütfen tekrar dene.',
      );
    } on InvalidApiKey {
      throw RecipeGenerationException(
        'Gemini API anahtarı geçersiz. Lütfen .env dosyandaki '
        'GEMINI_API_KEY değerini kontrol et.',
      );
    } on GenerativeAIException {
      throw RecipeGenerationException(
        'Yapay zeka servisine şu an ulaşılamıyor. Lütfen daha sonra tekrar dene.',
      );
    } catch (_) {
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

  String _jsonSchemaInstructions() {
    return '''
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

  String _buildTextPrompt(String mealName) {
    return '''
Sen profesyonel bir Türk mutfağı şefi ve diyetisyensin. Kullanıcının istediği
yemek için, SADECE aşağıdaki JSON şablonuna uyan, başka HİÇBİR açıklama,
markdown işaretleyici veya yorum içermeyen bir cevap üret.

İstenen yemek: "$mealName"

${_jsonSchemaInstructions()}
''';
  }

  String _buildPhotoPrompt(MealType mealType) {
    return '''
Sen profesyonel bir Türk mutfağı şefi ve diyetisyensin. Kullanıcı bir YEMEK
FOTOĞRAFI gönderdi. Fotoğraftaki yemeği tanı (veya en yakın makul tahmini
yap) ve bu yemek için SADECE aşağıdaki JSON şablonuna uyan bir tarif üret.

Bu tarif "${mealType.displayName}" öğünü için planlanacak.
Fotoğrafta yemek görünmüyorsa, yine de makul bir günlük yemek tarifi üret
ama title alanına "(Fotoğraftan tahmin)" ekle.

${_jsonSchemaInstructions()}
''';
  }
}
