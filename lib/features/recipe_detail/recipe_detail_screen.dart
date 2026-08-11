import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/ingredient.dart';
import '../../data/models/recipe.dart';

/// Bir tarifin TÜM detaylarını (malzemeler, yapılış adımları, besin
/// değerleri, pişirme yöntemi) gösteren salt okunur ekran.
///
/// Haftalık Planlayıcı'da DOLU bir slota dokunulduğunda buraya gelinir.
class RecipeDetailScreen extends StatelessWidget {
  const RecipeDetailScreen({super.key, required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(recipe.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _InfoChipsRow(recipe: recipe),
          const SizedBox(height: 20),
          _NutrientCard(recipe: recipe),
          const SizedBox(height: 24),
          _SectionTitle(icon: Icons.shopping_basket_outlined, title: 'Malzemeler'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final ingredient in recipe.ingredients) _IngredientRow(ingredient: ingredient),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _SectionTitle(icon: Icons.checklist_rtl, title: 'Yapılışı'),
          const SizedBox(height: 8),
          for (final entry in recipe.steps.asMap().entries)
            _StepRow(index: entry.key + 1, text: entry.value),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Kaç kişilik, hazırlık/pişirme süresi ve pişirme yöntemi bilgilerini
/// yatay bir çip (chip) satırında gösterir.
class _InfoChipsRow extends StatelessWidget {
  const _InfoChipsRow({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _InfoChip(icon: Icons.people_outline, label: '${recipe.servings} Kişilik'),
        _InfoChip(
          icon: Icons.schedule,
          label: '${recipe.prepTimeMinutes + recipe.cookTimeMinutes} dk',
        ),
        _InfoChip(icon: _cookingMethodIcon(recipe.cookingMethod), label: recipe.cookingMethod.displayName),
      ],
    );
  }

  static IconData _cookingMethodIcon(CookingMethod method) {
    switch (method) {
      case CookingMethod.airFryer:
        return Icons.air;
      case CookingMethod.oven:
        return Icons.microwave_outlined;
      case CookingMethod.stovetop:
        return Icons.soup_kitchen_outlined;
      case CookingMethod.grill:
        return Icons.outdoor_grill;
      case CookingMethod.noCook:
        return Icons.ac_unit;
      case CookingMethod.other:
        return Icons.restaurant_menu;
    }
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18, color: AppColors.primaryGreenDark),
      label: Text(label),
    );
  }
}

/// Kalori, protein, karbonhidrat ve yağ değerlerini bir ızgara (grid)
/// düzeninde gösteren kart.
class _NutrientCard extends StatelessWidget {
  const _NutrientCard({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final nutrient = recipe.nutrient;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _NutrientValue(label: 'Kalori', value: nutrient.calories.toStringAsFixed(0), unit: 'kcal'),
            _NutrientValue(label: 'Protein', value: nutrient.protein.toStringAsFixed(0), unit: 'g'),
            _NutrientValue(label: 'Karbonhidrat', value: nutrient.carbs.toStringAsFixed(0), unit: 'g'),
            _NutrientValue(label: 'Yağ', value: nutrient.fat.toStringAsFixed(0), unit: 'g'),
          ],
        ),
      ),
    );
  }
}

class _NutrientValue extends StatelessWidget {
  const _NutrientValue({required this.label, required this.value, required this.unit});

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryGreenDark,
                ),
          ),
          Text(unit, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryGreenDark),
        const SizedBox(width: 8),
        Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({required this.ingredient});

  final Ingredient ingredient;

  @override
  Widget build(BuildContext context) {
    final quantityText = ingredient.quantity == ingredient.quantity.roundToDouble()
        ? ingredient.quantity.toStringAsFixed(0)
        : ingredient.quantity.toStringAsFixed(1);

    return ListTile(
      dense: true,
      leading: const Icon(Icons.circle, size: 8, color: AppColors.primaryGreen),
      title: Text(ingredient.name),
      trailing: Text(
        '$quantityText ${ingredient.unit}',
        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textMuted),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.primaryGreen,
            child: Text(
              '$index',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
