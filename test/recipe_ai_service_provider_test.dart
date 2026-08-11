import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plan_to_plate/data/services/gemini_recipe_ai_service.dart';
import 'package:plan_to_plate/data/services/mock_recipe_ai_service.dart';
import 'package:plan_to_plate/data/services/recipe_ai_service_provider.dart';

/// Bu test, Adım 5'in en kritik parçasını doğrular: `.env` dosyasındaki
/// API anahtarının varlığına göre doğru motorun (Mock veya Gemini)
/// OTOMATİK seçildiğini kanıtlar.
///
/// `dotenv.loadFromString(...)` kullanıyoruz (gerçek `.env` dosyasını
/// diskten okuyan `dotenv.load(...)` yerine) çünkü bu, dosya sistemine/
/// Flutter asset sistemine ihtiyaç duymadan, doğrudan bellekte sahte bir
/// `.env` içeriği simüle etmemizi sağlar — testleri hızlı ve güvenilir
/// tutar.
void main() {
  test('.env boşsa (API anahtarı yoksa) Mock motor otomatik seçilmeli', () {
    dotenv.loadFromString(envString: 'GEMINI_API_KEY=');
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final service = container.read(recipeAiServiceProvider);

    expect(service, isA<MockRecipeAiService>());
    expect(container.read(isUsingRealAiProvider), isFalse);
  });

  test('.env dosyasında gerçek bir anahtar varsa Gemini motoru otomatik seçilmeli', () {
    dotenv.loadFromString(envString: 'GEMINI_API_KEY=sahte-test-anahtari-123');
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final service = container.read(recipeAiServiceProvider);

    expect(service, isA<GeminiRecipeAiService>());
    expect(container.read(isUsingRealAiProvider), isTrue);
  });
}
