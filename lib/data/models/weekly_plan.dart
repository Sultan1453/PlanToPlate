import 'package:hive/hive.dart';

import 'ingredient.dart';
import 'recipe.dart';

part 'weekly_plan.g.dart';

/// Haftanın günlerini temsil eder. Pazartesi'den başlatıyoruz çünkü
/// Türkiye'de (ve ISO 8601 standardında) hafta Pazartesi başlar.
@HiveType(typeId: 6)
enum DayOfWeek {
  @HiveField(0)
  monday,
  @HiveField(1)
  tuesday,
  @HiveField(2)
  wednesday,
  @HiveField(3)
  thursday,
  @HiveField(4)
  friday,
  @HiveField(5)
  saturday,
  @HiveField(6)
  sunday;

  String get displayName {
    switch (this) {
      case DayOfWeek.monday:
        return 'Pazartesi';
      case DayOfWeek.tuesday:
        return 'Salı';
      case DayOfWeek.wednesday:
        return 'Çarşamba';
      case DayOfWeek.thursday:
        return 'Perşembe';
      case DayOfWeek.friday:
        return 'Cuma';
      case DayOfWeek.saturday:
        return 'Cumartesi';
      case DayOfWeek.sunday:
        return 'Pazar';
    }
  }

  /// Gün seçici (`_DaySelector`) gibi dar alanlarda kullanılan, 3 harfli
  /// kısaltılmış isim (örn. "Pzt", "Sal").
  String get shortDisplayName {
    switch (this) {
      case DayOfWeek.monday:
        return 'Pzt';
      case DayOfWeek.tuesday:
        return 'Sal';
      case DayOfWeek.wednesday:
        return 'Çar';
      case DayOfWeek.thursday:
        return 'Per';
      case DayOfWeek.friday:
        return 'Cum';
      case DayOfWeek.saturday:
        return 'Cmt';
      case DayOfWeek.sunday:
        return 'Paz';
    }
  }
}

/// Haftalık planda TEK BİR hücreyi (slotu) temsil eder: örneğin "Salı günü
/// öğle yemeği için Tarif X seçildi" gibi.
///
/// `WeeklyPlan`, bunlardan 21 tane (7 gün x 3 öğün) tutan bir liste
/// barındıracak.
@HiveType(typeId: 7)
class PlannedMeal extends HiveObject {
  PlannedMeal({
    required this.day,
    required this.mealType,
    this.recipe,
  });

  /// Bu planlanan öğünün haftanın hangi gününe ait olduğu.
  @HiveField(0)
  DayOfWeek day;

  /// Kahvaltı / Öğle / Akşam.
  @HiveField(1)
  MealType mealType;

  /// Bu slota atanan tarif. Kullanıcı henüz bir yemek seçmediyse `null`
  /// (boş) olur; arayüzde bu durumda "+ Yemek Ekle" butonu gösteririz.
  /// `?` işareti bu alanın `null` OLABİLECEĞİNİ belirtir.
  @HiveField(2)
  Recipe? recipe;
}

/// Bir haftalık TÜM yemek planını tutan ana model.
///
/// Uygulama her hafta için bir `WeeklyPlan` nesnesi oluşturur ve içindeki
/// 21 `PlannedMeal` ile "Pazartesi-Pazar, Kahvaltı/Öğle/Akşam" ızgarasını
/// (grid) yönetir.
@HiveType(typeId: 8)
class WeeklyPlan extends HiveObject {
  WeeklyPlan({
    required this.id,
    required this.weekStartDate,
    List<PlannedMeal>? meals,
    List<String>? checkedAutoItemKeys,
    List<Ingredient>? manualItems,
  }) : meals = meals ?? _emptyWeek(),
       checkedAutoItemKeys = checkedAutoItemKeys ?? [],
       manualItems = manualItems ?? [];

  /// Bu haftalık planın benzersiz kimliği.
  @HiveField(0)
  final String id;

