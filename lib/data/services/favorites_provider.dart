import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/recipe.dart';
import 'hive_service.dart';

/// Favori tarifleri settings kutusunda JSON olarak tutar.
class FavoritesNotifier extends StateNotifier<List<Recipe>> {
  FavoritesNotifier() : super(_load());

  static const _key = 'favorite_recipes';

  static List<Recipe> _load() {
    final raw = HiveService.settingsBox.get(_key);
    if (raw is! List) return [];
    final recipes = <Recipe>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final id = map['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      recipes.add(
        Recipe.fromJson(
          map,
          id: id,
          mealType: MealType.fromString(map['mealType']?.toString()),
        ),
      );
    }
    return recipes;
  }

  void _persist() {
    HiveService.settingsBox.put(
      _key,
      state.map((e) => e.toJson()).toList(),
    );
  }

  bool contains(String recipeId) => state.any((r) => r.id == recipeId);

  void toggle(Recipe recipe) {
    if (contains(recipe.id)) {
      state = state.where((r) => r.id != recipe.id).toList();
    } else {
      state = [recipe, ...state];
    }
    _persist();
  }

  void remove(String recipeId) {
    state = state.where((r) => r.id != recipeId).toList();
    _persist();
  }
}

final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, List<Recipe>>((ref) {
  return FavoritesNotifier();
});
