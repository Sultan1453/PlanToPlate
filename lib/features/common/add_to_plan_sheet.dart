import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/ingredient.dart';
import '../../data/models/recipe.dart';
import '../../data/models/weekly_plan.dart';
import '../../data/services/weekly_plan_provider.dart';

/// Keşfet / tarif detay / hızlı atıştırmalık → plana ekleme paneli.
Future<bool> showAddToPlanSheet(
  BuildContext context, {
  required WidgetRef ref,
  required Recipe recipe,
  DayOfWeek? initialDay,
  MealType? initialMealType,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _AddToPlanSheet(
      recipe: recipe,
      initialDay: initialDay ?? DayOfWeek.values[DateTime.now().weekday - 1],
      initialMealType: initialMealType ?? recipe.mealType,
    ),
  );
  return result == true;
}

class _AddToPlanSheet extends ConsumerStatefulWidget {
  const _AddToPlanSheet({
    required this.recipe,
    required this.initialDay,
    required this.initialMealType,
  });

  final Recipe recipe;
  final DayOfWeek initialDay;
  final MealType initialMealType;

  @override
  ConsumerState<_AddToPlanSheet> createState() => _AddToPlanSheetState();
}

class _AddToPlanSheetState extends ConsumerState<_AddToPlanSheet> {
  late DayOfWeek _day = widget.initialDay;
  late MealType _mealType = widget.initialMealType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        20 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Planıma ekle',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.recipe.title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMuted,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            'Hangi güne eklensin?',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final day in DayOfWeek.values)
                ChoiceChip(
                  label: Text(day.shortDisplayName),
                  selected: _day == day,
                  onSelected: (_) => setState(() => _day = day),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Hangi öğüne eklensin?',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final meal in MealType.values)
                ChoiceChip(
                  label: Text(meal.shortDisplayName),
                  selected: _mealType == meal,
                  onSelected: (_) => setState(() => _mealType = meal),
                ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () {
              final plan = ref.read(weeklyPlanProvider);
              final source = widget.recipe;
              final assigned = Recipe(
                id: source.id,
                title: source.title,
                mealType: _mealType,
                ingredients: [
                  for (final i in source.ingredients)
                    Ingredient(
                      name: i.name,
                      quantity: i.quantity,
                      unit: i.unit,
                      category: i.category,
                      isChecked: i.isChecked,
                    ),
                ],
                steps: List<String>.from(source.steps),
                nutrient: source.nutrient,
                cookingMethod: source.cookingMethod,
                servings: source.servings,
                prepTimeMinutes: source.prepTimeMinutes,
                cookTimeMinutes: source.cookTimeMinutes,
              );
              ref.read(weeklyPlanProvider.notifier).assignRecipeForWeek(
                    weekStartDate: plan.weekStartDate,
                    day: _day,
                    mealType: _mealType,
                    recipe: assigned,
                  );
              Navigator.pop(context, true);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${assigned.title} → ${_day.displayName} / ${_mealType.shortDisplayName}',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.event_available_outlined),
            label: const Text('Onayla ve ekle'),
          ),
        ],
      ),
    );
  }
}

/// Bugünün DayOfWeek değeri (Pazartesi=0).
DayOfWeek dayOfWeekToday() => DayOfWeek.values[DateTime.now().weekday - 1];

/// Plan haftasının Pazartesi'si.
DateTime currentPlanWeekStart() => startOfWeek(DateTime.now());
