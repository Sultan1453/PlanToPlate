import 'dart:convert';
import 'dart:typed_data';

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:uuid/uuid.dart';

import '../models/fridge_suggestion.dart';
import '../models/recipe.dart';
import '../models/recipe_constraints.dart';
import 'recipe_ai_service.dart';
import 'snack_discover_catalog.dart';

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
    RecipeConstraints constraints = const RecipeConstraints(),
  }) async {
    return _generateFromContents(
      contents: [Content.text(_buildTextPrompt(mealName, constraints))],
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
    RecipeConstraints constraints = const RecipeConstraints(),
  }) async {
    return _generateFromContents(
      contents: [
        Content.multi([
          TextPart(_buildPhotoPrompt(mealType, constraints)),
          DataPart(mimeType, imageBytes),
        ]),
      ],
      id: id,
      mealType: mealType,
    );
  }

  @override
  Future<FridgeSuggestionResult> suggestFromIngredients({
    required List<String> ingredients,
    RecipeConstraints constraints = const RecipeConstraints(),
  }) async {
    final list = ingredients.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (list.isEmpty) {
      throw RecipeGenerationException('Öneri için en az bir malzeme ekle.');
    }

    try {
      final response = await _model.generateContent([
        Content.text(_buildFridgePrompt(list, constraints)),
      ]);
      final rawText = response.text;
      if (rawText == null || rawText.trim().isEmpty) {
        throw RecipeGenerationException(
          'Yapay zeka boş bir cevap döndürdü. Lütfen tekrar dene.',
        );
      }

      final decoded = jsonDecode(_stripMarkdownFences(rawText));
      if (decoded is! Map<String, dynamic>) {
        throw RecipeGenerationException(
          'Yapay zekadan gelen cevap beklenen formatta değil. Lütfen tekrar dene.',
        );
      }

      final recipesRaw = decoded['recipes'];
      if (recipesRaw is! List || recipesRaw.isEmpty) {
        throw RecipeGenerationException(
          'Bu malzemelerle tarif üretilemedi. Birkaç ürün daha ekleyip dene.',
        );
      }

      const uuid = Uuid();
      final recipes = <Recipe>[];
      for (final item in recipesRaw.take(3)) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final mealType = MealType.fromString(map['mealType']?.toString());
        recipes.add(
          Recipe.fromJson(map, id: uuid.v4(), mealType: mealType),
        );
      }
      if (recipes.isEmpty) {
        throw RecipeGenerationException(
          'Bu malzemelerle tarif üretilemedi. Birkaç ürün daha ekleyip dene.',
        );
      }

      final buys = <SuggestedBuy>[];
      final buysRaw = decoded['suggested_buys'];
      if (buysRaw is List) {
        for (final item in buysRaw.take(6)) {
          if (item is Map) {
            final name = item['name']?.toString().trim() ?? '';
            if (name.isEmpty) continue;
            buys.add(
              SuggestedBuy(
                name: name,
                reason: item['reason']?.toString(),
              ),
            );
          } else if (item is String && item.trim().isNotEmpty) {
            buys.add(SuggestedBuy(name: item.trim()));
          }
        }
      }

      return FridgeSuggestionResult(
        recipes: recipes,
        suggestedBuys: buys,
        note: decoded['note']?.toString(),
      );
    } on RecipeGenerationException {
      rethrow;
    } on FormatException {
      throw RecipeGenerationException(
        'Yapay zekadan gelen cevap okunamadı. Lütfen tekrar dene.',
      );
    } on TypeError {
      throw RecipeGenerationException(
        'Yapay zekadan gelen cevap beklenen formatta değil. Lütfen tekrar dene.',
      );
    } on InvalidApiKey {
      throw RecipeGenerationException(
        'Gemini API anahtarı geçersiz. Lütfen GEMINI_API_KEY değerini '
        '(.env + scripts/run_dev.ps1) kontrol et.',
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

      final decoded = jsonDecode(_stripMarkdownFences(rawText));
      if (decoded is! Map<String, dynamic>) {
        throw RecipeGenerationException(
          'Yapay zekadan gelen cevap beklenen formatta değil. Lütfen tekrar dene.',
        );
      }
      return Recipe.fromJson(decoded, id: id, mealType: mealType);
    } on RecipeGenerationException {
      rethrow;
    } on FormatException {
      throw RecipeGenerationException(
        'Yapay zekadan gelen cevap okunamadı. Lütfen tekrar dene.',
      );
    } on TypeError {
      throw RecipeGenerationException(
        'Yapay zekadan gelen cevap beklenen formatta değil. Lütfen tekrar dene.',
      );
    } on InvalidApiKey {
      throw RecipeGenerationException(
        'Gemini API anahtarı geçersiz. Lütfen GEMINI_API_KEY değerini '
        '(.env + scripts/run_dev.ps1) kontrol et.',
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

  @override
  Future<List<Recipe>> generateQuickSnacks({
    int count = 5,
    FeedMood mood = FeedMood.all,
    List<String> excludeTitles = const [],
    int? varietySeed,
  }) async {
    final n = count.clamp(1, 8);
    final seed = varietySeed ?? DateTime.now().millisecondsSinceEpoch;
    try {
      final response = await _model.generateContent([
        Content.text(_buildQuickSnackPrompt(n, mood, excludeTitles, seed)),
      ]);
      final rawText = response.text;
      if (rawText == null || rawText.trim().isEmpty) {
        throw RecipeGenerationException('Boş cevap. Tekrar dene.');
      }
      final decoded = jsonDecode(_stripMarkdownFences(rawText));
      if (decoded is! Map<String, dynamic>) {
        throw RecipeGenerationException('Beklenmeyen format.');
      }
      final list = decoded['recipes'];
      if (list is! List || list.isEmpty) {
        throw RecipeGenerationException('Atıştırmalık üretilemedi.');
      }
      const uuid = Uuid();
      final recipes = <Recipe>[];
      final seen = <String>{};
      for (final item in list) {
        if (recipes.length >= n) break;
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final title = map['title']?.toString().trim() ?? '';
        if (title.isEmpty) continue;
        final key = title.toLowerCase();
        if (!seen.add(key)) continue;
        recipes.add(
          Recipe.fromJson(map, id: uuid.v4(), mealType: MealType.snack),
        );
      }
      if (recipes.isEmpty) {
        throw RecipeGenerationException('Atıştırmalık üretilemedi.');
      }
      return recipes;
    } on RecipeGenerationException {
      rethrow;
    } on InvalidApiKey {
      throw RecipeGenerationException(
        'Gemini API anahtarı geçersiz. Lütfen GEMINI_API_KEY değerini kontrol et.',
      );
    } on GenerativeAIException {
      throw RecipeGenerationException(
        'Yapay zeka servisine ulaşılamıyor. Daha sonra dene.',
      );
    } catch (_) {
      throw RecipeGenerationException(
        'Atıştırmalıklar alınamadı. Bağlantını kontrol et.',
      );
    }
  }

  @override
  Future<List<Recipe>> generateDiscoverRecipes({
    int count = 10,
    FeedMood mood = FeedMood.all,
    MealType? mealType,
    List<String> excludeTitles = const [],
    int? varietySeed,
  }) async {
    final n = count.clamp(1, 12);
    final seed = varietySeed ?? DateTime.now().millisecondsSinceEpoch;
    try {
      final response = await _model.generateContent([
        Content.text(
          _buildDiscoverPrompt(n, mood, mealType, excludeTitles, seed),
        ),
      ]);
      final rawText = response.text;
      if (rawText == null || rawText.trim().isEmpty) {
        throw RecipeGenerationException('Boş cevap. Tekrar dene.');
      }
      final decoded = jsonDecode(_stripMarkdownFences(rawText));
      if (decoded is! Map<String, dynamic>) {
        throw RecipeGenerationException('Beklenmeyen format.');
      }
      final list = decoded['recipes'];
      if (list is! List || list.isEmpty) {
        throw RecipeGenerationException('Keşfet tarifleri üretilemedi.');
      }
      const uuid = Uuid();
      final recipes = <Recipe>[];
      final seen = <String>{};
      for (final item in list) {
        if (recipes.length >= n) break;
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final title = map['title']?.toString().trim() ?? '';
        if (title.isEmpty) continue;
        if (!seen.add(title.toLowerCase())) continue;
        final mt = mealType ?? MealType.fromString(map['mealType']?.toString());
        recipes.add(Recipe.fromJson(map, id: uuid.v4(), mealType: mt));
      }
      if (recipes.isEmpty) {
        throw RecipeGenerationException('Keşfet tarifleri üretilemedi.');
      }
      return recipes;
    } on RecipeGenerationException {
      rethrow;
    } on InvalidApiKey {
      throw RecipeGenerationException(
        'Gemini API anahtarı geçersiz. Lütfen GEMINI_API_KEY değerini kontrol et.',
      );
    } on GenerativeAIException {
      throw RecipeGenerationException(
        'Yapay zeka servisine ulaşılamıyor. Daha sonra dene.',
      );
    } catch (_) {
      throw RecipeGenerationException(
        'Keşfet tarifleri alınamadı. Bağlantını kontrol et.',
      );
    }
  }

  String _moodHint(FeedMood mood) {
    switch (mood) {
      case FeedMood.all:
        return 'karışık ve sürpriz dolu olsun; aynı tarza takılma';
      case FeedMood.salty:
        return 'tuzlu / tuzlu-acı / umami ağırlıklı';
      case FeedMood.sweet:
        return 'tatlı / hafif tatlı krizi';
      case FeedMood.protein:
        return 'protein odaklı (yumurta, yoğurt, baklagil, et/balık)';
      case FeedMood.cold:
        return 'soğuk veya pişirmesiz (no_cook tercihen)';
      case FeedMood.breadTop:
        return 'ekmek / toast / lavaş üzeri pratik';
      case FeedMood.quick:
        return 'toplam süre mümkün olduğunca kısa';
      case FeedMood.light:
        return 'hafif, düşük kalori hissi';
      case FeedMood.comfort:
        return 'doyurucu, rahatlatıcı';
    }
  }

  String _buildQuickSnackPrompt(
    int count,
    FeedMood mood,
    List<String> excludeTitles,
    int seed,
  ) {
    final avoid = excludeTitles.take(20).join(', ');
    final angles = [
      'Ege usulü',
      'öğrenci evi',
      'fitness ara öğün',
      'çocuk dostu',
      'airfryer yok',
      'sadece buzdolabı',
      'kahvaltılık tarz',
      'sinema molası',
    ];
    final angle = angles[seed % angles.length];
    return '''
Sen bir Türk mutfağı gece atıştırmalığı asistanısın.
Tam $count ADET FARKLI tarif öner. Tekrar yok, benzer isimler yok.
Çeşitlilik tohumu: $seed · açı: $angle
Ruh hali: ${_moodHint(mood)}
Kurallar:
- Toplam süre (hazırlık + pişirme) EN FAZLA 10 dakika
- Az malzeme (max 6)
- Evde sık bulunan ürünler
- mealType her zaman "snack"
- cookingMethod: "no_cook" | "stovetop" | "other"
- Türkçe yaz
${avoid.isEmpty ? '' : '- Şu başlıklara BENZEME / tekrar etme: $avoid'}
- SADECE JSON:
{
  "recipes": [
    {
      "title": "...",
      "mealType": "snack",
      "servings": 1,
      "prepTimeMinutes": <n>,
      "cookTimeMinutes": <n>,
      "cookingMethod": "no_cook|stovetop|other",
      "nutrient": {"calories": <n>, "protein": <n>, "carbs": <n>, "fat": <n>},
      "ingredients": [{"name":"...","quantity":1,"unit":"adet","category":"dairy"}],
      "steps": ["..."]
    }
  ]
}
''';
  }

  String _buildDiscoverPrompt(
    int count,
    FeedMood mood,
    MealType? mealType,
    List<String> excludeTitles,
    int seed,
  ) {
    final avoid = excludeTitles.take(24).join(', ');
    final cuisines = [
      'Türk ev yemeği',
      'Akdeniz',
      'Anadolu',
      'hafif fit',
      'öğrenci bütçesi',
      'tek tava',
      'fırın odaklı',
      'vejetaryen',
    ];
    final cuisine = cuisines[seed % cuisines.length];
    final mealHint = mealType == null
        ? 'Kahvaltı, öğle, akşam ve atıştırmalığı karıştır'
        : 'Hepsi ${mealType.name} / ${mealType.displayName} için olsun';
    return '''
Sen PlanToPlate keşfet motorusun. Tam $count ADET birbirinden farklı tarif üret.
Çeşitlilik tohumu: $seed · mutfak açısı: $cuisine
Ruh hali: ${_moodHint(mood)}
$mealHint
Kurallar:
- Başlıklar benzersiz olsun, klasik "Menemen/Omlet/Mercimek" klişesine sıkışma
- mealType: breakfast|lunch|dinner|snack
- Türkçe yaz, gerçekçi malzeme ve adımlar
${avoid.isEmpty ? '' : '- Bunlara benzeme / tekrar etme: $avoid'}
- SADECE JSON:
{
  "recipes": [
    {
      "title": "...",
      "mealType": "breakfast|lunch|dinner|snack",
      "servings": 2,
      "prepTimeMinutes": <n>,
      "cookTimeMinutes": <n>,
      "cookingMethod": "stovetop|oven|no_cook|grill|airfryer|other",
      "nutrient": {"calories": <n>, "protein": <n>, "carbs": <n>, "fat": <n>},
      "ingredients": [{"name":"...","quantity":1,"unit":"adet","category":"produce"}],
      "steps": ["..."]
    }
  ]
}
''';
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

  String _buildTextPrompt(String mealName, RecipeConstraints constraints) {
    return '''
Sen profesyonel bir Türk mutfağı şefi ve diyetisyensin. Kullanıcının istediği
yemek için, SADECE aşağıdaki JSON şablonuna uyan, başka HİÇBİR açıklama,
markdown işaretleyici veya yorum içermeyen bir cevap üret.

İstenen yemek: "$mealName"
${constraints.toPromptSection()}
${_jsonSchemaInstructions()}
''';
  }

  String _buildPhotoPrompt(MealType mealType, RecipeConstraints constraints) {
    return '''
Sen profesyonel bir Türk mutfağı şefi ve diyetisyensin. Kullanıcı bir YEMEK
FOTOĞRAFI gönderdi. Fotoğraftaki yemeği tanı (veya en yakın makul tahmini
yap) ve bu yemek için SADECE aşağıdaki JSON şablonuna uyan bir tarif üret.

Bu tarif "${mealType.displayName}" öğünü için planlanacak.
Fotoğrafta yemek görünmüyorsa, yine de makul bir günlük yemek tarifi üret
ama title alanına "(Fotoğraftan tahmin)" ekle.
${constraints.toPromptSection()}
${_jsonSchemaInstructions()}
''';
  }

  String _buildFridgePrompt(List<String> ingredients, RecipeConstraints constraints) {
    final joined = ingredients.map((e) => '- $e').join('\n');
    return '''
Sen profesyonel bir Türk mutfağı şefi ve pratik ev yemekleri uzmanısın.
Kullanıcının EVİNDE olan malzemelerle yapılabilecek yemekler öner.
Listedeki üstteki malzemeler öncelikli tüketilsin (bozulmaya yakın).

Evdeki malzemeler:
$joined
${constraints.toPromptSection()}
Kurallar:
1) Öncelikle SADECE listedeki malzemelerle (tuz, yağ, su, baharat gibi temel
   mutfak malzemeleri serbest) yapılabilecek 2 veya 3 tarif öner.
2) Malzeme listesi yetersizse veya tarifleri zenginleştirmek için az sayıda
   (en fazla 5) UCUZ ve KOLAY bulunan küçük ürün öner (örn. limon, yumurta,
   bir tutam maydanoz, bir kutu salça). Büyük et paketi veya pahalı ürün önerme.
3) Her tarifte ingredients listesinde hem evdekiler hem önerilen eksikleri
   birlikte yaz; kullanıcının elindekileri mümkün olduğunca kullan.
4) Türk mutfağına uygun, evde pişirilebilir tarifler olsun.
5) Cevabında SADECE geçerli JSON olsun; markdown veya ekstra metin EKLEME.

JSON şablonu:
{
  "note": "Kullanıcıya 1 kısa Türkçe cümle",
  "suggested_buys": [
    {"name": "Ürün adı", "reason": "Neden lazım (kısa)"}
  ],
  "recipes": [
    {
      "title": "...",
      "mealType": "breakfast | lunch | dinner",
      "servings": <sayı>,
      "prepTimeMinutes": <sayı>,
      "cookTimeMinutes": <sayı>,
      "cookingMethod": "<airfryer | oven | stovetop | grill | no_cook | other>",
      "nutrient": {"calories": <n>, "protein": <n>, "carbs": <n>, "fat": <n>},
      "ingredients": [
        {"name": "...", "quantity": <n>, "unit": "...", "category": "<produce|butcher|dairy|pantry|bakery|other>"}
      ],
      "steps": ["...", "..."]
    }
  ]
}
''';
  }
}
