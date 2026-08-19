import '../models/ingredient.dart';
import '../models/weekly_plan.dart';
import '../../core/utils/turkish_text_utils.dart';
import 'ingredient_aggregator_service.dart';
import 'purchase_unit_normalizer.dart';

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
  ///
  /// Not: UI artık sekmeleri ayırdığı için [buildAutoShoppingList] /
  /// [buildManualShoppingList] kullanır; bu metod testler ve geriye
  /// uyumluluk için durur.
  ///
  /// [ownedAtHome]: Evdekiler listesindeki malzemeler; otomatik listeden
  /// çıkarılır (kullanıcı zaten evde olduğunu bildirmiştir).
  static Map<IngredientCategory, List<ShoppingListEntry>> buildShoppingList(
    WeeklyPlan plan, {
    Iterable<String> ownedAtHome = const [],
  }) {
    final autoGrouped = buildAutoShoppingList(plan, ownedAtHome: ownedAtHome);
    final manualEntries = buildManualShoppingList(plan);

    final Map<IngredientCategory, List<ShoppingListEntry>> grouped = {
      for (final category in IngredientAggregatorService.marketVisitOrder) category: [
        ...?autoGrouped[category],
      ],
    };
    for (final entry in manualEntries) {
      grouped[entry.ingredient.category]!.add(entry);
    }
    for (final categoryEntries in grouped.values) {
      categoryEntries.sort(
        (a, b) => normalizeTurkish(a.ingredient.name)
            .compareTo(normalizeTurkish(b.ingredient.name)),
      );
    }
    grouped.removeWhere((_, categoryEntries) => categoryEntries.isEmpty);
    return grouped;
  }

  /// Sadece haftalık plandaki tariflerden gelen malzemeler (reyonlara göre).
  /// Tarif ölçüleri (kaşık, tutam...) markette alınabilir birime çevrilir.
  ///
  /// [ownedAtHome] içindeki ürünler listede gösterilmez.
  static Map<IngredientCategory, List<ShoppingListEntry>> buildAutoShoppingList(
    WeeklyPlan plan, {
    Iterable<String> ownedAtHome = const [],
  }) {
    final ownedKeys = ownedAtHome
        .map((e) => normalizeTurkish(e.trim()))
        .where((e) => e.isNotEmpty)
        .toSet();

    final autoIngredients = PurchaseUnitNormalizer.normalizeList(
      IngredientAggregatorService.aggregate(plan),
    );

    final autoEntries = autoIngredients
        .where((ingredient) => !_isOwnedAtHome(ingredient.name, ownedKeys))
        .map((ingredient) {
      final key = IngredientAggregatorService.mergeKeyFor(ingredient);
      ingredient.isChecked = plan.checkedAutoItemKeys.contains(key);
      return ShoppingListEntry(ingredient: ingredient, isManual: false, mergeKey: key);
    }).toList();

    final Map<IngredientCategory, List<ShoppingListEntry>> grouped = {
      for (final category in IngredientAggregatorService.marketVisitOrder) category: [],
    };
    for (final entry in autoEntries) {
      grouped[entry.ingredient.category]!.add(entry);
    }
    for (final categoryEntries in grouped.values) {
      categoryEntries.sort(
        (a, b) => normalizeTurkish(a.ingredient.name)
            .compareTo(normalizeTurkish(b.ingredient.name)),
      );
    }
    grouped.removeWhere((_, categoryEntries) => categoryEntries.isEmpty);
    return grouped;
  }

  /// Evdekiler kaydı ile tarif malzemesi eşleşiyor mu?
  /// Kısa token'larda (su, un…) yalnızca tam eşleşme; aksi halde yanlış gizleme olur.
  static bool _isOwnedAtHome(String ingredientName, Set<String> ownedKeys) {
    if (ownedKeys.isEmpty) return false;
    final name = normalizeTurkish(ingredientName);
    if (name.isEmpty) return false;
    for (final owned in ownedKeys) {
      if (owned.isEmpty) continue;
      if (name == owned) return true;
      // Çok kısa isimler (su, un, et…) yalnızca exact match.
      if (owned.length < 4 || name.length < 4) continue;
      final nameTokens = name.split(RegExp(r'\s+'));
      final ownedTokens = owned.split(RegExp(r'\s+'));
      if (nameTokens.contains(owned) || ownedTokens.contains(name)) {
        return true;
      }
    }
    return false;
  }

  /// Kullanıcının elle eklediği ev ihtiyaçları (yemek planından bağımsız).
  static List<ShoppingListEntry> buildManualShoppingList(WeeklyPlan plan) {
    final entries = plan.manualItems.map((ingredient) {
      return ShoppingListEntry(
        ingredient: ingredient,
        isManual: true,
        mergeKey: IngredientAggregatorService.mergeKeyFor(ingredient),
      );
    }).toList();

    entries.sort(
      (a, b) => normalizeTurkish(a.ingredient.name)
          .compareTo(normalizeTurkish(b.ingredient.name)),
    );
    return entries;
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

  /// Tarif kaldırıldığında artık listede olmayan otomatik satırların
  /// "alındı" işaretlerini temizler; aksi halde aynı malzeme tekrar
  /// eklenince yanlışlıkla işaretli görünebilir.
  static void pruneStaleCheckedKeys(WeeklyPlan plan) {
    final validKeys = PurchaseUnitNormalizer.normalizeList(
      IngredientAggregatorService.aggregate(plan),
    ).map(IngredientAggregatorService.mergeKeyFor).toSet();
    plan.checkedAutoItemKeys.removeWhere((key) => !validKeys.contains(key));
  }

  /// İşaretlenmemiş (alınacak) otomatik + manuel ürün sayısı.
  /// [ownedAtHome] verilirse alışveriş ekranıyla aynı filtre uygulanır.
  static int countUncheckedItems(
    WeeklyPlan plan, {
    Iterable<String> ownedAtHome = const [],
  }) {
    final auto = buildAutoShoppingList(plan, ownedAtHome: ownedAtHome);
    final manual = buildManualShoppingList(plan);
    var count = 0;
    for (final list in auto.values) {
      for (final e in list) {
        if (!e.ingredient.isChecked) count++;
      }
    }
    for (final e in manual) {
      if (!e.ingredient.isChecked) count++;
    }
    return count;
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
