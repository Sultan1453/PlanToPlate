import 'dart:typed_data';

import '../models/fridge_suggestion.dart';
import '../models/recipe.dart';
import '../models/recipe_constraints.dart';
import 'snack_discover_catalog.dart';

class RecipeGenerationException implements Exception {
  RecipeGenerationException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class RecipeAiService {
  Future<Recipe> generateRecipe({
    required String id,
    required String mealName,
    required MealType mealType,
    RecipeConstraints constraints = const RecipeConstraints(),
  });

  Future<Recipe> generateRecipeFromPhoto({
    required String id,
    required Uint8List imageBytes,
    required String mimeType,
    required MealType mealType,
    RecipeConstraints constraints = const RecipeConstraints(),
  });

  Future<FridgeSuggestionResult> suggestFromIngredients({
    required List<String> ingredients,
    RecipeConstraints constraints = const RecipeConstraints(),
  });

  /// Gece krizi: max ~10 dk, az malzemeli atıştırmalıklar (çeşitli).
  Future<List<Recipe>> generateQuickSnacks({
    int count = 5,
    FeedMood mood = FeedMood.all,
    List<String> excludeTitles = const [],
    int? varietySeed,
  });

  /// Keşfet destesi için çeşitli tarif paketi.
  Future<List<Recipe>> generateDiscoverRecipes({
    int count = 10,
    FeedMood mood = FeedMood.all,
    MealType? mealType,
    List<String> excludeTitles = const [],
    int? varietySeed,
  });
}
