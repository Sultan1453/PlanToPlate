import 'package:flutter_test/flutter_test.dart';
import 'package:plan_to_plate/data/models/ingredient.dart';
import 'package:plan_to_plate/data/models/nutrient.dart';
import 'package:plan_to_plate/data/models/recipe.dart';
import 'package:plan_to_plate/data/models/weekly_plan.dart';
import 'package:plan_to_plate/data/services/weekly_budget_calorie_service.dart';

void main() {
  test('Haftalık kalori porsiyonla çarpılır, bütçe alışverişten gelir', () {
    final plan = WeeklyPlan(
      id: 't1',
      weekStartDate: DateTime(2026, 8, 10),
    );
    plan.mealFor(DayOfWeek.monday, MealType.dinner).recipe = Recipe(
      id: 'r1',
      title: 'Test Yemek',
      mealType: MealType.dinner,
      ingredients: [
        Ingredient(
          name: 'Soğan',
          quantity: 2,
          unit: 'adet',
          category: IngredientCategory.produce,
        ),
        Ingredient(
          name: 'Zeytinyağı',
          quantity: 2,
          unit: 'yemek kaşığı',
          category: IngredientCategory.pantry,
        ),
      ],
      steps: const ['Pişir'],
      nutrient: Nutrient(calories: 400, protein: 20, carbs: 30, fat: 15),
      cookingMethod: CookingMethod.stovetop,
      servings: 2,
      prepTimeMinutes: 10,
      cookTimeMinutes: 20,
      createdAt: DateTime(2026, 8, 10),
    );

    final stats = WeeklyBudgetCalorieService.build(plan);

    expect(stats.plannedMeals, 1);
    expect(stats.totalCalories, 800); // 400 * 2 porsiyon
    expect(stats.estimatedBudgetTry, greaterThan(0));
    expect(stats.shoppingItemCount, greaterThanOrEqualTo(1));
  });
}
