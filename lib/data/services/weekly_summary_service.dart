import '../models/ingredient.dart';
import '../models/recipe.dart';
import '../models/weekly_plan.dart';
import 'weekly_budget_calorie_service.dart';

/// Haftalık plan özeti + paylaşılabilir menü metni.
class WeeklySummary {
  const WeeklySummary({
    required this.plannedMeals,
    required this.totalSlots,
    required this.topTitles,
    required this.topCategories,
    required this.shareText,
    required this.weekLabel,
    required this.dayLines,
    required this.stats,
  });

  final int plannedMeals;
  final int totalSlots;
  final List<String> topTitles;
  final List<String> topCategories;
  final String shareText;
  final String weekLabel;
  final List<String> dayLines;
  final WeeklyBudgetCalorieSummary stats;

  int get emptySlots => totalSlots - plannedMeals;
}

class WeeklySummaryService {
  WeeklySummaryService._();

  static WeeklySummary build(WeeklyPlan plan) {
    final recipes = plan.meals
        .where((m) => m.recipe != null)
        .map((m) => m.recipe!)
        .toList();

    final titles = recipes.map((r) => r.title).toList();
    final categoryCounts = <IngredientCategory, int>{};
    for (final recipe in recipes) {
      for (final ing in recipe.ingredients) {
        categoryCounts[ing.category] = (categoryCounts[ing.category] ?? 0) + 1;
      }
    }
    final topCategories = categoryCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final categoryNames =
        topCategories.take(3).map((e) => e.key.displayName).toList();

    final weekStart = plan.weekStartDate;
    final weekEnd = weekStart.add(const Duration(days: 6));
    final weekLabel =
        '${_formatDayMonth(weekStart)} – ${_formatDayMonth(weekEnd)}';

    final dayLines = <String>[];
    final buffer = StringBuffer();
    buffer.writeln('🍽️ PlanToPlate — Bu Haftanın Menüsü');
    buffer.writeln(weekLabel);
    buffer.writeln('');

    for (final day in DayOfWeek.values) {
      final slots =
          MealType.values.map((mt) => plan.mealFor(day, mt)).toList();
      final hasAny = slots.any((s) => s.recipe != null);
      if (!hasAny) continue;

      buffer.writeln('📅 ${day.displayName}');
      final previewParts = <String>[];
      for (final slot in slots) {
        final title = slot.recipe?.title.trim();
        if (title == null || title.isEmpty) continue;
        buffer.writeln('  • ${slot.mealType.displayName}: $title');
        previewParts.add('${slot.mealType.displayName}: $title');
      }
      buffer.writeln('');
      if (previewParts.isNotEmpty) {
        dayLines.add('${day.shortDisplayName} — ${previewParts.join(' · ')}');
      }
    }

    if (recipes.isEmpty) {
      buffer.writeln('Bu hafta henüz yemek eklenmedi.');
      buffer.writeln('');
    }

    final stats = WeeklyBudgetCalorieService.build(plan);
    final totalSlots = DayOfWeek.values.length * MealType.values.length;

    buffer.writeln('${recipes.length} / $totalSlots öğün planlı');
    if (categoryNames.isNotEmpty) {
      buffer.writeln('Alışverişte öne çıkan: ${categoryNames.join(', ')}');
    }
    buffer.writeln('');
    buffer.writeln('🔥 Kalori (hafta): ${stats.caloriesLabel}');
    buffer.writeln(
      '   Ort. gün: ${stats.avgDailyCalories.round()} kcal · '
      'P ${stats.totalProtein.round()}g · '
      'K ${stats.totalCarbs.round()}g · '
      'Y ${stats.totalFat.round()}g',
    );
    buffer.writeln('🛒 Tahmini alışveriş: ${stats.budgetLabel}');
    if (stats.topCostLines.isNotEmpty) {
      buffer.writeln('   En maliyetli:');
      for (final line in stats.topCostLines) {
        buffer.writeln('   • ${line.label} (~₺${line.tryAmount.round()})');
      }
    }
    buffer.writeln('');
    buffer.writeln('PlanToPlate ile hazırlandı');
    buffer.writeln('(Bütçe tahmindir; market fiyatları değişebilir.)');

    return WeeklySummary(
      plannedMeals: recipes.length,
      totalSlots: totalSlots,
      topTitles: titles.take(5).toList(),
      topCategories: categoryNames,
      shareText: buffer.toString().trimRight(),
      weekLabel: weekLabel,
      dayLines: dayLines,
      stats: stats,
    );
  }

  static const _monthsTr = [
    'Oca',
    'Şub',
    'Mar',
    'Nis',
    'May',
    'Haz',
    'Tem',
    'Ağu',
    'Eyl',
    'Eki',
    'Kas',
    'Ara',
  ];

  static String _formatDayMonth(DateTime d) =>
      '${d.day} ${_monthsTr[d.month - 1]}';
}

/// Tarif porsiyonunu ölçekler (malzeme miktarları + servings).
class RecipeScaler {
  RecipeScaler._();

  static void scaleToServings(Recipe recipe, int newServings) {
    final target = newServings.clamp(1, 24);
    final old = recipe.servings <= 0 ? 1 : recipe.servings;
    if (target == old) return;
    final factor = target / old;
    for (final ing in recipe.ingredients) {
      final scaled = ing.quantity * factor;
      ing.quantity = scaled >= 10
          ? scaled.roundToDouble()
          : (scaled * 10).roundToDouble() / 10;
    }
    recipe.servings = target;
  }
}

/// Sesle söylenen metni malzeme adına böler.
class SpokenIngredientParser {
  SpokenIngredientParser._();

  static List<String> parse(String spoken) {
    var text = spoken.trim().toLowerCase();
    if (text.isEmpty) return [];
    text = text
        .replaceAll(' lütfen', '')
        .replaceAll(' ekle', '')
        .replaceAll(' ve ', ',')
        .replaceAll(' ile ', ',')
        .replaceAll(';', ',')
        .replaceAll('،', ',');

    return text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.length >= 2)
        .map(_titleCaseTr)
        .toList();
  }

  static String _titleCaseTr(String input) {
    if (input.isEmpty) return input;
    return input[0].toUpperCase() + input.substring(1);
  }
}
