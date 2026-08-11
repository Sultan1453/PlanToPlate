import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/banner_ad_widget.dart';
import '../../data/models/ingredient.dart';
import '../../data/services/ingredient_aggregator_service.dart';
import '../../data/services/shopping_list_service.dart';
import '../../data/services/weekly_plan_provider.dart';

/// "Otomatik Malzeme Birleştirici" + "Alışveriş Listesi" ekranı.
///
/// Haftalık plandaki TÜM tariflerden toplanan malzemeleri (Manav, Kasap,
/// Süt Ürünleri gibi kategorilere ayrılmış olarak) gösterir. Kullanıcı:
/// - Bir satıra dokunarak "evde var / alındı" işaretleyebilir,
/// - Sağ üstteki `+` butonuyla tarifte geçmeyen manuel bir ürün ekleyebilir,
/// - Sadece MANUEL eklediği ürünleri silebilir (otomatik satırlar her
///   zaman tariflerden yeniden hesaplanır, tek tek silinemez — bir
///   malzemeyi tamamen kaldırmak için ilgili tarifi Haftalık Plan'dan
///   kaldırmak gerekir).
class ShoppingListScreen extends ConsumerWidget {
  const ShoppingListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(weeklyPlanProvider);
    final grouped = ShoppingListService.buildShoppingList(plan);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alışveriş Listesi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Ürün Ekle',
            onPressed: () => _showAddManualItemDialog(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: grouped.isEmpty
                ? const _EmptyState()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    children: [
                      for (final category in grouped.keys) ...[
                        _CategoryHeader(category: category),
                        const SizedBox(height: 8),
                        Card(
                          child: Column(
                            children: [
                              for (final entry in grouped[category]!)
                                _ShoppingItemRow(
                                  entry: entry,
                                  onToggle: () =>
                                      ref.read(weeklyPlanProvider.notifier).toggleShoppingItem(entry),
                                  onDelete: entry.isManual
                                      ? () => ref
                                          .read(weeklyPlanProvider.notifier)
                                          .removeManualShoppingItem(entry.ingredient)
                                      : null,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
          ),
          const BannerAdWidget(),
        ],
      ),
    );
  }

  void _showAddManualItemDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (_) => _AddManualItemDialog(
        onAdd: (name, quantity, unit, category) {
          ref.read(weeklyPlanProvider.notifier).addManualShoppingItem(
                name: name,
                quantity: quantity,
                unit: unit,
                category: category,
              );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shopping_basket_outlined, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              'Listeniz şu an boş',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Haftalık Plan sekmesinden birkaç öğün ekleyince, malzemeler otomatik olarak burada toplanır.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.category});

  final IngredientCategory category;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(_categoryIcon(category), size: 18, color: AppColors.primaryGreenDark),
        const SizedBox(width: 8),
        Text(
          category.displayName,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  static IconData _categoryIcon(IngredientCategory category) {
    switch (category) {
      case IngredientCategory.produce:
        return Icons.eco_outlined;
      case IngredientCategory.butcher:
        return Icons.set_meal_outlined;
      case IngredientCategory.dairy:
        return Icons.icecream_outlined;
      case IngredientCategory.pantry:
        return Icons.kitchen_outlined;
      case IngredientCategory.bakery:
        return Icons.bakery_dining_outlined;
      case IngredientCategory.other:
        return Icons.category_outlined;
    }
  }
}

class _ShoppingItemRow extends StatelessWidget {
  const _ShoppingItemRow({required this.entry, required this.onToggle, this.onDelete});

  final ShoppingListEntry entry;
  final VoidCallback onToggle;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final ingredient = entry.ingredient;
    final quantityText = ingredient.quantity == ingredient.quantity.roundToDouble()
        ? ingredient.quantity.toStringAsFixed(0)
        : ingredient.quantity.toStringAsFixed(1);

    return ListTile(
      onTap: onToggle,
      leading: Checkbox(value: ingredient.isChecked, onChanged: (_) => onToggle()),
      title: Text(
        ingredient.name,
        style: TextStyle(
          decoration: ingredient.isChecked ? TextDecoration.lineThrough : null,
          color: ingredient.isChecked ? AppColors.textMuted : AppColors.textDark,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$quantityText ${ingredient.unit}', style: const TextStyle(color: AppColors.textMuted)),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
              onPressed: onDelete,
              tooltip: 'Sil',
            ),
        ],
      ),
    );
  }
}

/// Kullanıcının tarifte geçmeyen ekstra bir ürün (örn. "Tuvalet Kağıdı")
/// eklemesi için basit bir form diyaloğu.
class _AddManualItemDialog extends StatefulWidget {
  const _AddManualItemDialog({required this.onAdd});

  final void Function(String name, double quantity, String unit, IngredientCategory category) onAdd;

  @override
  State<_AddManualItemDialog> createState() => _AddManualItemDialogState();
}

class _AddManualItemDialogState extends State<_AddManualItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _unitController = TextEditingController(text: 'adet');
  IngredientCategory _category = IngredientCategory.other;

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final quantity = double.tryParse(_quantityController.text.replaceAll(',', '.')) ?? 1;
    widget.onAdd(_nameController.text.trim(), quantity, _unitController.text.trim(), _category);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ürün Ekle'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Ürün adı'),
              validator: (value) => (value == null || value.trim().isEmpty) ? 'Ürün adı gerekli' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _quantityController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Miktar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _unitController,
                    decoration: const InputDecoration(labelText: 'Birim'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<IngredientCategory>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Kategori'),
              items: IngredientAggregatorService.marketVisitOrder
                  .map((category) => DropdownMenuItem(value: category, child: Text(category.displayName)))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _category = value);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Vazgeç')),
        ElevatedButton(onPressed: _submit, child: const Text('Ekle')),
      ],
    );
  }
}
