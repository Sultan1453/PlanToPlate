import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'gemini_recipe_ai_service.dart';
import 'mock_recipe_ai_service.dart';
import 'recipe_ai_service.dart';

/// ================================================================
/// BAĞIMLILIK ENJEKSİYONU (Dependency Injection) NOKTASI
/// ================================================================
/// Uygulamanın HER YERİ, tarif üretmek istediğinde doğrudan
/// `MockRecipeAiService()` veya `GeminiRecipeAiService()` yazmaz. Bunun
/// yerine Riverpod'un bu TEK `Provider`ını kullanır:
/// `ref.read(recipeAiServiceProvider)`.
///
/// Burada, kullanıcının `.env` dosyasına GERÇEK bir Gemini API anahtarı
/// koyup koymadığına göre OTOMATİK bir karar veriyoruz:
///
/// - `.env`'de `GEMINI_API_KEY` BOŞ veya YOKSA → güvenli şekilde
///   `MockRecipeAiService`'e (Adım 2'deki sahte motor) geri döneriz. Bu
///   sayede API anahtarını henüz almamış biri bile uygulamayı sorunsuz
///   çalıştırabilir.
/// - `.env`'de GERÇEK bir anahtar VARSA → otomatik olarak
///   `GeminiRecipeAiService`'e (gerçek yapay zeka) geçeriz.
///
/// Yani kullanıcı sadece `.env` dosyasına kendi anahtarını yapıştırdığı
/// anda, uygulamanın geri kalanında (ekranlarda) TEK BİR SATIR KOD
/// DEĞİŞTİRMEDEN gerçek Gemini API'sini kullanmaya başlar. Bu, Adım 1'de
/// yazdığımız `RecipeAiService` soyut sözleşmesinin tam olarak var oluş
/// sebebidir.
final recipeAiServiceProvider = Provider<RecipeAiService>((ref) {
  final apiKey = dotenv.env['GEMINI_API_KEY']?.trim() ?? '';

  if (apiKey.isEmpty) {
    return MockRecipeAiService();
  }

  return GeminiRecipeAiService(apiKey: apiKey);
});

/// Uygulamanın şu anda GERÇEK yapay zeka mı yoksa Mock veri seti mi
/// kullandığını söyler. Ayarlar ekranında (ileriki bir adımda) kullanıcıya
/// "Şu an Mock modundasın, gerçek AI için .env dosyana anahtarını ekle"
/// gibi şeffaf bir bilgi göstermek için kullanılacak.
final isUsingRealAiProvider = Provider<bool>((ref) {
  final apiKey = dotenv.env['GEMINI_API_KEY']?.trim() ?? '';
  return apiKey.isNotEmpty;
});
