import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../models/fridge_suggestion.dart';
import '../models/recipe.dart';
import '../models/recipe_constraints.dart';
import 'gemini_recipe_ai_service.dart';
import 'mock_recipe_ai_service.dart';
import 'recipe_ai_service.dart';
import 'snack_discover_catalog.dart';

final recipeAiServiceProvider = Provider<RecipeAiService>((ref) {
  final apiKey = resolveGeminiApiKey();

  if (!isUsableGeminiApiKey(apiKey)) {
    return MockRecipeAiService();
  }

  return _ResilientRecipeAiService(
    primary: GeminiRecipeAiService(apiKey: apiKey),
    fallback: MockRecipeAiService(),
  );
});

final isUsingRealAiProvider = Provider<bool>((ref) {
  return isUsableGeminiApiKey(resolveGeminiApiKey());
});

/// Derleme zamanı `GEMINI_API_KEY` (`--dart-define` / `--dart-define-from-file`).
String resolveGeminiApiKey() => AppConfig.geminiApiKey.trim();

/// Placeholder / boş anahtarları gerçek Gemini çağrısından ayırır.
bool isUsableGeminiApiKey(String apiKey) {
  if (apiKey.isEmpty || apiKey.length < 20) return false;
  final lower = apiKey.toLowerCase();
  const placeholders = [
    'your_api_key',
    'your-api-key',
    'changeme',
    'replace_me',
    'xxx',
    'todo',
    'paste_here',
    'buraya_kendi',
  ];
  for (final placeholder in placeholders) {
    if (lower.contains(placeholder)) return false;
  }
  return true;
}

class _ResilientRecipeAiService implements RecipeAiService {
  _ResilientRecipeAiService({
    required this.primary,
    required this.fallback,
  });

  final RecipeAiService primary;
  final RecipeAiService fallback;

  @override
  Future<Recipe> generateRecipe({
    required String id,
    required String mealName,
    required MealType mealType,
    RecipeConstraints constraints = const RecipeConstraints(),
  }) async {
    try {
      return await primary.generateRecipe(
        id: id,
        mealName: mealName,
        mealType: mealType,
        constraints: constraints,
      );
    } on RecipeGenerationException {
      return fallback.generateRecipe(
        id: id,
        mealName: mealName,
        mealType: mealType,
        constraints: constraints,
      );
    }
  }

  @override
  Future<Recipe> generateRecipeFromPhoto({
    required String id,
    required Uint8List imageBytes,
    required String mimeType,
    required MealType mealType,
    RecipeConstraints constraints = const RecipeConstraints(),
  }) async {
    try {
      return await primary.generateRecipeFromPhoto(
        id: id,
        imageBytes: imageBytes,
        mimeType: mimeType,
        mealType: mealType,
        constraints: constraints,
      );
    } on RecipeGenerationException {
      return fallback.generateRecipe(
        id: id,
        mealName: 'Fotoğraftan yemek',
        mealType: mealType,
        constraints: constraints,
      );
    }
  }

  @override
  Future<FridgeSuggestionResult> suggestFromIngredients({
    required List<String> ingredients,
    RecipeConstraints constraints = const RecipeConstraints(),
  }) async {
    try {
      return await primary.suggestFromIngredients(
        ingredients: ingredients,
        constraints: constraints,
      );
    } on RecipeGenerationException {
      return fallback.suggestFromIngredients(
        ingredients: ingredients,
        constraints: constraints,
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
    try {
      return await primary
          .generateQuickSnacks(
            count: count,
            mood: mood,
            excludeTitles: excludeTitles,
            varietySeed: varietySeed,
          )
          .timeout(const Duration(seconds: 12));
    } on RecipeGenerationException {
      return fallback.generateQuickSnacks(
        count: count,
        mood: mood,
        excludeTitles: excludeTitles,
        varietySeed: varietySeed,
      );
    } on TimeoutException {
      return fallback.generateQuickSnacks(
        count: count,
        mood: mood,
        excludeTitles: excludeTitles,
        varietySeed: varietySeed,
      );
    } catch (_) {
      return fallback.generateQuickSnacks(
        count: count,
        mood: mood,
        excludeTitles: excludeTitles,
        varietySeed: varietySeed,
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
    try {
      return await primary
          .generateDiscoverRecipes(
            count: count,
            mood: mood,
            mealType: mealType,
            excludeTitles: excludeTitles,
            varietySeed: varietySeed,
          )
          .timeout(const Duration(seconds: 12));
    } on RecipeGenerationException {
      return fallback.generateDiscoverRecipes(
        count: count,
        mood: mood,
        mealType: mealType,
        excludeTitles: excludeTitles,
        varietySeed: varietySeed,
      );
    } on TimeoutException {
      return fallback.generateDiscoverRecipes(
        count: count,
        mood: mood,
        mealType: mealType,
        excludeTitles: excludeTitles,
        varietySeed: varietySeed,
      );
    } catch (_) {
      return fallback.generateDiscoverRecipes(
        count: count,
        mood: mood,
        mealType: mealType,
        excludeTitles: excludeTitles,
        varietySeed: varietySeed,
      );
    }
  }
}
