import '../models/ingredient.dart';
import '../models/weekly_plan.dart';
import 'ingredient_aggregator_service.dart';
import 'market_price_catalog.dart';
import 'purchase_unit_normalizer.dart';

/// Haftalık kalori + tahmini alışveriş bütçesi.
class WeeklyBudgetCalorieSummary {
  const WeeklyBudgetCalorieSummary({
    required this.plannedMeals,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
    required this.avgDailyCalories,
    required this.estimatedBudgetTry,
    required this.shoppingItemCount,
    required this.topCostLines,
  });

  final int plannedMeals;
  final double totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;

  /// 7 güne bölünmüş ortalama (planlı gün yoksa 0).
  final double avgDailyCalories;

  /// Alışveriş listesi üzerinden tahmini TL.
  final double estimatedBudgetTry;
  final int shoppingItemCount;

  /// En pahalı 3 alışveriş satırı (gösterim için).
  final List<({String label, double tryAmount})> topCostLines;

  String get budgetLabel {
    if (estimatedBudgetTry <= 0) return '—';
    return '₺${estimatedBudgetTry.round()}';
  }

  String get caloriesLabel {
    if (totalCalories <= 0) return '—';
    return '${totalCalories.round()} kcal';
  }
}

class WeeklyBudgetCalorieService {
  WeeklyBudgetCalorieService._();

  static WeeklyBudgetCalorieSummary build(WeeklyPlan plan) {
    var calories = 0.0;
    var protein = 0.0;
    var carbs = 0.0;
    var fat = 0.0;
    var meals = 0;

    for (final slot in plan.meals) {
      final recipe = slot.recipe;
      if (recipe == null) continue;
      meals++;
      // nutrient = 1 porsiyon; tüm tabak için servings ile çarp
      final servings = recipe.servings <= 0 ? 1 : recipe.servings;
      calories += recipe.nutrient.calories * servings;
      protein += recipe.nutrient.protein * servings;
      carbs += recipe.nutrient.carbs * servings;
      fat += recipe.nutrient.fat * servings;
    }

    final purchaseItems = PurchaseUnitNormalizer.normalizeList(
      IngredientAggregatorService.aggregate(plan),
    );

    var budget = 0.0;
    final costs = <({String label, double tryAmount, Ingredient ing})>[];
    for (final ing in purchaseItems) {
      final line = MarketPriceCatalog.estimateLine(ing);
      budget += line;
      final qty = ing.quantity == ing.quantity.roundToDouble()
          ? ing.quantity.toStringAsFixed(0)
          : ing.quantity.toStringAsFixed(1);
      costs.add((
        label: '$qty ${ing.unit} ${ing.name}',
        tryAmount: line,
        ing: ing,
      ));
    }
    costs.sort((a, b) => b.tryAmount.compareTo(a.tryAmount));

    return WeeklyBudgetCalorieSummary(
      plannedMeals: meals,
      totalCalories: calories,
      totalProtein: protein,
      totalCarbs: carbs,
      totalFat: fat,
      avgDailyCalories: meals == 0 ? 0 : calories / 7,
      estimatedBudgetTry: budget,
      shoppingItemCount: purchaseItems.length,
      topCostLines: costs
          .take(3)
          .map((e) => (label: e.label, tryAmount: e.tryAmount))
          .toList(),
    );
  }
}
