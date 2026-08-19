import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/recipe.dart';
import 'hive_service.dart';

/// Tarif kaç kez plana eklendi / yapıldı sayacı (başlığa göre).
class RecipeHistoryEntry {
  const RecipeHistoryEntry({
    required this.title,
    required this.count,
    this.lastRecipeJson,
  });

  final String title;
  final int count;
  final Map<String, dynamic>? lastRecipeJson;

  Map<String, dynamic> toJson() => {
        'title': title,
        'count': count,
        if (lastRecipeJson != null) 'lastRecipe': lastRecipeJson,
      };

  factory RecipeHistoryEntry.fromJson(Map<String, dynamic> json) {
    final last = json['lastRecipe'];
    return RecipeHistoryEntry(
      title: json['title']?.toString() ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
      lastRecipeJson: last is Map ? Map<String, dynamic>.from(last) : null,
    );
  }
}

class RecipeHistoryNotifier extends StateNotifier<List<RecipeHistoryEntry>> {
  RecipeHistoryNotifier() : super(_load());

  static const _key = 'recipe_cook_history';

  static List<RecipeHistoryEntry> _load() {
    final raw = HiveService.settingsBox.get(_key);
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => RecipeHistoryEntry.fromJson(Map<String, dynamic>.from(e)))
        .where((e) => e.title.isNotEmpty)
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));
  }

  void _persist() {
    HiveService.settingsBox.put(
      _key,
      state.map((e) => e.toJson()).toList(),
    );
  }

  int countForTitle(String title) {
    final key = title.trim().toLowerCase();
    for (final e in state) {
      if (e.title.toLowerCase() == key) return e.count;
    }
    return 0;
  }

  void record(Recipe recipe) {
    final title = recipe.title.trim();
    if (title.isEmpty) return;
    final key = title.toLowerCase();
    final next = <RecipeHistoryEntry>[];
    var found = false;
    for (final e in state) {
      if (e.title.toLowerCase() == key) {
        next.add(
          RecipeHistoryEntry(
            title: title,
            count: e.count + 1,
            lastRecipeJson: recipe.toJson(),
          ),
        );
        found = true;
      } else {
        next.add(e);
      }
    }
    if (!found) {
      next.add(
        RecipeHistoryEntry(
          title: title,
          count: 1,
          lastRecipeJson: recipe.toJson(),
        ),
      );
    }
    next.sort((a, b) => b.count.compareTo(a.count));
    state = next;
    _persist();
  }

  List<RecipeHistoryEntry> get topFive => state.take(5).toList();

  Recipe? recipeFromEntry(RecipeHistoryEntry entry, {required MealType mealType}) {
    final json = entry.lastRecipeJson;
    if (json == null) return null;
    final id = json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
    return Recipe.fromJson(json, id: id, mealType: mealType);
  }
}

final recipeHistoryProvider =
    StateNotifierProvider<RecipeHistoryNotifier, List<RecipeHistoryEntry>>((ref) {
  return RecipeHistoryNotifier();
});