  /// Bu planın ait olduğu haftanın Pazartesi tarihi. Bu tarih sayesinde
  /// kullanıcı "önceki hafta" / "sonraki hafta" arasında gezinebilir.
  @HiveField(1)
  DateTime weekStartDate;

  /// Bu haftadaki tüm planlanmış öğünlerin listesi (7 gün x 3 öğün = 21
  /// eleman).
  @HiveField(2)
  List<PlannedMeal> meals;

  /// Tariflerden OTOMATİK toplanan alışveriş listesindeki hangi
  /// malzemelerin "evde var / alındı" olarak işaretlendiğini tutar.
  ///
  /// NEDEN "isim listesi" (anahtar listesi) tutuyoruz, doğrudan
  /// `Ingredient` nesnelerinin kendisini değil? Çünkü otomatik liste her
  /// açılışta tariflerden YENİDEN hesaplanır (bkz.
  /// `IngredientAggregatorService.aggregate`); bu yüzden kalıcı olması
  /// gereken tek şey "hangi malzeme işaretliydi" bilgisidir, o malzemenin
  /// kendisi değil. Her anahtar,
  /// `IngredientAggregatorService.mergeKeyFor(ingredient)` ile üretilen
  /// "isim|birim" biçimindeki bir metindir (örn. "soğan|adet").
  @HiveField(3)
  List<String> checkedAutoItemKeys;

  /// Kullanıcının, herhangi bir tarifte GEÇMEYEN, kendi elleriyle
  /// alışveriş listesine eklediği ekstra ürünler (örn. "Tuvalet Kağıdı").
  /// `Ingredient` sınıfını burada da kullanıyoruz çünkü onun zaten kendi
  /// `isChecked` alanı var — manuel ürünler tariflerden gelmediği için
  /// (her açılışta yeniden hesaplanmadıkları için) işaretli durumlarını
  /// doğrudan kendi üzerlerinde saklayabiliyorlar.
  @HiveField(4)
  List<Ingredient> manualItems;

  /// Boş bir hafta oluşturur: her gün için Kahvaltı, Öğle, Akşam slotlarını
  /// tarifsiz (`recipe: null`) olarak hazırlar.
  ///
  /// `static` olması, bu metodun belirli bir `WeeklyPlan` NESNESİNE değil,
  /// doğrudan `WeeklyPlan` SINIFINA ait olduğu anlamına gelir; bu yüzden
  /// nesne oluşturulmadan (constructor'ın initializer list'inde) çağrılabilir.
  static List<PlannedMeal> _emptyWeek() {
    final List<PlannedMeal> result = [];
    for (final day in DayOfWeek.values) {
      for (final mealType in MealType.values) {
        result.add(PlannedMeal(day: day, mealType: mealType));
      }
    }
    return result;
  }

  /// Bu hafta plana eklenmiş tarif başlıkları (tekrar önlemede kullanılır).
  List<String> get plannedRecipeTitles {
    return meals
        .where((m) => m.recipe != null)
        .map((m) => m.recipe!.title.trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  /// Eski planlarda (21 slot) atıştırmalık yoksa ekler.
  void ensureMealSlots() {
    var changed = false;
    final next = List<PlannedMeal>.from(meals);
    for (final day in DayOfWeek.values) {
      for (final mealType in MealType.values) {
        final exists = next.any((m) => m.day == day && m.mealType == mealType);
        if (!exists) {
          next.add(PlannedMeal(day: day, mealType: mealType));
          changed = true;
        }
      }
    }
    if (!changed) return;
    meals = next;
    if (isInBox) {
      save();
    }
  }

  /// Belirli bir gün ve öğün için planlanan hücreyi bulur.
  PlannedMeal mealFor(DayOfWeek day, MealType mealType) {
    ensureMealSlots();
    for (final m in meals) {
      if (m.day == day && m.mealType == mealType) return m;
    }
    final created = PlannedMeal(day: day, mealType: mealType);
    meals = List<PlannedMeal>.from(meals)..add(created);
    if (isInBox) save();
    return created;
  }
}
