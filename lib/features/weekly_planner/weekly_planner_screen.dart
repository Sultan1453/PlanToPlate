import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/recipe.dart';
import '../../data/models/recipe_constraints.dart';
import '../../data/models/weekly_plan.dart';
import '../../data/models/user.dart';
import '../../data/services/fridge_inventory_provider.dart';
import '../../data/services/household_prefs_provider.dart';
import '../../data/services/recipe_ai_service.dart';
import '../../data/services/recipe_ai_service_provider.dart';
import '../../data/services/recipe_history_provider.dart';
import '../../data/services/user_provider.dart';
import '../../data/services/weekly_plan_provider.dart';
import '../paywall/paywall_screen.dart';
import '../recipe_detail/recipe_detail_screen.dart';
import 'meal_name_input_sheet.dart';
import 'weekly_summary_sheet.dart';
import '../../data/services/weekly_summary_service.dart';
import '../discover/discover_screen.dart';
import '../quick_snack/quick_snack_screen.dart';

/// Adım 7'nin ANA ekranı: Pazartesi'den Pazar'a gün seçici + seçili
/// günün Kahvaltı/Öğle/Akşam kartları.
///
/// Kullanıcı boş bir slota dokunduğunda:
/// 1) Önce hakkı var mı kontrol edilir (`userProvider.tryConsumeRecipeGeneration`,
///    Kural 1),
/// 2) Hakkı yoksa Paywall ekranı açılır (Kural 2),
/// 3) Hakkı varsa yemek adı sorulur ve AI (Mock veya Gemini — hangisinin
///    aktif olduğu `recipeAiServiceProvider` tarafından otomatik seçilir)
///    tarif üretir,
/// 4) Üretilen tarif o slota kaydedilir (`weeklyPlanProvider.assignRecipe`).
class WeeklyPlannerScreen extends ConsumerStatefulWidget {
  const WeeklyPlannerScreen({super.key});

  @override
  ConsumerState<WeeklyPlannerScreen> createState() => _WeeklyPlannerScreenState();
}

class _WeeklyPlannerScreenState extends ConsumerState<WeeklyPlannerScreen> {
  late DayOfWeek _selectedDay = _todayAsDayOfWeek();
  bool _isGenerating = false;

