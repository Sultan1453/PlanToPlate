import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/banner_ad_widget.dart';
import '../../data/models/recipe.dart';
import '../../data/models/weekly_plan.dart';
import '../../data/models/user.dart';
import '../../data/services/recipe_ai_service.dart';
import '../../data/services/recipe_ai_service_provider.dart';
import '../../data/services/user_provider.dart';
import '../../data/services/weekly_plan_provider.dart';
import '../paywall/paywall_screen.dart';
import '../recipe_detail/recipe_detail_screen.dart';
import 'meal_name_input_sheet.dart';

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
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: _RecipeCreditsBadge(user: user)),
          ),
        ],
      ),
      body: Column(
        children: [
          _WeekHeader(
            weekStartDate: plan.weekStartDate,
            isCurrentWeek: isSameCalendarDay(plan.weekStartDate, startOfWeek(DateTime.now())),
            onPrevious: () => ref.read(weeklyPlanProvider.notifier).goToPreviousWeek(),
            onNext: () => ref.read(weeklyPlanProvider.notifier).goToNextWeek(),
            onGoToCurrent: () => ref.read(weeklyPlanProvider.notifier).goToCurrentWeek(),
          ),
          _DaySelector(
            selectedDay: _selectedDay,
            onDaySelected: (day) => setState(() => _selectedDay = day),
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
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const BannerAdWidget(),
        ],
      ),
    );
  }

  Future<void> _handleAddMeal(MealType mealType) async {
    // Önce kullanıcıdan girdi al; vazgeçerse hiçbir hak harcanmasın.
    final input = await showMealNameInputSheet(context, mealType: mealType);
    if (input == null || !mounted) return;

    final userNotifier = ref.read(userProvider.notifier);
    var consumedRecipe = false;
    var consumedPhoto = false;

    if (input.isPhoto) {
      // Fotoğraftan tarif: hem fotoğraf hakkı (haftada 1) HEM DE AI tarif
      // hakkı (haftada 3) harcanır — çünkü sonuç yine bir AI tarifidir.
      if (!userNotifier.tryConsumePhotoUpload()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bu haftaki fotoğraf hakkın doldu. Premium ile sınırsız kullanabilirsin.'),
          ),
        );
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PaywallScreen()));
        return;
      }
      consumedPhoto = true;

      if (!userNotifier.tryConsumeRecipeGeneration()) {
        userNotifier.refundLastPhotoUpload();
        if (!mounted) return;
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PaywallScreen()));
        return;
      }
      consumedRecipe = true;
    } else {
      if (!userNotifier.tryConsumeRecipeGeneration()) {
        if (!mounted) return;
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PaywallScreen()));
        return;
      }
      consumedRecipe = true;
    }

    setState(() => _isGenerating = true);
    try {
      final ai = ref.read(recipeAiServiceProvider);
      final id = DateTime.now().microsecondsSinceEpoch.toString();
      final Recipe recipe;
      if (input.isPhoto) {
        recipe = await ai.generateRecipeFromPhoto(
          id: id,
          imageBytes: input.photoBytes!,
          mimeType: input.photoMimeType ?? 'image/jpeg',
          mealType: mealType,
        );
      } else {
        recipe = await ai.generateRecipe(
          id: id,
          mealName: input.mealName!.trim(),
          mealType: mealType,
        );
      }
      ref.read(weeklyPlanProvider.notifier).assignRecipe(_selectedDay, mealType, recipe);
    } on RecipeGenerationException catch (error) {
      if (consumedRecipe) userNotifier.refundLastRecipeGeneration();
      if (consumedPhoto) userNotifier.refundLastPhotoUpload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _openRecipeDetail(Recipe recipe) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: recipe)));
  }
}

/// Görüntülenen haftanın tarih aralığını gösteren başlık + ileri/geri oklar.
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
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onGoToCurrent;

  static const List<String> _turkishMonths = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
  ];

  @override
  Widget build(BuildContext context) {
    final weekEndDate = weekStartDate.add(const Duration(days: 6));
    final rangeText = '${weekStartDate.day} - ${weekEndDate.day} ${_turkishMonths[weekEndDate.month - 1]}';
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
  final ValueChanged<DayOfWeek> onDaySelected;

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
            onSelected: (_) => onDaySelected(day),
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

    final remainingWeekly = (3 - user.weeklyRecipeGenerationCount).clamp(0, 3);
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
  });

  final PlannedMeal meal;
  final VoidCallback onTapEmpty;
  final VoidCallback onTapFilled;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final recipe = meal.recipe;

    if (recipe == null) {
      return InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTapEmpty,
        child: DottedCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(_mealTypeIcon(meal.mealType), color: AppColors.primaryGreenDark),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    meal.mealType.displayName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
                },
                itemBuilder: (context) => const [
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
