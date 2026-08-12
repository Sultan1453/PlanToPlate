import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/date_utils.dart';
import '../models/ingredient.dart';
import '../models/recipe.dart';
import '../models/weekly_plan.dart';
import 'hive_service.dart';
import 'shopping_list_service.dart';

/// Kullanıcının ŞU AN görüntülediği haftalık planı (`WeeklyPlan`) tutan
/// ve bu plan üzerinde yapılan TÜM değişiklikleri (tarif atama/kaldırma,
/// alışveriş listesi işaretleme, manuel ürün ekleme/silme) Hive'a
/// kaydedip ekranı yeniden çizdiren Riverpod katmanı.
///
/// Bkz. `data/services/user_provider.dart` — aynı "mutable HiveObject +
/// `state = state` ile elle bildirim" deseni burada da kullanılıyor.
class WeeklyPlanNotifier extends StateNotifier<WeeklyPlan> {
  WeeklyPlanNotifier() : super(_loadOrCreateCurrentWeek());

  /// Uygulama açıldığında, içinde bulunduğumuz haftaya ait bir
  /// `WeeklyPlan` var mı diye Hive kutusunda arar; yoksa (örn. uygulama
  /// ilk kez açıldıysa veya yeni bir haftaya geçildiyse) BOŞ bir tane
  /// oluşturup kaydeder.
  static WeeklyPlan _loadOrCreateCurrentWeek() {
    final thisWeekStart = startOfWeek(DateTime.now());
    final box = HiveService.weeklyPlanBox;

    for (final plan in box.values) {
      if (isSameCalendarDay(plan.weekStartDate, thisWeekStart)) {
        return plan;
      }
    }

    final newPlan = WeeklyPlan(id: const Uuid().v4(), weekStartDate: thisWeekStart);
    box.put(newPlan.id, newPlan);
    return newPlan;
  }

  void _persistAndNotify() {
    if (state.isInBox) {
      state.save();
    }
    // ignore: avoid_self_assignment (bilerek: Riverpod'a "değişti" demek için)
    state = state;
  }

  /// Verilen Pazartesi tarihine ait planı yükler; yoksa boş bir tane oluşturur.
  WeeklyPlan _loadOrCreateWeek(DateTime weekStart) {
    final normalized = startOfWeek(weekStart);
    final box = HiveService.weeklyPlanBox;

    for (final plan in box.values) {
      if (isSameCalendarDay(plan.weekStartDate, normalized)) {
        return plan;
      }
    }

    final newPlan = WeeklyPlan(id: const Uuid().v4(), weekStartDate: normalized);
    box.put(newPlan.id, newPlan);
    return newPlan;
  }

  /// Bir önceki haftaya geçer.
  void goToPreviousWeek() {
    state = _loadOrCreateWeek(state.weekStartDate.subtract(const Duration(days: 7)));
  }

  /// Bir sonraki haftaya geçer.
  void goToNextWeek() {
    state = _loadOrCreateWeek(state.weekStartDate.add(const Duration(days: 7)));
  }

  /// Takvimdeki içinde bulunulan haftaya döner.
  void goToCurrentWeek() {
    state = _loadOrCreateWeek(DateTime.now());
  }

  /// Görüntülenen hafta, takvimdeki "bu hafta" mı?
  bool get isViewingCurrentWeek =>
      isSameCalendarDay(state.weekStartDate, startOfWeek(DateTime.now()));

  /// Belirli bir gün/öğün hücresine bir tarif atar. AI üretimi bittiğinde
  /// (bkz. `WeeklyPlannerScreen`) çağrılır.
  void assignRecipe(DayOfWeek day, MealType mealType, Recipe recipe) {
    state.mealFor(day, mealType).recipe = recipe;
    _persistAndNotify();
  }

  /// Bir hücredeki tarifi kaldırır (kullanıcı "kaldır" dediğinde).
  void clearMeal(DayOfWeek day, MealType mealType) {
    state.mealFor(day, mealType).recipe = null;
    _persistAndNotify();
  }

  /// Alışveriş listesindeki bir satırın işaretini (evde var / alındı)
  /// açar/kapatır. Zaten test edilmiş olan `ShoppingListService`
  /// mantığını ÇAĞIRIR, sadece işlemden sonra Riverpod'a haber verir.
  void toggleShoppingItem(ShoppingListEntry entry) {
    ShoppingListService.toggleChecked(state, entry);
    _persistAndNotify();
  }

  /// Kullanıcının elle eklediği ekstra bir alışveriş ürününü kaydeder.
  void addManualShoppingItem({
    required String name,
    required double quantity,
    required String unit,
    required IngredientCategory category,
  }) {
    ShoppingListService.addManualItem(
      plan: state,
      name: name,
      quantity: quantity,
      unit: unit,
      category: category,
    );
    _persistAndNotify();
  }

  /// Daha önce manuel eklenen bir ürünü listeden tamamen kaldırır.
  void removeManualShoppingItem(Ingredient ingredient) {
    ShoppingListService.removeManualItem(state, ingredient);
    _persistAndNotify();
  }
}

/// Uygulama genelinde `ref.watch(weeklyPlanProvider)` ile GÜNCEL haftalık
/// planı okumak, `ref.read(weeklyPlanProvider.notifier)` ile de yukarıdaki
/// metodları çağırmak için kullanılan TEK giriş noktası.
final weeklyPlanProvider = StateNotifierProvider<WeeklyPlanNotifier, WeeklyPlan>((ref) {
  return WeeklyPlanNotifier();
});