  // `DateTime.weekday`: Pazartesi=1 ... Pazar=7. `DayOfWeek.values` sırası
  // da Pazartesi'den başladığı için `index = weekday - 1` doğrudan eşleşir.
  static DayOfWeek _todayAsDayOfWeek() => DayOfWeek.values[DateTime.now().weekday - 1];

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(weeklyPlanProvider);
    final user = ref.watch(userProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PlanToPlate'),
        actions: [
          IconButton(
            tooltip: 'Keşfet',
            onPressed: _isGenerating ? null : _openDiscover,
            icon: const Icon(Icons.auto_awesome_motion_outlined),
          ),
          PopupMenuButton<String>(
            enabled: !_isGenerating,
            tooltip: 'Diğer',
            onSelected: (value) {
              if (value == 'snack') {
                _openQuickSnack();
              } else if (value == 'summary') {
                final summary = WeeklySummaryService.build(plan);
                showWeeklySummarySheet(context, summary: summary);
              } else if (value == 'tomorrow') {
                _handleTomorrowSuggestion();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'snack',
                child: Text('Gece krizleri / atıştırmalık'),
              ),
              PopupMenuItem(
                value: 'summary',
                child: Text('Haftalık özet'),
              ),
              PopupMenuItem(
                value: 'tomorrow',
                child: Text('Yarın ne pişireyim?'),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(child: _RecipeCreditsBadge(user: user)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: _PlanShortcutCard(
                    color: AppColors.primaryGreen,
                    icon: Icons.auto_awesome_motion,
                    title: 'Keşfet',
                    subtitle: 'Swipe ile tarif bul',
                    onTap: _isGenerating ? null : _openDiscover,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PlanShortcutCard(
                    color: const Color(0xFF1A1A2E),
                    icon: Icons.nightlife,
                    iconColor: const Color(0xFFFFC857),
                    title: 'Gece krizi',
                    subtitle: '5 dk atıştırmalık',
                    onTap: _isGenerating ? null : _openQuickSnack,
                  ),
                ),
              ],
            ),
          ),
          _WeekHeader(
            weekStartDate: plan.weekStartDate,
            isCurrentWeek: isSameCalendarDay(plan.weekStartDate, startOfWeek(DateTime.now())),
            // AI üretirken hafta/gün değiştirmek, tarifi yanlış slota
            // yazılmasına yol açabilir — bu yüzden kilitliyoruz.
            onPrevious: _isGenerating
                ? null
                : () => ref.read(weeklyPlanProvider.notifier).goToPreviousWeek(),
            onNext: _isGenerating
                ? null
                : () => ref.read(weeklyPlanProvider.notifier).goToNextWeek(),
            onGoToCurrent: _isGenerating
                ? null
                : () => ref.read(weeklyPlanProvider.notifier).goToCurrentWeek(),
          ),
          _DaySelector(
            selectedDay: _selectedDay,
            onDaySelected: _isGenerating
                ? null
                : (day) => setState(() => _selectedDay = day),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: _isGenerating
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    children: MealType.values.map((mealType) {
                      final meal = plan.mealFor(_selectedDay, mealType);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _MealSlotCard(
                          meal: meal,
                          onTapEmpty: () => _handleAddMeal(mealType),
                          onTapFilled: () => _openRecipeDetail(meal.recipe!),
                          onRemove: () =>
                              ref.read(weeklyPlanProvider.notifier).clearMeal(_selectedDay, mealType),
                          onSwap: () => _handleSwapMeal(mealType),
                          onPickFrequent: () => _pickFromHistory(mealType),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  void _openDiscover() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const DiscoverScreen()),
    );
  }

  void _openQuickSnack() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const QuickSnackScreen()),
    );
  }

  Future<void> _handleAddMeal(MealType mealType) async {
    // Çift dokunuş / eşzamanlı ekleme: ikinci çağrı hakları iki kez harcamasın.
    if (_isGenerating) return;

    // Önce kullanıcıdan girdi al; vazgeçerse hiçbir hak harcanmasın.
    final input = await showMealNameInputSheet(context, mealType: mealType);
    if (input == null || !mounted) return;
    if (_isGenerating) return;

    // Hak düşümünden ÖNCE UI'ı kilitle — aksi halde spinner gelmeden
    // ikinci bir öğün ekleme başlayabilir.
    setState(() => _isGenerating = true);

    final userNotifier = ref.read(userProvider.notifier);
    var consumedRecipe = false;
    var consumedPhoto = false;

    try {
      if (input.isPhoto) {
        // Fotoğraftan tarif: hem fotoğraf hakkı (haftada 1) HEM DE AI tarif
        // hakkı (haftada User.weeklyFreeRecipeLimit) harcanır — çünkü sonuç yine bir AI tarifidir.
        if (!userNotifier.tryConsumePhotoUpload()) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bu haftaki fotoğraf hakkın doldu. Premium ile sınırsız kullanabilirsin.'),
            ),
          );
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const PaywallScreen(reason: PaywallReason.photoQuota),
            ),
          );
          return;
        }
        consumedPhoto = true;

        if (!userNotifier.tryConsumeRecipeGeneration()) {
          userNotifier.refundLastPhotoUpload();
          if (!mounted) return;
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const PaywallScreen(reason: PaywallReason.recipeQuota),
            ),
          );
          return;
        }
        consumedRecipe = true;
      } else {
        if (!userNotifier.tryConsumeRecipeGeneration()) {
          if (!mounted) return;
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const PaywallScreen(reason: PaywallReason.recipeQuota),
            ),
          );
          return;
        }
        consumedRecipe = true;
      }

      // Üretim başında gün + haftayı sabitle; AI beklerken kullanıcı
      // başka güne/haftaya geçse bile tarif doğru slota yazılır.
      final targetDay = _selectedDay;
      final planSnapshot = ref.read(weeklyPlanProvider);
      final targetWeekStart = planSnapshot.weekStartDate;
      final planTitles = planSnapshot.plannedRecipeTitles;

      final ai = ref.read(recipeAiServiceProvider);
      final id = const Uuid().v4();
      final Recipe recipe;
      if (input.isPhoto) {
        recipe = await ai.generateRecipeFromPhoto(
          id: id,
          imageBytes: input.photoBytes!,
          mimeType: input.photoMimeType ?? 'image/jpeg',
          mealType: mealType,
          constraints: RecipeConstraints(
            excludeTitles: planTitles,
          )
              .merge(input.constraints)
              .merge(ref.read(householdPrefsProvider).toConstraints()),
        );
      } else {
        recipe = await ai.generateRecipe(
          id: id,
          mealName: input.mealName!.trim(),
          mealType: mealType,
          constraints: RecipeConstraints(
            excludeTitles: planTitles,
          )
              .merge(input.constraints)
              .merge(ref.read(householdPrefsProvider).toConstraints()),
        );
      }
      ref.read(weeklyPlanProvider.notifier).assignRecipeForWeek(
            weekStartDate: targetWeekStart,
            day: targetDay,
            mealType: mealType,
            recipe: recipe,
          );
      ref.read(recipeHistoryProvider.notifier).record(recipe);
    } catch (error) {
      if (consumedRecipe) userNotifier.refundLastRecipeGeneration();
      if (consumedPhoto) userNotifier.refundLastPhotoUpload();
      if (!mounted) return;
      final message = error is RecipeGenerationException
          ? error.message
          : 'Tarif oluşturulamadı. Lütfen tekrar dene.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _handleTomorrowSuggestion() async {
    if (_isGenerating) return;

    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final tomorrowDay = DayOfWeek.values[tomorrow.weekday - 1];
    final plan = ref.read(weeklyPlanProvider);
    const mealType = MealType.dinner;

    if (plan.mealFor(tomorrowDay, mealType).recipe != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${tomorrowDay.displayName} akşamı zaten dolu. Önce o tarifi kaldırabilirsin.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _selectedDay = tomorrowDay;
    });

    final userNotifier = ref.read(userProvider.notifier);
    if (!userNotifier.tryConsumeRecipeGeneration()) {
      if (!mounted) return;
      setState(() => _isGenerating = false);
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const PaywallScreen(reason: PaywallReason.recipeQuota),
        ),
      );
      return;
    }

    try {
      final fridge = ref.read(fridgeInventoryProvider.notifier).namesForAi();
      final ai = ref.read(recipeAiServiceProvider);
      final id = const Uuid().v4();
      final constraints = RecipeConstraints(
        excludeTitles: plan.plannedRecipeTitles,
        maxTotalMinutes: 45,
        preferFewIngredients: true,
      ).merge(ref.read(householdPrefsProvider).toConstraints());

      final Recipe recipe;
      if (fridge.isNotEmpty) {
        final suggestion = await ai.suggestFromIngredients(
          ingredients: fridge,
          constraints: constraints,
        );
        recipe = suggestion.recipes.firstWhere(
          (r) => r.mealType == MealType.dinner,
          orElse: () => suggestion.recipes.first,
        );
      } else {
        recipe = await ai.generateRecipe(
          id: id,
          mealName: 'Pratik ev yemeği',
          mealType: mealType,
          constraints: constraints,
        );
      }

      // suggestFromIngredients yeni id vermiş olabilir; slot için id sabit kalsın
      final toAssign = Recipe(
        id: id,
        title: recipe.title,
        mealType: mealType,
        ingredients: recipe.ingredients,
        steps: recipe.steps,
        nutrient: recipe.nutrient,
        cookingMethod: recipe.cookingMethod,
        servings: recipe.servings,
        prepTimeMinutes: recipe.prepTimeMinutes,
        cookTimeMinutes: recipe.cookTimeMinutes,
      );

      ref.read(weeklyPlanProvider.notifier).assignRecipeForWeek(
            weekStartDate: plan.weekStartDate,
            day: tomorrowDay,
            mealType: mealType,
            recipe: toAssign,
          );
      ref.read(recipeHistoryProvider.notifier).record(toAssign);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Yarın akşam: ${toAssign.title}')),
      );
    } catch (error) {
      userNotifier.refundLastRecipeGeneration();
      if (!mounted) return;
      final message = error is RecipeGenerationException
          ? error.message
          : 'Öneri alınamadı. Lütfen tekrar dene.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _handleSwapMeal(MealType mealType) async {
    if (_isGenerating) return;
    final plan = ref.read(weeklyPlanProvider);
    final current = plan.mealFor(_selectedDay, mealType).recipe;
    if (current == null) return;

    setState(() => _isGenerating = true);
    final userNotifier = ref.read(userProvider.notifier);
    if (!userNotifier.tryConsumeRecipeGeneration()) {
      if (!mounted) return;
      setState(() => _isGenerating = false);
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const PaywallScreen(reason: PaywallReason.recipeQuota),
        ),
      );
      return;
    }

    try {
      final ai = ref.read(recipeAiServiceProvider);
      final id = const Uuid().v4();
      final exclude = [
        ...plan.plannedRecipeTitles,
        current.title,
      ];
      final recipe = await ai.generateRecipe(
        id: id,
        mealName: 'Alternatif ${mealType.displayName} yemeği, ${current.title} olmasın',
        mealType: mealType,
        constraints: RecipeConstraints(
          excludeTitles: exclude,
          preferFewIngredients: true,
        ).merge(ref.read(householdPrefsProvider).toConstraints()),
      );
      ref.read(weeklyPlanProvider.notifier).assignRecipeForWeek(
            weekStartDate: plan.weekStartDate,
            day: _selectedDay,
            mealType: mealType,
            recipe: recipe,
          );
      ref.read(recipeHistoryProvider.notifier).record(recipe);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Yeni öneri: ${recipe.title}')),
      );
    } catch (error) {
      userNotifier.refundLastRecipeGeneration();
      if (!mounted) return;
      final message = error is RecipeGenerationException
          ? error.message
          : 'Alternatif alınamadı.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _pickFromHistory(MealType mealType) async {
    final top = ref.read(recipeHistoryProvider.notifier).topFive;
    if (top.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Henüz sık yaptığın yemek yok. Önce birkaç tarif ekle.')),
      );
      return;
    }

    final selected = await showModalBottomSheet<RecipeHistoryEntry>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text(
                'Sık yaptıklarım',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            for (final entry in top)
              ListTile(
                title: Text(entry.title),
                subtitle: Text('${entry.count} kez'),
                onTap: () => Navigator.pop(ctx, entry),
              ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
    if (selected == null || !mounted) return;

    final recipe = ref.read(recipeHistoryProvider.notifier).recipeFromEntry(
          selected,
          mealType: mealType,
        );
    if (recipe == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu kayıttan tarif açılamadı.')),
      );
      return;
    }

    final plan = ref.read(weeklyPlanProvider);
    ref.read(weeklyPlanProvider.notifier).assignRecipeForWeek(
          weekStartDate: plan.weekStartDate,
          day: _selectedDay,
          mealType: mealType,
          recipe: recipe,
        );
    ref.read(recipeHistoryProvider.notifier).record(recipe);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${recipe.title} eklendi (AI hakkı harcanmadı).')),
    );
  }

  void _openRecipeDetail(Recipe recipe) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: recipe)));
  }
}

