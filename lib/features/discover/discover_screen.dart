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

/// Reels tarzı keşfet: filtreler + AI/katalog destesi + tekrar önleme.
class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final List<Recipe> _deck = [];
  int _index = 0;
  double _dragDx = 0;
  bool _loading = true;
  String? _error;
  FeedMood _mood = FeedMood.all;
  MealType? _mealFilter;

  static const _batchSize = 10;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDeck(replace: true));
  }

  List<String> _excludeTitles() {
    final plan = ref.read(weeklyPlanProvider);
    return [
      ...FeedVarietyStore.recentDiscoverTitles(),
      ...plan.plannedRecipeTitles,
      ..._deck.map((r) => r.title),
    ];
  }

  Future<void> _loadDeck({required bool replace}) async {
    setState(() {
      _loading = _deck.isEmpty || replace;
      _error = null;
    });

    final seed = DateTime.now().millisecondsSinceEpoch;
    final exclude = _excludeTitles();

    // 1) Yerel katalog — anında açılır (AI beklenmez).
    var list = await MockRecipeAiService().generateDiscoverRecipes(
      count: _batchSize,
      mood: _mood,
      mealType: _mealFilter,
      excludeTitles: exclude,
      varietySeed: seed,
    );
    if (!mounted) return;
    if (list.isNotEmpty) {
      _commitDeck(list, replace: replace);
    }

    // 2) Gemini varsa zenginleştir; timeout/fallback zaten resilient katmanda.
    if (!isUsableGeminiApiKey(resolveGeminiApiKey())) {
      if (list.isEmpty && mounted) {
        setState(() {
          _error = 'Keşfet için tarif bulunamadı.';
          _loading = false;
        });
      }
      return;
    }

    try {
      final ai = await ref.read(recipeAiServiceProvider).generateDiscoverRecipes(
            count: _batchSize,
            mood: _mood,
            mealType: _mealFilter,
            excludeTitles: exclude,
            varietySeed: seed + 17,
          );
      if (!mounted) return;
      if (ai.isNotEmpty) {
        _commitDeck(ai, replace: true);
      } else if (list.isEmpty) {
        setState(() {
          _error = 'Keşfet için tarif bulunamadı.';
          _loading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      if (list.isEmpty) {
        setState(() {
          _error = 'Keşfet yüklenemedi.';
          _loading = false;
        });
      }
    }
  }

  void _commitDeck(List<Recipe> list, {required bool replace}) {
    FeedVarietyStore.markDiscoverShown(list.map((r) => r.title));
    setState(() {
      if (replace) {
        _deck
          ..clear()
          ..addAll(list);
        _index = 0;
      } else {
        final existing = _deck.map((r) => r.title.toLowerCase()).toSet();
        for (final r in list) {
          if (existing.add(r.title.toLowerCase())) _deck.add(r);
        }
      }
      _dragDx = 0;
      _loading = false;
      _error = null;
    });
  }

  Recipe? get _current =>
      _index < _deck.length ? _deck[_index] : null;

  Future<void> _onAccept(Recipe recipe) async {
    final ok = await showAddToPlanSheet(
      context,
      ref: ref,
      recipe: recipe,
      initialMealType: recipe.mealType,
    );
    if (!mounted) return;
    if (ok) _advance();
  }

  void _onSkip() => _advance();

  void _advance() {
    setState(() {
      _index = (_index + 1).clamp(0, _deck.length);
      _dragDx = 0;
    });
    if (_index >= _deck.length - 2 && !_loading) {
      _loadDeck(replace: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipe = _current;
    final remaining = (_deck.length - _index).clamp(0, _deck.length);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Keşfet'),
        actions: [
          IconButton(
            tooltip: 'Yeni deste',
            onPressed: _loading ? null : () => _loadDeck(replace: true),
            icon: const Icon(Icons.casino_outlined),
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
                for (final mood in const [
                  FeedMood.all,
                  FeedMood.quick,
                  FeedMood.light,
                  FeedMood.comfort,
                  FeedMood.protein,
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(mood.label),
                      selected: _mood == mood,
                      onSelected: _loading
                          ? null
                          : (_) {
                              setState(() => _mood = mood);
                              _loadDeck(replace: true);
                            },
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('Tüm öğünler'),
                    selected: _mealFilter == null,
                    onSelected: _loading
                        ? null
                        : (_) {
                            setState(() => _mealFilter = null);
                            _loadDeck(replace: true);
                          },
                  ),
                ),
                for (final mt in MealType.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(mt.shortDisplayName),
                      selected: _mealFilter == mt,
                      onSelected: _loading
                          ? null
                          : (_) {
                              setState(() => _mealFilter = mt);
                              _loadDeck(replace: true);
                            },
                    ),
                  ),
              ],
            ),
          ),
          if (_loading && _deck.isEmpty)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null && _deck.isEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => _loadDeck(replace: true),
                        child: const Text('Tekrar dene'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (recipe == null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Bu destenin sonu.'),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => _loadDeck(replace: true),
                      icon: const Icon(Icons.casino_outlined),
                      label: const Text('Yeni çeşitler getir'),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text(
                          '$remaining kart',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textMuted,
                              ),
                        ),
                        const Spacer(),
                        if (_loading)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onHorizontalDragUpdate: (d) {
                        setState(() => _dragDx += d.delta.dx);
                      },
                      onHorizontalDragEnd: (d) async {
                        if (_dragDx > 120) {
                          setState(() => _dragDx = 0);
                          await _onAccept(recipe);
                        } else if (_dragDx < -120) {
                          _onSkip();
                        } else {
                          setState(() => _dragDx = 0);
                        }
                      },
                      child: Transform.translate(
                        offset: Offset(_dragDx, 0),
                        child: Transform.rotate(
                          angle: _dragDx * 0.0012,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: _SwipeRecipeCard(
                              recipe: recipe,
                              onOpen: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        RecipeDetailScreen(recipe: recipe),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _onSkip,
                            icon: const Icon(Icons.close),
                            label: const Text('Geç'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _onAccept(recipe),
                            icon: const Icon(Icons.favorite_outline),
                            label: const Text('Planıma ekle'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Sola: geç · Sağa: plana ekle · Üstte filtre / yeni deste',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SwipeRecipeCard extends StatelessWidget {
  const _SwipeRecipeCard({required this.recipe, required this.onOpen});

  final Recipe recipe;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _chip(recipe.mealType.displayName),
                  _chip(recipe.cookingMethod.displayName),
                  _chip(
                    '${recipe.prepTimeMinutes + recipe.cookTimeMinutes} dk',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                recipe.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '${recipe.servings} kişilik · '
                '${recipe.nutrient.calories.round()} kcal · '
                'P ${recipe.nutrient.protein.round()}g',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                    ),
              ),
              const Spacer(),
              Text(
                'Malzemeler',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              for (final ing in recipe.ingredients.take(6))
                Text('• ${ing.name}'),
              if (recipe.ingredients.length > 6)
                Text('+${recipe.ingredients.length - 6} malzeme daha…'),
              const Spacer(),
              Text(
                'Detay için dokun',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.primaryGreenDark,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }
}
