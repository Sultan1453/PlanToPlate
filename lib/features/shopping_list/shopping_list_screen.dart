import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/ingredient.dart';
import '../../data/services/fridge_inventory_provider.dart';
import '../../data/services/market_deeplink_service.dart';
import '../../data/services/shopping_list_exchange.dart';
import '../../data/services/shopping_list_service.dart';
import '../../data/services/weekly_plan_provider.dart';
import '../common/voice_ingredient_sheet.dart';

/// Alışveriş listesi: iki sekme.
/// 1) Yemek Malzemeleri — haftalık plandaki tariflerden otomatik
/// 2) Ev İhtiyaçları — kullanıcının elle eklediği ürünler
class ShoppingListScreen extends ConsumerStatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  ConsumerState<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends ConsumerState<ShoppingListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(weeklyPlanProvider);
    final ownedAtHome = ref.watch(fridgeInventoryProvider).map((e) => e.name);
    final autoGrouped = ShoppingListService.buildAutoShoppingList(
      plan,
      ownedAtHome: ownedAtHome,
    );
    final manualEntries = ShoppingListService.buildManualShoppingList(plan);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alışveriş Listesi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.mic_none),
            tooltip: 'Sesli ekle',
            onPressed: () async {
              final items = await showVoiceIngredientSheet(context);
              if (items == null || items.isEmpty || !mounted) return;
              _tabController.animateTo(1);
              for (final name in items) {
                ref.read(weeklyPlanProvider.notifier).addManualShoppingItem(
                      name: name,
                      quantity: 1,
                      unit: 'adet',
                      category: IngredientCategory.other,
                    );
              }
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${items.length} ürün ev ihtiyaçlarına eklendi.')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.group_add_outlined),
            tooltip: 'Ortak liste',
            onPressed: () => _showPartnerListSheet(autoGrouped, manualEntries),
          ),
          IconButton(
            icon: const Icon(Icons.storefront_outlined),
            tooltip: 'Markette ara',
            onPressed: () => _openMarketTransfer(autoGrouped, manualEntries),
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Listeyi paylaş',
            onPressed: () => _shareList(autoGrouped, manualEntries),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Ev ihtiyacı ekle',
            onPressed: () {
              _tabController.animateTo(1);
              _showAddManualItemDialog(context);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryGreenDark,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.primaryGreen,
          tabs: [
            Tab(
              text: autoGrouped.isEmpty
                  ? 'Malzemeler'
                  : 'Malzemeler (${_countEntries(autoGrouped)})',
            ),
            Tab(
              text: manualEntries.isEmpty
                  ? 'Ev İhtiyaçları'
                  : 'Ev İhtiyaçları (${manualEntries.length})',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _AutoIngredientsTab(grouped: autoGrouped),
          _HouseholdNeedsTab(entries: manualEntries),
        ],
      ),
    );
  }

  int _countEntries(Map<IngredientCategory, List<ShoppingListEntry>> grouped) {
    return grouped.values.fold<int>(0, (sum, list) => sum + list.length);
  }

  Future<void> _shareList(
    Map<IngredientCategory, List<ShoppingListEntry>> autoGrouped,
    List<ShoppingListEntry> manualEntries,
  ) async {
    final buffer = StringBuffer('Alışveriş Listesi\n');
    buffer.writeln('— PlanToPlate —\n');

    if (autoGrouped.isNotEmpty) {
      buffer.writeln('Malzemeler:');
      for (final category in autoGrouped.keys) {
        buffer.writeln('\n${category.displayName}');
        for (final entry in autoGrouped[category]!) {
          final ing = entry.ingredient;
          final qty = ing.quantity == ing.quantity.roundToDouble()
              ? ing.quantity.toStringAsFixed(0)
              : ing.quantity.toStringAsFixed(1);
          final mark = ing.isChecked ? '✓' : '☐';
          buffer.writeln('$mark $qty ${ing.unit} ${ing.name}');
        }
      }
    }

    if (manualEntries.isNotEmpty) {
      buffer.writeln('\nEv İhtiyaçları:');
      for (final entry in manualEntries) {
        final ing = entry.ingredient;
        final qty = ing.quantity == ing.quantity.roundToDouble()
            ? ing.quantity.toStringAsFixed(0)
            : ing.quantity.toStringAsFixed(1);
        final mark = ing.isChecked ? '✓' : '☐';
        buffer.writeln('$mark $qty ${ing.unit} ${ing.name}');
      }
    }

    final text = buffer.toString().trim();
    if (text == 'Alışveriş Listesi\n— PlanToPlate —') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paylaşılacak ürün yok.')),
      );
      return;
    }

    await Share.share(text, subject: 'Alışveriş Listesi');
  }

  Future<void> _openMarketTransfer(
    Map<IngredientCategory, List<ShoppingListEntry>> autoGrouped,
    List<ShoppingListEntry> manualEntries,
  ) async {
    final missing = <Ingredient>[
      for (final list in autoGrouped.values)
        for (final e in list)
          if (!e.ingredient.isChecked) e.ingredient,
      for (final e in manualEntries)
        if (!e.ingredient.isChecked) e.ingredient,
    ];
    if (missing.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Eksik malzeme yok — markette aranacak ürün yok.')),
      );
      return;
    }

    final channel = await showModalBottomSheet<MarketChannel>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Markette ara',
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${missing.length} eksik malzeme seçilen markette aranacak '
                  '(gerçek sepet aktarımı partner API gerektirir).',
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textMuted,
                      ),
                ),
                const SizedBox(height: 12),
                for (final c in MarketChannel.values)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.storefront_outlined),
                    title: Text(c.displayName),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () => Navigator.pop(ctx, c),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (channel == null || !mounted) return;

    final uri = MarketDeeplinkService.buildSearchUri(
      channel: channel,
      items: missing,
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? '${channel.displayName} araması açıldı.'
              : 'Bağlantı açılamadı: $uri',
        ),
      ),
    );
  }

  Future<void> _showPartnerListSheet(
    Map<IngredientCategory, List<ShoppingListEntry>> autoGrouped,
    List<ShoppingListEntry> manualEntries,
  ) async {
    final plan = ref.read(weeklyPlanProvider);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Eş / ev arkadaşı ile liste',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sunucu yok: kodu WhatsApp ile gönder, karşı taraf “İçe aktar” ile kendi telefonuna alsın. İşaretler ve ev ihtiyaçları birleşir.',
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                    ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  final payload = ShoppingListExchange.exportPayload(plan);
                  await Clipboard.setData(ClipboardData(text: payload));
                  await Share.share(
                    payload,
                    subject: 'PlanToPlate ortak liste',
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                icon: const Icon(Icons.upload_outlined),
                label: const Text('Liste kodunu paylaş'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _importPartnerList();
                },
                icon: const Icon(Icons.download_outlined),
                label: const Text('Kod ile içe aktar'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _importPartnerList() async {
    final controller = TextEditingController();
    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboard?.text != null &&
        clipboard!.text!.contains(ShoppingListExchange.marker)) {
      controller.text = clipboard.text!;
    }

    if (!mounted) return;
    final raw = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Liste kodunu yapıştır'),
        content: TextField(
          controller: controller,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: 'PLANTO_PLATE_LIST_V1 ...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Aktar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (raw == null || raw.trim().isEmpty || !mounted) return;

    try {
      ref.read(weeklyPlanProvider.notifier).importSharedShoppingList(raw);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ortak liste birleştirildi.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  void _showAddManualItemDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => _AddManualItemDialog(
        onAdd: (name, quantity, unit) {
          ref.read(weeklyPlanProvider.notifier).addManualShoppingItem(
                name: name,
                quantity: quantity,
                unit: unit,
                category: IngredientCategory.other,
              );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"$name" ev ihtiyaçlarına eklendi.')),
          );
        },
      ),
    );
  }
}

class _AutoIngredientsTab extends ConsumerWidget {
  const _AutoIngredientsTab({required this.grouped});

  final Map<IngredientCategory, List<ShoppingListEntry>> grouped;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (grouped.isEmpty) {
      return const _EmptyState(
        icon: Icons.restaurant_menu_outlined,
        title: 'Henüz yemek malzemesi yok',
        body:
            'Haftalık Plan sekmesinden öğün ekledikçe malzemeler burada otomatik toplanır.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        _MarketProgressBanner(grouped: grouped),
        const SizedBox(height: 12),
        Text(
          'Market rotası: reyon sırasıyla. '
          'Miktarlar tezgahtaki satış birimine çevrildi '
          '(manav kg/demet, yağ şişe, baharat paket, et kg…).',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 12),
        for (final category in grouped.keys) ...[
          _SectionHeader(
            icon: _categoryIcon(category),
            title: category.routeTitle,
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                for (final entry in grouped[category]!)
                  _ShoppingItemRow(
                    entry: entry,
                    onToggle: () =>
                        ref.read(weeklyPlanProvider.notifier).toggleShoppingItem(entry),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
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

class _HouseholdNeedsTab extends ConsumerWidget {
  const _HouseholdNeedsTab({required this.entries});

  final List<ShoppingListEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (entries.isEmpty) {
      return const _EmptyState(
        icon: Icons.home_outlined,
        title: 'Ev ihtiyacı eklenmedi',
        body:
            'Tuvalet kağıdı, deterjan gibi yemek dışı ürünleri sağ üstteki + ile buraya ekleyebilirsin.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        Text(
          'Haftalık plandan bağımsız, elle eklediğin ürünler',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 12),
        const _SectionHeader(
          icon: Icons.home_outlined,
          title: 'Ev İhtiyaçları',
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              for (final entry in entries)
                _ShoppingItemRow(
                  entry: entry,
                  onToggle: () =>
                      ref.read(weeklyPlanProvider.notifier).toggleShoppingItem(entry),
                  onDelete: () => ref
                      .read(weeklyPlanProvider.notifier)
                      .removeManualShoppingItem(entry.ingredient),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MarketProgressBanner extends StatelessWidget {
  const _MarketProgressBanner({required this.grouped});

  final Map<IngredientCategory, List<ShoppingListEntry>> grouped;

  @override
  Widget build(BuildContext context) {
    final all = grouped.values.expand((e) => e).toList();
    final total = all.length;
    final done = all.where((e) => e.ingredient.isChecked).length;
    final progress = total == 0 ? 0.0 : done / total;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Market turu · $done / $total alındı',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white,
              color: AppColors.primaryGreenDark,
            ),
          ),
          if (done == total && total > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Tur bitti — afiyet olsun!',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.primaryGreenDark,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primaryGreenDark),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
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

/// Ev ihtiyacı ekleme formu (yemek malzemelerinden ayrı sekme için).
class _AddManualItemDialog extends StatefulWidget {
  const _AddManualItemDialog({required this.onAdd});

  final void Function(String name, double quantity, String unit) onAdd;

  @override
  State<_AddManualItemDialog> createState() => _AddManualItemDialogState();
}

class _AddManualItemDialogState extends State<_AddManualItemDialog> {
  static const List<String> _units = [
    'adet',
    'paket',
    'kutu',
    'şişe',
    'rulo',
    'poşet',
    'litre',
    'kg',
    'gram',
  ];

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  String _selectedUnit = 'adet';

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final quantity = double.tryParse(_quantityController.text.replaceAll(',', '.')) ?? 1;
    widget.onAdd(_nameController.text.trim(), quantity, _selectedUnit);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ev İhtiyacı Ekle'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Tuvalet kağıdı, deterjan gibi yemek dışı ürünler.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Ürün adı'),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Ürün adı gerekli' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _quantityController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Miktar'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey(_selectedUnit),
                initialValue: _selectedUnit,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Birim',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                icon: const Icon(Icons.arrow_drop_down),
                items: _units
                    .map((unit) => DropdownMenuItem(value: unit, child: Text(unit)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _selectedUnit = value);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Vazgeç')),
        ElevatedButton(onPressed: _submit, child: const Text('Ekle')),
      ],
    );
  }
}