/// Görüntülenen haftanın tarih aralığını gösteren başlık + ileri/geri oklar.
class _PlanShortcutCard extends StatelessWidget {
  const _PlanShortcutCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.iconColor = Colors.white,
  });

  final Color color;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader({
    required this.weekStartDate,
    required this.isCurrentWeek,
    required this.onPrevious,
    required this.onNext,
    required this.onGoToCurrent,
  });

  final DateTime weekStartDate;
  final bool isCurrentWeek;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onGoToCurrent;

  static const List<String> _turkishMonths = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
  ];

  static String _formatWeekRange(DateTime start, DateTime end) {
    if (start.year == end.year && start.month == end.month) {
      return '${start.day} - ${end.day} ${_turkishMonths[end.month - 1]}';
    }
    if (start.year == end.year) {
      return '${start.day} ${_turkishMonths[start.month - 1]} - '
          '${end.day} ${_turkishMonths[end.month - 1]}';
    }
    return '${start.day} ${_turkishMonths[start.month - 1]} ${start.year} - '
        '${end.day} ${_turkishMonths[end.month - 1]} ${end.year}';
  }

  @override
  Widget build(BuildContext context) {
    final weekEndDate = weekStartDate.add(const Duration(days: 6));
    final rangeText = _formatWeekRange(weekStartDate, weekEndDate);
    final label = isCurrentWeek ? 'Bu hafta' : 'Hafta';

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Önceki hafta',
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
            color: AppColors.primaryGreenDark,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  '$label: $rangeText',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (!isCurrentWeek)
                  TextButton(
                    onPressed: onGoToCurrent,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Bugüne dön'),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Sonraki hafta',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
            color: AppColors.primaryGreenDark,
          ),
        ],
      ),
    );
  }
}

