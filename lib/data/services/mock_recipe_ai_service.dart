import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../../core/utils/turkish_text_utils.dart';
import '../models/fridge_suggestion.dart';
import '../models/ingredient.dart';
import '../models/recipe.dart';
import '../models/recipe_constraints.dart';
import 'mock_recipe_dataset.dart';
import 'recipe_ai_service.dart';
import 'snack_discover_catalog.dart';

class MockRecipeAiService implements RecipeAiService {
  @override
  Future<Recipe> generateRecipe({
    required String id,
    required String mealName,
    required MealType mealType,
    RecipeConstraints constraints = const RecipeConstraints(),
  }) async {
    await Future.delayed(const Duration(milliseconds: 900));

    final normalizedInput = normalizeTurkish(mealName);
    var matchedEntry =
        _findByKeyword(normalizedInput) ?? _pickDeterministicFallback(normalizedInput);
    matchedEntry = _pickAvoidingExcludes(matchedEntry, constraints) ?? matchedEntry;
    matchedEntry = _applyConstraintFilters(matchedEntry, constraints);

    return Recipe.fromJson(matchedEntry, id: id, mealType: mealType);
  }

  @override
  Future<Recipe> generateRecipeFromPhoto({
    required String id,
    required Uint8List imageBytes,
    required String mimeType,
    required MealType mealType,
    RecipeConstraints constraints = const RecipeConstraints(),
  }) async {
    await Future.delayed(const Duration(milliseconds: 900));
    final fingerprint = imageBytes.fold<int>(0, (sum, b) => sum + b);
    var index = fingerprint % mockRecipeDataset.length;
    var entry = Map<String, dynamic>.from(mockRecipeDataset[index]);
    entry = _pickAvoidingExcludes(entry, constraints) ?? entry;
    entry = _applyConstraintFilters(entry, constraints);
    entry['title'] = '${entry['title']} (Fotoğraftan)';
    return Recipe.fromJson(entry, id: id, mealType: mealType);
  }

  @override
  Future<FridgeSuggestionResult> suggestFromIngredients({
    required List<String> ingredients,
    RecipeConstraints constraints = const RecipeConstraints(),
  }) async {
    await Future.delayed(const Duration(milliseconds: 900));

    final fridge = ingredients
        .map((e) => normalizeTurkish(e.trim()))
        .where((e) => e.isNotEmpty)
        .toList();
    if (fridge.isEmpty) {
      throw RecipeGenerationException('Öneri için en az bir malzeme ekle.');
    }

    final excluded = constraints.excludeTitles
        .map(normalizeTurkish)
        .where((e) => e.isNotEmpty)
        .toSet();

    final scored = <({Map<String, dynamic> entry, int score})>[];
    for (final entry in mockRecipeDataset) {
      final title = normalizeTurkish(entry['title']?.toString() ?? '');
      if (excluded.any((e) => title.contains(e) || e.contains(title))) continue;

      final ingList = (entry['ingredients'] as List)
          .map((e) => normalizeTurkish((e as Map)['name'].toString()))
          .toList();
      var score = 0;
      for (final f in fridge) {
        for (final ing in ingList) {
          if (ing.contains(f) || f.contains(ing)) {
            score += 1;
            break;
          }
        }
      }
      if (constraints.preferFewIngredients && ingList.length <= 8) score += 2;
      if (constraints.noOven) {
        final method = normalizeTurkish(entry['cookingMethod']?.toString() ?? '');
        if (method.contains('oven') || method.contains('firin')) continue;
      }
      if (constraints.maxTotalMinutes != null) {
        final prep = (entry['prepTimeMinutes'] as num?)?.toInt() ?? 0;
        final cook = (entry['cookTimeMinutes'] as num?)?.toInt() ?? 0;
        if (prep + cook > constraints.maxTotalMinutes!) continue;
      }
      scored.add((entry: entry, score: score));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));

    const uuid = Uuid();
    final top = scored.take(3).where((e) => e.score > 0).toList();
    final picks = top.isNotEmpty
        ? top
        : (scored.isNotEmpty ? scored.take(2).toList() : mockRecipeDataset.take(2).map((e) => (entry: e, score: 0)).toList());

    final recipes = <Recipe>[];
    for (var i = 0; i < picks.length; i++) {
      final mealType = switch (i % 3) {
        0 => MealType.dinner,
        1 => MealType.lunch,
        _ => MealType.breakfast,
      };
      recipes.add(
        Recipe.fromJson(picks[i].entry, id: uuid.v4(), mealType: mealType),
      );
    }

    final buys = <SuggestedBuy>[];
    final bestScore = picks.isEmpty ? 0 : picks.first.score;
    if (fridge.length < 3 || bestScore < 2) {
      const catalog = [
        SuggestedBuy(name: 'Yumurta', reason: 'Hızlı kahvaltı / omlet için'),
        SuggestedBuy(name: 'Soğan', reason: 'Neredeyse her yemeğe temel'),
        SuggestedBuy(name: 'Domates', reason: 'Salça yerine taze lezzet'),
        SuggestedBuy(name: 'Limon', reason: 'Salata ve etlere ekşi dokunuş'),
        SuggestedBuy(name: 'Maydanoz', reason: 'Süsleme ve taze aroma'),
        SuggestedBuy(name: 'Salça', reason: 'Çorba ve sos için'),
      ];
      for (final buy in catalog) {
        final key = normalizeTurkish(buy.name);
        final already = fridge.any((f) => f.contains(key) || key.contains(f));
        if (!already) buys.add(buy);
        if (buys.length >= 4) break;
      }
    }

