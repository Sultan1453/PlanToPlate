import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/ingredient.dart';
import '../../data/models/recipe.dart';
import '../../data/services/favorites_provider.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/recipe_history_provider.dart';
import '../../data/services/weekly_plan_provider.dart';
import '../../data/services/weekly_summary_service.dart';
import '../common/add_to_plan_sheet.dart';
import 'cooking_mode_screen.dart';
import 'equipment_suggestion.dart';
import 'unit_converter_dialog.dart';

/// Bir tarifin TÜM detaylarını gösteren ekran.
class RecipeDetailScreen extends ConsumerStatefulWidget {
  const RecipeDetailScreen({super.key, required this.recipe});

  final Recipe recipe;

  @override
  ConsumerState<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends ConsumerState<RecipeDetailScreen> {
  Recipe get recipe => widget.recipe;

  String _formatRecipeText() {
    final buffer = StringBuffer();
    buffer.writeln(recipe.title);
    buffer.writeln('${recipe.servings} kişilik · ${recipe.cookingMethod.displayName}');
    buffer.writeln(
      '${recipe.nutrient.calories.toStringAsFixed(0)} kcal · '
      'P ${recipe.nutrient.protein.toStringAsFixed(0)}g · '
      'K ${recipe.nutrient.carbs.toStringAsFixed(0)}g · '
      'Y ${recipe.nutrient.fat.toStringAsFixed(0)}g',
    );
    buffer.writeln();
    buffer.writeln('Malzemeler:');
    for (final ingredient in recipe.ingredients) {
      final quantityText = ingredient.quantity == ingredient.quantity.roundToDouble()
          ? ingredient.quantity.toStringAsFixed(0)
          : ingredient.quantity.toStringAsFixed(1);
      buffer.writeln('- $quantityText ${ingredient.unit} ${ingredient.name}');
    }
    buffer.writeln();
    buffer.writeln('Yapılışı:');
    for (var i = 0; i < recipe.steps.length; i++) {
      buffer.writeln('${i + 1}. ${recipe.steps[i]}');
    }
    buffer.writeln();
    buffer.writeln('PlanToPlate ile hazırlandı');
    return buffer.toString();
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _formatRecipeText()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tarif panoya kopyalandı.')),
    );
  }

  Future<void> _share() async {
    await Share.share(_formatRecipeText(), subject: recipe.title);
  }

  Future<void> _scaleServings() async {
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => _ScaleServingsDialog(initialServings: recipe.servings),
    );
    if (result == null || !mounted) return;
    if (result < 1 || result > 24) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('1–24 arası bir sayı gir.')),
      );
      return;
    }
    setState(() => RecipeScaler.scaleToServings(recipe, result));
    // Diyalog kapanış animasyonu bitsin; plan notify hemen olursa ağaç yarışabilir.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;
    ref.read(weeklyPlanProvider.notifier).persistCurrentPlan();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Tarif $result kişilik olacak şekilde ölçeklendi.')),
    );
  }

  Future<void> _schedulePrepReminder() async {
    final hours = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text(
                  'Buzluk / ön hazırlık hatırlatıcısı',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text('Kaç saat sonra hatırlatılsın?'),
              ),
              for (final h in [1, 2, 4, 8, 12, 24])
                ListTile(
                  leading: const Icon(Icons.alarm_outlined),
                  title: Text('$h saat sonra'),
                  onTap: () => Navigator.pop(ctx, h),
                ),
            ],
          ),
        );
      },
    );
    if (hours == null || !mounted) return;
    final granted = await NotificationService.requestPermission();
    if (!granted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bildirim izni gerekli.')),
      );
      return;
    }
    await NotificationService.schedulePrepReminder(
      recipeTitle: recipe.title,
      hoursFromNow: hours,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$hours saat sonra hatırlatma kuruldu.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFavorite = ref.watch(favoritesProvider).any((r) => r.id == recipe.id);
    final history = ref.watch(recipeHistoryProvider);
    var cookCount = 0;
    final titleKey = recipe.title.trim().toLowerCase();
    for (final e in history) {
      if (e.title.toLowerCase() == titleKey) {
        cookCount = e.count;
        break;
      }
    }
    final equipment = EquipmentSuggestion.forRecipe(recipe);

    return Scaffold(
      appBar: AppBar(
        title: Text(recipe.title),
        actions: [
          IconButton(
            tooltip: 'Planıma ekle',
            onPressed: () => showAddToPlanSheet(
              context,
              ref: ref,
              recipe: recipe,
            ),
            icon: const Icon(Icons.event_available_outlined),
          ),
          IconButton(
            tooltip: 'Ölçü çevirici',
            onPressed: () => UnitConverterDialog.show(context),
            icon: const Icon(Icons.straighten_outlined),
          ),
          IconButton(
            tooltip: 'Ön hazırlık hatırlat',
            onPressed: _schedulePrepReminder,
            icon: const Icon(Icons.ac_unit_outlined),
          ),
          IconButton(
            tooltip: 'Porsiyon ayarla',
            onPressed: _scaleServings,
            icon: const Icon(Icons.groups_outlined),
          ),
          IconButton(
            tooltip: 'Pişirme modu',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CookingModeScreen(recipe: recipe),
                ),
              );
            },
            icon: const Icon(Icons.soup_kitchen_outlined),
          ),
          IconButton(
            tooltip: isFavorite ? 'Favoriden çıkar' : 'Favorilere ekle',
            onPressed: () {
              ref.read(favoritesProvider.notifier).toggle(recipe);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isFavorite ? 'Favorilerden çıkarıldı.' : 'Favorilere eklendi.',
                  ),
                ),
              );
            },
            icon: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              color: isFavorite ? Colors.redAccent : null,
            ),
          ),
          IconButton(
            tooltip: 'Kopyala',
            onPressed: () => _copy(context),
            icon: const Icon(Icons.copy_outlined),
          ),
          IconButton(
            tooltip: 'Paylaş',
            onPressed: _share,
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => CookingModeScreen(recipe: recipe),
            ),
          );
        },
        icon: const Icon(Icons.play_arrow),
        label: const Text('Pişirmeye başla'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        children: [
          if (cookCount > 0) ...[
            Text(
              'Bu tarifi $cookCount kez plana ekledin',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
          ],
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.kitchen_outlined, color: AppColors.primaryGreenDark),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ekipman: ${equipment.title}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        equipment.detail,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textMuted,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
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

/// Controller'ı diyalog kendi dispose eder — dışarıda erken dispose
/// `_dependents.isEmpty` kırmızısına yol açıyordu.
class _ScaleServingsDialog extends StatefulWidget {
  const _ScaleServingsDialog({required this.initialServings});

  final int initialServings;

  @override
  State<_ScaleServingsDialog> createState() => _ScaleServingsDialogState();
}

class _ScaleServingsDialogState extends State<_ScaleServingsDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.initialServings}');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final n = int.tryParse(_controller.text.trim());
    Navigator.of(context).pop(n);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Kaç kişilik?'),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        autofocus: true,
        onSubmitted: (_) => _submit(),
        decoration: const InputDecoration(
          labelText: 'Kişi sayısı',
          hintText: 'Örn. 6',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Ölçekle'),
        ),
      ],
    );
  }
}
