import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/fridge_item.dart';
import '../../data/models/fridge_suggestion.dart';
import '../../data/models/ingredient.dart';
import '../../data/models/recipe_constraints.dart';
import '../../data/models/user.dart';
import '../../data/services/fridge_inventory_provider.dart';
import '../../data/services/household_prefs_provider.dart';
import '../../data/services/recipe_ai_service.dart';
import '../../data/services/recipe_ai_service_provider.dart';
import '../../data/services/user_provider.dart';
import '../../data/services/weekly_plan_provider.dart';
import '../common/voice_ingredient_sheet.dart';
import '../paywall/paywall_screen.dart';
import '../recipe_detail/recipe_detail_screen.dart';

/// Evdeki malzemeleri kaydedip AI ile yemek önerisi alan sekme.
class FridgeScreen extends ConsumerStatefulWidget {
  const FridgeScreen({super.key});

  @override
  ConsumerState<FridgeScreen> createState() => _FridgeScreenState();
}

class _FridgeScreenState extends ConsumerState<FridgeScreen> {
  final _controller = TextEditingController();
  bool _isSuggesting = false;
  FridgeSuggestionResult? _result;
  FridgeUrgency _defaultUrgency = FridgeUrgency.normal;
  bool _under30 = false;
  bool _fewIngredients = false;
  bool _noOven = false;

