import '../models/ingredient.dart';
import '../models/weekly_plan.dart';
import 'ingredient_aggregator_service.dart';

/// Alışveriş listesindeki TEK BİR satırı ekrana çizmek için hazırlanmış
/// "görüntü modeli" (view model).
///
/// Ekranlar, ham `Ingredient` nesneleri yerine bu sınıfı kullanacak; çünkü
/// bir satırın "otomatik mi (tariften geldi) yoksa manuel mi (kullanıcı
/// elle ekledi) eklendiği" ve "işaretlendiğinde hangi anahtarla kalıcı
/// kaydedileceği" bilgisi de gerekiyor.
class ShoppingListEntry {
  ShoppingListEntry({
    required this.ingredient,
    required this.isManual,
    required this.mergeKey,
  });

  /// Satırın malzeme bilgisi (isim, miktar, birim, kategori, işaretli mi).
  final Ingredient ingredient;

  /// `true` ise bu satır kullanıcı tarafından elle eklenmiştir; `false` ise
  /// tariflerden otomatik toplanmıştır.
  final bool isManual;

  /// Bu satırı `WeeklyPlan.checkedAutoItemKeys` içinde bulmak/işaretlemek
  /// için kullanılan anahtar (sadece otomatik satırlar için anlamlıdır).
  final String mergeKey;
}

/// Adım 3'te yazdığımız `IngredientAggregatorService`'in (sadece tariflerden
/// OKUMA yapan, "salt okunur" servisin) üzerine, KALICI DURUM YÖNETİMİNİ
/// (işaretleme, manuel ürün ekleme/silme) ekleyen servis.
///
/// Bu iki servisi NEDEN ayırdık? `IngredientAggregatorService` tamamen "saf"
/// (pure) kalsın istedik: aynı girdi için hep aynı çıktıyı üretsin, hiçbir
/// şeyi diske kaydetmesin. `ShoppingListService` ise "kirli" (impure) işleri
/// üstlenir: veritabanına yazar (`plan.save()`), kullanıcı etkileşimine
/// (tıklama) tepki verir. Bu ayrım, hangi kodun test edilmesi kolay
/// (aggregator), hangisinin Hive'a bağımlı olduğunu (bu servis) net tutar.
class ShoppingListService {
  ShoppingListService._();

  /// Belirli bir haftalık plan için TAM alışveriş listesini oluşturur:
  /// tariflerden otomatik toplanan malzemeler + kullanıcının manuel
  /// eklediği ürünler, hepsi birlikte kategoriye göre gruplanmış olarak.
  static Map<IngredientCategory, List<ShoppingListEntry>> buildShoppingList(
    WeeklyPlan plan,
  ) {
    final autoIngredients = IngredientAggregatorService.aggregate(plan);

    final autoEntries = autoIngredients.map((ingredient) {
      final key = IngredientAggregatorService.mergeKeyFor(ingredient);
      // Otomatik toplanan malzeme her seferinde SIFIRDAN (isChecked: false)
      // oluşturulduğu için, kalıcı olarak kaydedilmiş işaretli durumunu
      // burada geri "giydiriyoruz".
      ingredient.isChecked = plan.checkedAutoItemKeys.contains(key);
      return ShoppingListEntry(ingredient: ingredient, isManual: false, mergeKey: key);
    });

    final manualEntries = plan.manualItems.map((ingredient) {
      return ShoppingListEntry(
        ingredient: ingredient,
        isManual: true,
        mergeKey: IngredientAggregatorService.mergeKeyFor(ingredient),
      );
    });

    final allEntries = [...autoEntries, ...manualEntries];

    final Map<IngredientCategory, List<ShoppingListEntry>> grouped = {
      for (final category in IngredientAggregatorService.marketVisitOrder) category: [],
    };
    for (final entry in allEntries) {
      grouped[entry.ingredient.category]!.add(entry);
    }
    for (final categoryEntries in grouped.values) {
      categoryEntries.sort((a, b) => a.ingredient.name.compareTo(b.ingredient.name));
    }
    grouped.removeWhere((_, categoryEntries) => categoryEntries.isEmpty);
    return grouped;
  }

  /// Bir satırın "evde var / alındı" işaretini AÇAR/KAPATIR ve değişikliği
  /// KALICI olarak kaydeder.
  ///
  /// Manuel ürünlerde bu bilgi doğrudan `Ingredient.isChecked` üzerinde
  /// tutulur. Otomatik (tariften gelen) ürünlerde ise malzemenin kendisi
  /// her seferinde yeniden üretildiği için, bilgiyi `WeeklyPlan` üzerindeki
  /// `checkedAutoItemKeys` listesinde saklarız.
  ///
  /// `plan.save()` çağrısı ÖNEMLİDİR: `Ingredient` nesnesi tek başına bir
  /// Hive kutusunda saklanmadığı (WeeklyPlan'ın İÇİNDE gömülü olduğu) için,
  /// değişikliğin diske yazılması ancak dış nesne olan `WeeklyPlan`
  /// kaydedildiğinde gerçekleşir.
  static void toggleChecked(WeeklyPlan plan, ShoppingListEntry entry) {
    if (entry.isManual) {
      entry.ingredient.isChecked = !entry.ingredient.isChecked;
    } else {
      final alreadyChecked = plan.checkedAutoItemKeys.contains(entry.mergeKey);
      if (alreadyChecked) {
        plan.checkedAutoItemKeys.remove(entry.mergeKey);
      } else {
        plan.checkedAutoItemKeys.add(entry.mergeKey);
      }
    }
    _saveIfInBox(plan);
  }

  /// Kullanıcının elle yazdığı, herhangi bir tarifte geçmeyen ekstra bir
  /// ürünü listeye ekler (örn. "Tuvalet Kağıdı", "Bulaşık Deterjanı").
  static void addManualItem({
    required WeeklyPlan plan,
    required String name,
    required double quantity,
    required String unit,
    required IngredientCategory category,
  }) {
    plan.manualItems.add(
      Ingredient(name: name, quantity: quantity, unit: unit, category: category),
    );
    _saveIfInBox(plan);
  }

  /// Kullanıcının daha önce manuel eklediği bir ürünü listeden tamamen
  /// kaldırır (örn. yanlışlıkla eklediği bir şeyi silmek istediğinde).
  static void removeManualItem(WeeklyPlan plan, Ingredient ingredient) {
    plan.manualItems.remove(ingredient);
    _saveIfInBox(plan);
  }

  /// `HiveObject.save()`, nesne HENÜZ bir Hive kutusuna eklenmemişse
  /// (`box.put(...)` çağrılmadıysa) hata fırlatır. Gerçek uygulamada
  /// `WeeklyPlan` her zaman `HiveService.weeklyPlanBox`'a eklenmiş
  /// olacağı için bu bir sorun yaratmaz; ancak testlerde (gerçek bir Hive
  /// kutusu açmadan) bu servisi çağırabilmek için burada güvenli bir
  /// kontrol ekliyoruz. `plan.isInBox`, `HiveObject`'in kendisinin
  /// sağladığı hazır bir kontrol.
  static void _saveIfInBox(WeeklyPlan plan) {
    if (plan.isInBox) {
      plan.save();
    }
  }
}