/// Pazartesi'den Pazar'a yatay kaydırılabilir gün seçici.
class _DaySelector extends StatelessWidget {
  const _DaySelector({required this.selectedDay, required this.onDaySelected});

  final DayOfWeek selectedDay;
  final ValueChanged<DayOfWeek>? onDaySelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: DayOfWeek.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final day = DayOfWeek.values[index];
          final isSelected = day == selectedDay;
          return ChoiceChip(
            label: Text(day.shortDisplayName),
            selected: isSelected,
            onSelected: onDaySelected == null ? null : (_) => onDaySelected!(day),
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : AppColors.textDark,
              fontWeight: FontWeight.w700,
            ),
            selectedColor: AppColors.primaryGreen,
            backgroundColor: AppColors.surface,
          );
        },
      ),
    );
  }
}

/// Kullanıcının kalan AI tarifi hakkını gösteren küçük rozet
/// (AppBar'da). Premium kullanıcıda "Sınırsız" gösterilir.
class _RecipeCreditsBadge extends StatelessWidget {
  const _RecipeCreditsBadge({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    if (user.isPremium) {
      return const Chip(
        avatar: Icon(Icons.workspace_premium, size: 16, color: AppColors.accentOrangeDark),
        label: Text('Sınırsız'),
        visualDensity: VisualDensity.compact,
      );
    }

    final remainingWeekly =
        (User.weeklyFreeRecipeLimit - user.weeklyRecipeGenerationCount)
            .clamp(0, User.weeklyFreeRecipeLimit);
    final totalRemaining = remainingWeekly + user.bonusRecipeCredits;

    return Chip(
      avatar: const Icon(Icons.auto_awesome, size: 16, color: AppColors.primaryGreenDark),
      label: Text('$totalRemaining hak kaldı'),
      visualDensity: VisualDensity.compact,
    );
  }
}

/// Tek bir öğün slotunu (Kahvaltı/Öğle/Akşam) çizen kart. Boşsa "+ Yemek
/// Ekle" durumunu, doluysa tarif özetini gösterir.
class _MealSlotCard extends StatelessWidget {
  const _MealSlotCard({
    required this.meal,
    required this.onTapEmpty,
    required this.onTapFilled,
    required this.onRemove,
    required this.onSwap,
    required this.onPickFrequent,
  });