    if (buys.length < 3 && recipes.isNotEmpty) {
      for (final recipe in recipes) {
        for (final ing in recipe.ingredients) {
          final key = normalizeTurkish(ing.name);
          final have = fridge.any((f) => f.contains(key) || key.contains(f));
          final alreadySuggested =
              buys.any((b) => normalizeTurkish(b.name) == key);
          if (!have &&
              !alreadySuggested &&
              ing.category != IngredientCategory.butcher) {
            buys.add(
              SuggestedBuy(
                name: ing.name,
                reason: '${recipe.title} için küçük tamamlayıcı',
              ),
            );
          }
          if (buys.length >= 5) break;
        }
        if (buys.length >= 5) break;
      }
    }

    final note = bestScore >= 2
        ? 'Evdekilerinle uyumlu ${recipes.length} tarif buldum.'
        : 'Malzeme az olduğu için birkaç küçük alışveriş önerisi de ekledim.';

    return FridgeSuggestionResult(
      recipes: recipes,
      suggestedBuys: buys,
      note: note,
    );
  }

  @override
  Future<List<Recipe>> generateQuickSnacks({
    int count = 5,
    FeedMood mood = FeedMood.all,
    List<String> excludeTitles = const [],
    int? varietySeed,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    const uuid = Uuid();
    final seed = varietySeed ?? DateTime.now().millisecondsSinceEpoch;
    final picks = SnackDiscoverCatalog.pickSnacks(
      count: count.clamp(1, 8),
      mood: mood,
      excludeTitles: excludeTitles,
      seed: seed,
    );
    return [
      for (final entry in picks)
        Recipe.fromJson(
          entry,
          id: uuid.v4(),
          mealType: MealType.snack,
        ),
    ];
  }

  @override
  Future<List<Recipe>> generateDiscoverRecipes({
    int count = 10,
    FeedMood mood = FeedMood.all,
    MealType? mealType,
    List<String> excludeTitles = const [],
    int? varietySeed,
  }) async {
    await Future.delayed(const Duration(milliseconds: 450));
    const uuid = Uuid();
    final seed = varietySeed ?? DateTime.now().millisecondsSinceEpoch;
    final picks = SnackDiscoverCatalog.pickDiscover(
      count: count.clamp(1, 16),
      mood: mood,
      mealType: mealType,
      excludeTitles: excludeTitles,
      seed: seed,
    );
    return [
      for (var i = 0; i < picks.length; i++)
        Recipe.fromJson(
          picks[i],
          id: uuid.v4(),
          mealType: mealType ??
              MealType.fromString(picks[i]['mealType']?.toString()),
        ),
    ];
  }

  Map<String, dynamic>? _findByKeyword(String normalizedInput) {
    for (final entry in mockRecipeDataset) {
      final keywords = entry['keywords'] as List<String>;
      for (final keyword in keywords) {
        if (normalizedInput.contains(normalizeTurkish(keyword))) {
          return entry;
        }
      }
    }
    return null;
  }

  Map<String, dynamic> _pickDeterministicFallback(String normalizedInput) {
    if (normalizedInput.isEmpty) return mockRecipeDataset.first;
    final sumOfCharCodes = normalizedInput.codeUnits.fold<int>(
      0,
      (total, charCode) => total + charCode,
    );
    final index = sumOfCharCodes % mockRecipeDataset.length;
    return mockRecipeDataset[index];
  }

  Map<String, dynamic>? _pickAvoidingExcludes(
    Map<String, dynamic> preferred,
    RecipeConstraints constraints,
  ) {
    if (constraints.excludeTitles.isEmpty) return preferred;
    final excluded = constraints.excludeTitles.map(normalizeTurkish).toSet();
    final title = normalizeTurkish(preferred['title']?.toString() ?? '');
    final clashes = excluded.any((e) => title.contains(e) || e.contains(title));
    if (!clashes) return preferred;

    for (final entry in mockRecipeDataset) {
      final t = normalizeTurkish(entry['title']?.toString() ?? '');
      if (excluded.any((e) => t.contains(e) || e.contains(t))) continue;
      return entry;
    }
    return preferred;
  }

  Map<String, dynamic> _applyConstraintFilters(
    Map<String, dynamic> entry,
    RecipeConstraints constraints,
  ) {
    if (!constraints.hasAny) return entry;

    for (final candidate in mockRecipeDataset) {
      if (constraints.noOven) {
        final method = normalizeTurkish(candidate['cookingMethod']?.toString() ?? '');
        if (method.contains('oven') || method.contains('firin')) continue;
      }
      if (constraints.maxTotalMinutes != null) {
        final prep = (candidate['prepTimeMinutes'] as num?)?.toInt() ?? 0;
        final cook = (candidate['cookTimeMinutes'] as num?)?.toInt() ?? 0;
        if (prep + cook > constraints.maxTotalMinutes!) continue;
      }
      if (constraints.preferFewIngredients) {
        final count = (candidate['ingredients'] as List?)?.length ?? 99;
        if (count > 8) continue;
      }
      final excluded = constraints.excludeTitles.map(normalizeTurkish).toSet();
      final t = normalizeTurkish(candidate['title']?.toString() ?? '');
      if (excluded.any((e) => t.contains(e) || e.contains(t))) continue;
      return candidate;
    }
    return entry;
  }
}
