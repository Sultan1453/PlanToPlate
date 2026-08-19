import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/recipe.dart';
import '../../data/services/feed_variety_store.dart';
import '../../data/services/mock_recipe_ai_service.dart';
import '../../data/services/recipe_ai_service_provider.dart';
import '../../data/services/snack_discover_catalog.dart';
import '../../data/services/weekly_plan_provider.dart';
import '../common/add_to_plan_sheet.dart';
import '../recipe_detail/recipe_detail_screen.dart';

/// Gece krizi: ruh hali filtreli, tekrar etmeyen hızlı atıştırmalıklar.
class QuickSnackScreen extends ConsumerStatefulWidget {
  const QuickSnackScreen({super.key});

  @override
  ConsumerState<QuickSnackScreen> createState() => _QuickSnackScreenState();
}

class _QuickSnackScreenState extends ConsumerState<QuickSnackScreen> {
  bool _loading = true;
  String? _error;
  List<Recipe> _snacks = [];
  FeedMood _mood = FeedMood.all;

  static const _moods = [
    FeedMood.all,
    FeedMood.salty,
    FeedMood.sweet,
    FeedMood.protein,
    FeedMood.cold,
    FeedMood.breadTop,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  List<String> _excludeTitles() {
    final plan = ref.read(weeklyPlanProvider);
    return [
      ...FeedVarietyStore.recentSnackTitles(),
      ...plan.plannedRecipeTitles,
      ..._snacks.map((r) => r.title),
    ];
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final seed = DateTime.now().millisecondsSinceEpoch;
    final exclude = _excludeTitles();

    // Yerel snack kataloğu önce — spinner'da takılma olmasın.
    var list = await MockRecipeAiService().generateQuickSnacks(
      count: 5,
      mood: _mood,
      excludeTitles: exclude,
      varietySeed: seed,
    );
    if (!mounted) return;
    if (list.isNotEmpty) {
      FeedVarietyStore.markSnackShown(list.map((r) => r.title));
      setState(() {
        _snacks = list;
        _loading = false;
      });
    }

    if (!isUsableGeminiApiKey(resolveGeminiApiKey())) {
      if (list.isEmpty && mounted) {
        setState(() {
          _error = 'Atıştırmalık bulunamadı.';
          _loading = false;
        });
      }
      return;
    }

    try {
      final ai = await ref.read(recipeAiServiceProvider).generateQuickSnacks(
            count: 5,
            mood: _mood,
            excludeTitles: exclude,
            varietySeed: seed + 11,
          );
      if (!mounted) return;
      if (ai.isNotEmpty) {
        FeedVarietyStore.markSnackShown(ai.map((r) => r.title));
        setState(() {
          _snacks = ai;
          _loading = false;
          _error = null;
        });
      } else if (list.isEmpty) {
        setState(() {
          _error = 'Atıştırmalık bulunamadı.';
          _loading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      if (list.isEmpty) {
        setState(() {
          _error = 'Atıştırmalıklar yüklenemedi.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gece Krizleri'),
        actions: [
          IconButton(
            tooltip: 'Başka 5 öneri',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final mood in _moods)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(mood.label),
                      selected: _mood == mood,
                      onSelected: _loading
                          ? null
                          : (_) {
                              setState(() => _mood = mood);
                              _load();
                            },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!, textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: _load,
                                child: const Text('Tekrar dene'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              'Max ~10 dk · az malzeme · ${_mood.label.toLowerCase()} odaklı 5 fikir. '
                              'Yenile = yeni çeşitler (son görülenler elenir).',
                            ),
                          ),
                          const SizedBox(height: 16),
                          for (final recipe in _snacks) ...[
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      recipe.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(fontWeight: FontWeight.w800),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${recipe.prepTimeMinutes + recipe.cookTimeMinutes} dk · '
                                      '${recipe.cookingMethod.displayName} · '
                                      '${recipe.nutrient.calories.round()} kcal · '
                                      '${recipe.ingredients.length} malzeme',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: AppColors.textMuted),
                                    ),
                                    const SizedBox(height: 8),
                                    for (final ing in recipe.ingredients.take(5))
                                      Text('• ${ing.name}'),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        TextButton(
                                          onPressed: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute<void>(
                                                builder: (_) => RecipeDetailScreen(
                                                  recipe: recipe,
                                                ),
                                              ),
                                            );
                                          },
                                          child: const Text('Tarifi gör'),
                                        ),
                                        const Spacer(),
                                        FilledButton.tonal(
                                          onPressed: () => showAddToPlanSheet(
                                            context,
                                            ref: ref,
                                            recipe: recipe,
                                            initialMealType: MealType.snack,
                                            initialDay: dayOfWeekToday(),
                                          ),
                                          child: const Text('Planıma ekle'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          OutlinedButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.casino_outlined),
                            label: const Text('Başka 5 çeşit getir'),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}