  final PlannedMeal meal;
  final VoidCallback onTapEmpty;
  final VoidCallback onTapFilled;
  final VoidCallback onRemove;
  final VoidCallback onSwap;
  final VoidCallback onPickFrequent;

  @override
  Widget build(BuildContext context) {
    final recipe = meal.recipe;

    if (recipe == null) {
      return InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTapEmpty,
        onLongPress: onPickFrequent,
        child: DottedCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(_mealTypeIcon(meal.mealType), color: AppColors.primaryGreenDark),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meal.mealType.displayName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Dokun: AI · Uzun bas: sık yaptıklarım',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.add_circle, color: AppColors.accentOrange, size: 28),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTapFilled,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.cream,
                child: Icon(_mealTypeIcon(meal.mealType), color: AppColors.primaryGreenDark),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meal.mealType.displayName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                    ),
                    Text(
                      recipe.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${recipe.nutrient.calories.toStringAsFixed(0)} kcal · ${recipe.cookingMethod.displayName}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'remove') onRemove();
                  if (value == 'swap') onSwap();
                  if (value == 'frequent') onPickFrequent();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'swap', child: Text('Bugün istemiyorum (alternatif)')),
                  PopupMenuItem(value: 'frequent', child: Text('Sık yaptıklarımdan değiştir')),
                  PopupMenuItem(value: 'remove', child: Text('Kaldır')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _mealTypeIcon(MealType mealType) {
    switch (mealType) {
      case MealType.breakfast:
        return Icons.free_breakfast_outlined;
      case MealType.lunch:
        return Icons.lunch_dining_outlined;
      case MealType.dinner:
        return Icons.dinner_dining_outlined;
      case MealType.snack:
        return Icons.nightlife_outlined;
    }
  }
}

/// Boş bir öğün slotunu belirginleştirmek için kesikli (dashed) kenarlıklı
/// basit bir kart görünümü. Hazır bir paket eklemeden, `CustomPaint` ile
/// elle çiziyoruz.
class DottedCard extends StatelessWidget {
  const DottedCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(color: AppColors.divider, radius: 20),
      child: child,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final double segmentEnd = distance + dashWidth > metric.length ? metric.length : distance + dashWidth;
        canvas.drawPath(metric.extractPath(distance, segmentEnd), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
