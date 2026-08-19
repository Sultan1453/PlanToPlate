import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plan_to_plate/data/services/mock_recipe_ai_service.dart';
import 'package:plan_to_plate/data/services/recipe_ai_service_provider.dart';

/// API anahtarı doğrulama + derleme zamanı anahtar yokken Mock seçimi.
void main() {
  test('boş veya kısa anahtar kullanılabilir değil', () {
    expect(isUsableGeminiApiKey(''), isFalse);
    expect(isUsableGeminiApiKey('short'), isFalse);
  });

  test('placeholder anahtar kullanılabilir değil', () {
    expect(
      isUsableGeminiApiKey('BURAYA_KENDI_GEMINI_API_ANAHTARINI_YAPISTIR'),
      isFalse,
    );
    expect(isUsableGeminiApiKey('your_api_key_here_xxxxxxxxxxx'), isFalse);
  });

  test('gerçek görünümlü anahtar kullanılabilir sayılır', () {
    expect(
      isUsableGeminiApiKey('AIzaSyDummyKeyForUnitTestsOnly99'),
      isTrue,
    );
  });

  test('dart-define yoksa (varsayılan test) Mock motor seçilir', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final service = container.read(recipeAiServiceProvider);

    expect(service, isA<MockRecipeAiService>());
    expect(container.read(isUsingRealAiProvider), isFalse);
  });
}