  static const _quickAdds = [
    'Yumurta',
    'Soğan',
    'Domates',
    'Patates',
    'Pirinç',
    'Makarna',
    'Tavuk',
    'Yoğurt',
    'Peynir',
    'Zeytinyağı',
    'Un',
    'Salça',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addIngredient([String? value]) {
    final text = (value ?? _controller.text).trim();
    if (text.isEmpty) return;
    ref.read(fridgeInventoryProvider.notifier).add(text, urgency: _defaultUrgency);
    _controller.clear();
    setState(() => _result = null);
  }

  Future<void> _suggest() async {
    final ingredients = ref.read(fridgeInventoryProvider);
    if (ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce evdeki malzemeleri ekle.')),
      );
      return;
    }

    final userNotifier = ref.read(userProvider.notifier);
    if (!userNotifier.tryConsumeRecipeGeneration()) {
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const PaywallScreen(reason: PaywallReason.recipeQuota),
        ),
      );
      return;
    }

    setState(() {
      _isSuggesting = true;
      _result = null;
    });

    try {
      final ai = ref.read(recipeAiServiceProvider);
      final names = ref.read(fridgeInventoryProvider.notifier).namesForAi();
      final planTitles = ref.read(weeklyPlanProvider).plannedRecipeTitles;
      final result = await ai.suggestFromIngredients(
        ingredients: names,
        constraints: RecipeConstraints(
          excludeTitles: planTitles,
          maxTotalMinutes: _under30 ? 30 : null,
          preferFewIngredients: _fewIngredients,
          noOven: _noOven,
        ).merge(ref.read(householdPrefsProvider).toConstraints()),
      );
      if (!mounted) return;
      setState(() => _result = result);
    } on RecipeGenerationException catch (e) {
      userNotifier.refundLastRecipeGeneration();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      userNotifier.refundLastRecipeGeneration();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Öneri alınamadı. Lütfen tekrar dene.')),
      );
    } finally {
      if (mounted) setState(() => _isSuggesting = false);
    }
  }

  Future<void> _addBuyToShopping(SuggestedBuy buy) async {
    ref.read(weeklyPlanProvider.notifier).addManualShoppingItem(
          name: buy.name,
          quantity: 1,
          unit: 'adet',
          category: _guessBuyCategory(buy.name),
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '"${buy.name}" alışveriş listesine eklendi (Ev ihtiyaçları).',
        ),
      ),
    );
  }

  static IngredientCategory _guessBuyCategory(String name) {
    final n = name.toLowerCase();
    if (RegExp(
      r'yumurta|peynir|süt|sut|yoğurt|yogurt|tereyağ|kaymak',
    ).hasMatch(n)) {
      return IngredientCategory.dairy;
    }
    if (RegExp(
      r'tavuk|et|balık|balik|kıyma|kiyma|sucuk|hindi|somon',
    ).hasMatch(n)) {
      return IngredientCategory.butcher;
    }
    if (RegExp(
      r'ekmek|lavaş|lavas|simit|yufka|galeta',
    ).hasMatch(n)) {
      return IngredientCategory.bakery;
    }
    if (RegExp(
      r'domates|soğan|sogan|biber|salatalık|salatalik|havuç|havuc|'
      r'patates|muz|elma|marul|ıspanak|ispanak|sarımsak|sarimsak|'
      r'meyve|sebze|limon|avokado|çilek|cilek',
    ).hasMatch(n)) {
      return IngredientCategory.produce;
    }
    return IngredientCategory.pantry;
  }

  void _cycleUrgency(FridgeItem item) {
    final next = switch (item.urgency) {
      FridgeUrgency.normal => FridgeUrgency.soon,
      FridgeUrgency.soon => FridgeUrgency.today,
      FridgeUrgency.today => FridgeUrgency.normal,
    };
    ref.read(fridgeInventoryProvider.notifier).setUrgency(item.name, next);
    setState(() => _result = null);
  }

  @override
  Widget build(BuildContext context) {
    final ingredients = ref.watch(fridgeInventoryProvider);
    final user = ref.watch(userProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Evdekiler'),
        actions: [
          _CreditsChip(user: user),
          IconButton(
            tooltip: 'Sesli ekle',
            icon: const Icon(Icons.mic_none),
            onPressed: () async {
              final items = await showVoiceIngredientSheet(context);
              if (items == null || items.isEmpty || !mounted) return;
              for (final name in items) {
                ref.read(fridgeInventoryProvider.notifier).add(
                      name,
                      urgency: _defaultUrgency,
                    );
              }
              setState(() => _result = null);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${items.length} malzeme eklendi.')),
              );
            },
          ),
          if (ingredients.isNotEmpty)
            IconButton(
              tooltip: 'Listeyi temizle',
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                ref.read(fridgeInventoryProvider.notifier).clear();
                setState(() => _result = null);
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            'Evindeki malzemeleri yaz; yapay zeka bunlarla yemek önersin. '
            'Bozulmaya yakınlara "Önce tüket" etiketi koy. '
            'Az malzeme varsa küçük alışveriş önerileri de çıkar.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMuted,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'Eklerken öncelik',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Normal'),
                selected: _defaultUrgency == FridgeUrgency.normal,
                onSelected: (_) => setState(() => _defaultUrgency = FridgeUrgency.normal),
              ),
              ChoiceChip(
                label: const Text('Yakında'),
                selected: _defaultUrgency == FridgeUrgency.soon,
                onSelected: (_) => setState(() => _defaultUrgency = FridgeUrgency.soon),
              ),
              ChoiceChip(
                label: const Text('Önce tüket'),
                selected: _defaultUrgency == FridgeUrgency.today,
                onSelected: (_) => setState(() => _defaultUrgency = FridgeUrgency.today),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Malzeme ekle',
                    hintText: 'örn. yumurta, soğan',
                  ),
                  onSubmitted: _addIngredient,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => _addIngredient(),
                child: const Text('Ekle'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in _quickAdds)
                ActionChip(
                  label: Text(item),
                  onPressed: () => _addIngredient(item),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (ingredients.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Henüz malzeme yok. Yukarıdan ekle veya hızlı seçimlerden birine dokun.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                    ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in ingredients)
                  InputChip(
                    label: Text(
                      item.urgency == FridgeUrgency.normal
                          ? item.name
                          : '${item.name} · ${item.urgency.shortLabel}',
                    ),
                    avatar: item.urgency == FridgeUrgency.today
                        ? const Icon(Icons.priority_high, size: 16)
                        : item.urgency == FridgeUrgency.soon
                            ? const Icon(Icons.schedule, size: 16)
                            : null,
                    onPressed: () => _cycleUrgency(item),
                    onDeleted: () {
                      ref.read(fridgeInventoryProvider.notifier).remove(item.name);
                      setState(() => _result = null);
                    },
                  ),
              ],
            ),
          const SizedBox(height: 12),
          Text(
            'Öneri tercihleri',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('30 dk altı'),
                selected: _under30,
                onSelected: (v) => setState(() => _under30 = v),
              ),
              FilterChip(
                label: const Text('Az malzeme'),
                selected: _fewIngredients,
                onSelected: (v) => setState(() => _fewIngredients = v),
              ),
              FilterChip(
                label: const Text('Fırın yok'),
                selected: _noOven,
                onSelected: (v) => setState(() => _noOven = v),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isSuggesting || ingredients.isEmpty ? null : _suggest,
            icon: _isSuggesting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(_isSuggesting ? 'Öneriler hazırlanıyor…' : 'Yemek öner'),
          ),
          if (_result != null) ...[
            const SizedBox(height: 24),
            if (_result!.note != null && _result!.note!.isNotEmpty)
              Text(
                _result!.note!,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            if (_result!.suggestedBuys.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Küçük alışveriş önerileri',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              for (final buy in _result!.suggestedBuys)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.shopping_bag_outlined),
                    title: Text(buy.name),
                    subtitle: buy.reason == null ? null : Text(buy.reason!),
                    trailing: TextButton(
                      onPressed: () => _addBuyToShopping(buy),
                      child: const Text('Listeye ekle'),
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 16),
            Text(
              'Önerilen yemekler',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            for (final recipe in _result!.recipes)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipe.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${recipe.mealType.displayName} · ${recipe.prepTimeMinutes + recipe.cookTimeMinutes} dk · ${recipe.servings} kişilik',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textMuted,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => RecipeDetailScreen(recipe: recipe),
                              ),
                            );
                          },
                          child: const Text('Tarifi gör'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _CreditsChip extends StatelessWidget {
  const _CreditsChip({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    if (user.isPremium) {
      return const Padding(
        padding: EdgeInsets.only(right: 8),
        child: Chip(
          avatar: Icon(Icons.workspace_premium, size: 16, color: AppColors.accentOrangeDark),
          label: Text('Sınırsız'),
          visualDensity: VisualDensity.compact,
        ),
      );
    }
    final remainingWeekly =
        (User.weeklyFreeRecipeLimit - user.weeklyRecipeGenerationCount)
            .clamp(0, User.weeklyFreeRecipeLimit);
    final total = remainingWeekly + user.bonusRecipeCredits;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Chip(
        avatar: const Icon(Icons.auto_awesome, size: 16, color: AppColors.primaryGreenDark),
        label: Text('$total hak'),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
