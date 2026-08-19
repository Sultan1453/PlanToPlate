import 'package:hive/hive.dart';

part 'ingredient.g.dart';

/// Bir malzemenin hangi mağaza/reyon kategorisine ait olduğunu belirtir.
///
/// Bu enum (sabit değer listesi), "Otomatik Malzeme Birleştirici"
/// özelliğinde malzemeleri Manav, Kasap, Market gibi gruplara otomatik
/// ayırmak için kullanılacak. Alışveriş listesi ekranında malzemeler bu
/// kategoriye göre başlıklar altında gruplanacak.
///
/// `typeId: 1` kullanıyoruz çünkü 0 numarasını Nutrient sınıfı için
/// kullanmıştık; her modelin (ve enum'un) kendine özel, tekrarsız bir
/// numarası olmalı.
@HiveType(typeId: 1)
enum IngredientCategory {
  /// Sebze, meyve gibi manav ürünleri.
  @HiveField(0)
  produce,

  /// Et, tavuk, balık gibi kasap ürünleri.
  @HiveField(1)
  butcher,

  /// Süt, yoğurt, peynir gibi süt ürünleri.
  @HiveField(2)
  dairy,

  /// Bakliyat, konserve, baharat, un, şeker gibi raf (market) ürünleri.
  @HiveField(3)
  pantry,

  /// Ekmek ve unlu mamuller.
  @HiveField(4)
  bakery,

  /// Yukarıdaki kategorilerin hiçbirine uymayan diğer her şey.
  @HiveField(5)
  other;

  /// Bu enum değerine karşılık gelen, kullanıcıya EKRANDA gösterilecek
  /// Türkçe metni döndürür. Kod içinde "IngredientCategory.produce" yazmak
  /// yerine, arayüzde bu getter sayesinde "Manav" gibi okunabilir bir
  /// kelime göstereceğiz.
  String get displayName {
    switch (this) {
      case IngredientCategory.produce:
        return 'Manav';
      case IngredientCategory.butcher:
        return 'Kasap';
      case IngredientCategory.dairy:
        return 'Süt Ürünleri';
      case IngredientCategory.pantry:
        return 'Market / Kuru Gıda';
      case IngredientCategory.bakery:
        return 'Fırın';
      case IngredientCategory.other:
        return 'Diğer';
    }
  }

  /// Market yürüyüş sırasındaki adım başlığı (1 · Manav).
  String get routeTitle {
    const order = [
      IngredientCategory.produce,
      IngredientCategory.butcher,
      IngredientCategory.dairy,
      IngredientCategory.pantry,
      IngredientCategory.bakery,
      IngredientCategory.other,
    ];
    final step = order.indexOf(this) + 1;
    return '$step · $displayName';
  }
}

/// Bir yemek tarifindeki TEK BİR malzemeyi temsil eder.
/// Örn: isim: "Soğan", miktar: 2, birim: "adet", kategori: Manav.
///
/// `HiveObject`'i extend ediyoruz (miras alıyoruz) çünkü Ingredient
/// nesneleri bazen (alışveriş listesi ekranında) tek başlarına da
/// saklanıp güncellenecek. `HiveObject` bize hazır `.save()` (değişikliği
/// veritabanına kaydet) ve `.delete()` (veritabanından sil) metodlarını
/// otomatik olarak kazandırır.
@HiveType(typeId: 2)
class Ingredient extends HiveObject {
  Ingredient({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.category,
    this.isChecked = false,
  });

  /// Malzemenin adı. Örn: "Soğan", "Tavuk But", "Zeytinyağı".
  ///
  /// `final` DEĞİL, çünkü kullanıcı ismi düzenlemek isteyebilir (örn. yazım
  /// hatasını düzeltmek için). `final` olan alanlar oluşturulduktan sonra
  /// asla değiştirilemez; burada değiştirilebilir olmasını istiyoruz.
  @HiveField(0)
  String name;

  /// Malzemenin miktarı. `double` kullanıyoruz çünkü "1.5 su bardağı" gibi
  /// ondalıklı miktarlar da olabilir.
  @HiveField(1)
  double quantity;

  /// Miktarın birimi. Örn: "adet", "gram", "yemek kaşığı", "su bardağı".
  @HiveField(2)
  String unit;

  /// Bu malzemenin ait olduğu mağaza kategorisi (Manav, Kasap, vb.)
  @HiveField(3)
  IngredientCategory category;

  /// Kullanıcı bu malzemeyi zaten evde varsa veya alışveriş listesinden
  /// satın aldıysa bu değeri `true` yapar; arayüzde üzeri çizili olarak
  /// gösterilir. Varsayılan olarak `false` (yani "henüz alınmadı") kabul
  /// ederiz.
  @HiveField(4)
  bool isChecked;

  /// Gemini AI'dan gelen TEK BİR malzeme JSON'ını Ingredient nesnesine
  /// çevirir. Örn. AI'ın gönderdiği ham veri:
  /// `{"name": "Soğan", "quantity": 2, "unit": "adet", "category": "manav"}`
  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      name: json['name'] as String? ?? '',
      quantity: (json['quantity'] as num? ?? 1).toDouble(),
      unit: json['unit'] as String? ?? 'adet',
      category: _categoryFromString(json['category'] as String?),
      isChecked: false,
    );
  }

  /// AI'dan gelen kategori metnini (örn: "manav", "produce") güvenli bir
  /// şekilde `IngredientCategory` enum değerine çevirir.
  ///
  /// AI her zaman beklediğimiz kelimeyi göndermeyebilir (örn. "sebzeler"
  /// yazabilir). Böyle bilinmeyen bir durumda uygulamanın ÇÖKMEMESİ için,
  /// eşleşme bulunamazsa varsayılan olarak `other` (Diğer) döndürüyoruz.
  static IngredientCategory _categoryFromString(String? raw) {
    switch (raw?.toLowerCase().trim()) {
      case 'produce':
      case 'manav':
        return IngredientCategory.produce;
      case 'butcher':
      case 'kasap':
        return IngredientCategory.butcher;
      case 'dairy':
      case 'süt ürünleri':
      case 'sut urunleri':
        return IngredientCategory.dairy;
      case 'pantry':
      case 'market':
        return IngredientCategory.pantry;
      case 'bakery':
      case 'fırın':
      case 'firin':
        return IngredientCategory.bakery;
      default:
        return IngredientCategory.other;
    }
  }

  /// Bu nesneyi JSON (Map) formatına çevirir.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'category': category.name,
      'isChecked': isChecked,
    };
  }
}
