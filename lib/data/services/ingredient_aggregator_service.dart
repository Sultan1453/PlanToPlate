import '../../core/utils/turkish_text_utils.dart';
import '../models/ingredient.dart';
import '../models/weekly_plan.dart';

/// "Otomatik Malzeme Birleştirici" — haftanın 21 öğününe (7 gün × 3 öğün)
/// dağılmış tariflerin malzemelerini tarayıp, AYNI malzemeleri tek satırda
/// toplayan servis.
///
/// Örn: Pazartesi akşam yemeği "2 Adet Soğan" istiyor, Perşembe öğle yemeği
/// de "3 Adet Soğan" istiyorsa, alışveriş listesinde bunlar TEK bir satırda
/// "5 Adet Soğan" olarak görünür.
///
/// Bu sınıf tamamen "saf" (pure) fonksiyonlardan oluşur: hiçbir veriyi
/// KENDİSİ saklamaz, sadece kendisine verilen `WeeklyPlan`'ı okuyup yeni bir
/// sonuç listesi üretir. Bu, test etmeyi çok kolaylaştırır (bkz.
/// `test/ingredient_aggregator_service_test.dart`) ve ekranların bu servisi
/// istedikleri an, yan etkisiz şekilde çağırabilmesini sağlar.
class IngredientAggregatorService {
  IngredientAggregatorService._(); // Nesne oluşturulması gereksiz; tüm metodlar static.

  /// Marketin GERÇEK reyon sırasına yakın bir gezinme sırası. Alışveriş
  /// listesi ekranında kategoriler bu sırayla gösterilecek: önce manav,
  /// sonra kasap, süt ürünleri, fırın, en son da raf ömrü uzun market
  /// ürünleri (kuru gıda) — bu sıralama, kullanıcı marketten gezerken en
  /// çabuk bozulacak ürünleri en başta toplasın diye düşünülmüştür.
  static const List<IngredientCategory> marketVisitOrder = [
    IngredientCategory.produce,
    IngredientCategory.butcher,
    IngredientCategory.dairy,
    IngredientCategory.bakery,
    IngredientCategory.pantry,
    IngredientCategory.other,
  ];

  /// Bir haftalık plandaki TÜM tariflerin malzemelerini toplar ve
  /// birleştirir.
  ///
  /// Nasıl çalışır:
  /// 1) Plandaki 21 öğün hücresi (`PlannedMeal`) tek tek gezilir.
  /// 2) Bir hücrede tarif YOKSA (`recipe == null`, kullanıcı henüz o öğüne
  ///    yemek seçmediyse) o hücre atlanır.
  /// 3) Tarifi olan her hücrenin malzemeleri, "isim + birim" ikilisine göre
  ///    bir haritada (Map) toplanır; aynı anahtar ikinci kez görülürse
  ///    miktarlar TOPLANIR, görülmezse yeni bir satır olarak eklenir.
  ///
  /// NEDEN "isim + birim" birlikte anahtar? Çünkü "2 Adet Soğan" ile
  /// "500 Gram Soğan" farklı birimlerdedir; ikisini basitçe toplarsak
  /// anlamsız bir sayı çıkar (adet + gram olmaz). Bu yüzden farklı
  /// birimdeki aynı malzeme, listede AYRI iki satır olarak kalır — bu,
  /// hatalı toplamadan çok daha güvenli bir davranıştır.
  static List<Ingredient> aggregate(WeeklyPlan plan) {
    final Map<String, Ingredient> mergedByKey = {};

    for (final plannedMeal in plan.meals) {
      final recipe = plannedMeal.recipe;
      if (recipe == null) continue;

      for (final ingredient in recipe.ingredients) {
        final key = mergeKeyFor(ingredient);
        final alreadyCollected = mergedByKey[key];

        if (alreadyCollected == null) {
          // Bu malzemeyi ilk kez görüyoruz: listeye yeni, BAĞIMSIZ bir kopya
          // olarak ekliyoruz (orijinal tarif nesnesini asla değiştirmiyoruz;
          // aksi halde tarifin kendi malzeme miktarı da yanlışlıkla
          // değişirdi).
          mergedByKey[key] = Ingredient(
            name: ingredient.name,
            quantity: ingredient.quantity,
            unit: ingredient.unit,
            category: ingredient.category,
          );
        } else {
          // Bu malzemeyi (aynı isim + aynı birim ile) daha önce de
          // görmüştük: miktarını üzerine ekliyoruz.
          alreadyCollected.quantity += ingredient.quantity;
        }
      }
    }

    return mergedByKey.values.toList();
  }

  /// Birleştirilmiş malzeme listesini, market kategorilerine göre
  /// gruplayıp `marketVisitOrder`'daki sırayla döner. Her kategori
  /// içindeki malzemeler alfabetik sıraya dizilir (kullanıcı listede
  /// belirli bir ürünü ararken kolayca bulabilsin diye).
  ///
  /// Hiç malzemesi olmayan kategoriler (örn. bu hafta hiç "Fırın" ürünü
  /// yoksa) sonuçtan tamamen çıkarılır; ekranda boş başlıklar görünmesin.
  static Map<IngredientCategory, List<Ingredient>> groupByCategory(
    List<Ingredient> ingredients,
  ) {
    final Map<IngredientCategory, List<Ingredient>> grouped = {
      for (final category in marketVisitOrder) category: <Ingredient>[],
    };

    for (final ingredient in ingredients) {
      grouped[ingredient.category]!.add(ingredient);
    }

    for (final categoryIngredients in grouped.values) {
      categoryIngredients.sort(
        (a, b) => normalizeTurkish(a.name).compareTo(normalizeTurkish(b.name)),
      );
    }

    grouped.removeWhere((_, categoryIngredients) => categoryIngredients.isEmpty);
    return grouped;
  }

  /// Bir haftalık planı doğrudan kategorilere göre gruplanmış, birleştirilmiş
  /// hale getiren kısayol. Ekranlar genellikle sadece bu tek metodu
  /// çağıracak (`aggregate` + `groupByCategory`'yi arka arkaya çalıştırır).
  static Map<IngredientCategory, List<Ingredient>> buildShoppingList(
    WeeklyPlan plan,
  ) {
    return groupByCategory(aggregate(plan));
  }

  /// İki malzemenin "aynı satırda toplanabilir" sayılması için kullanılan
  /// anahtarı üretir: Türkçe karakterlerden/büyük-küçük harften bağımsız
  /// isim + birim ikilisi. `normalizeTurkish` fonksiyonunu Adım 2'de zaten
  /// yazmıştık (bkz. `core/utils/turkish_text_utils.dart`); burada TEKRAR
  /// KULLANIYORUZ çünkü aynı sorun (AI'ın "Soğan" yerine bazen "soğan"
  /// döndürmesi ihtimali) burada da geçerli.
  ///
  /// `public` (alt çizgisiz) yaptık çünkü Adım 4'te yazacağımız
  /// `ShoppingListService`, bir malzemenin "işaretli mi?" bilgisini
  /// `WeeklyPlan.checkedAutoItemKeys` listesinde ARAMAK için AYNI anahtar
  /// üretim mantığına ihtiyaç duyacak; mantığı iki yerde ayrı ayrı yazmak
  /// yerine buradan tekrar kullanıyoruz.
  static String mergeKeyFor(Ingredient ingredient) {
    final normalizedName = normalizeTurkish(ingredient.name);
    final normalizedUnit = normalizeTurkish(ingredient.unit);
    return '$normalizedName|$normalizedUnit';
  }
}
