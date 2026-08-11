import 'package:hive/hive.dart';

import 'ingredient.dart';
import 'nutrient.dart';

part 'recipe.g.dart';

/// Bir tarifin en pratik şekilde nasıl pişirileceğini belirtir.
/// Gemini AI, tarifi üretirken bu yöntemlerden birini önerecek (Kullanıcının
/// istediği "PİŞİRME YÖNTEMİ FİKRİ" özelliği).
@HiveType(typeId: 3)
enum CookingMethod {
  @HiveField(0)
  airFryer,

  @HiveField(1)
  oven,

  @HiveField(2)
  stovetop,

  @HiveField(3)
  grill,

  /// Pişirme gerektirmeyen tarifler için (örn: salata, smoothie).
  @HiveField(4)
  noCook,

  @HiveField(5)
  other;

  /// Ekranda gösterilecek Türkçe isim.
  String get displayName {
    switch (this) {
      case CookingMethod.airFryer:
        return 'Airfryer';
      case CookingMethod.oven:
        return 'Fırın';
      case CookingMethod.stovetop:
        return 'Ocak';
      case CookingMethod.grill:
        return 'Izgara';
      case CookingMethod.noCook:
        return 'Pişirme Gerektirmez';
      case CookingMethod.other:
        return 'Diğer';
    }
  }

  /// AI'dan gelen metni güvenli şekilde enum değerine çevirir.
  /// Tanımadığı bir kelime gelirse çökme yerine `other` döndürür.
  static CookingMethod fromString(String? raw) {
    switch (raw?.toLowerCase().trim()) {
      case 'airfryer':
      case 'air fryer':
        return CookingMethod.airFryer;
      case 'oven':
      case 'fırın':
      case 'firin':
        return CookingMethod.oven;
      case 'stovetop':
      case 'ocak':
        return CookingMethod.stovetop;
      case 'grill':
      case 'izgara':
        return CookingMethod.grill;
      case 'no_cook':
      case 'nocook':
      case 'pişirme gerektirmez':
        return CookingMethod.noCook;
      default:
        return CookingMethod.other;
    }
  }
}

/// Bir öğünün günün hangi vaktine ait olduğunu belirtir: Kahvaltı, Öğle,
/// Akşam. Bu değer hem `Recipe` içinde (bu tarif hangi öğün için üretildi)
/// hem de haftalık planda (bir sonraki adımda yazacağımız `WeeklyPlan`
/// modelinde) kullanılacak.
@HiveType(typeId: 4)
enum MealType {
  @HiveField(0)
  breakfast,

  @HiveField(1)
  lunch,

  @HiveField(2)
  dinner;

  String get displayName {
    switch (this) {
      case MealType.breakfast:
        return 'Kahvaltı';
      case MealType.lunch:
        return 'Öğle Yemeği';
      case MealType.dinner:
        return 'Akşam Yemeği';
    }
  }
}

/// Tek bir yemek tarifini temsil eden ANA model.
///
/// Bu sınıf, Gemini AI'dan gelen tüm tarif verisini (malzemeler, yapılış
/// adımları, besin değerleri, pişirme yöntemi) tek bir yapı altında toplar.
/// `HiveObject`'i extend ediyoruz çünkü her tarif, Hive veritabanında
/// bağımsız bir kayıt olarak saklanacak (örn. "Tarif Geçmişi" ekranında
/// eski tarifleri listelemek için).
@HiveType(typeId: 5)
class Recipe extends HiveObject {
  Recipe({
    required this.id,
    required this.title,
    required this.mealType,
    required this.ingredients,
    required this.steps,
    required this.nutrient,
    required this.cookingMethod,
    required this.servings,
    this.prepTimeMinutes = 0,
    this.cookTimeMinutes = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
  // `DateTime? createdAt` parametresini alıp `this.createdAt`'e atarken
  // eğer değer verilmediyse (null ise) şu anki zamanı kullanıyoruz
  // (`?? DateTime.now()`). Bu yapıya "initializer list" denir; constructor
  // gövdesinden (süslü parantez `{}` içinden) ÖNCE çalışır.

  /// Tarifin benzersiz kimliği (unique ID). İleride `uuid` paketiyle
  /// üreteceğiz. Bu ID sayesinde bir tarifi listede, veritabanında ve
  /// haftalık planda karışıklık olmadan buluruz.
  @HiveField(0)
  final String id;

  /// Tarifin adı. Örn: "Fırında Sebzeli Tavuk But".
  @HiveField(1)
  String title;

  /// Bu tarifin hangi öğün için üretildiği (Kahvaltı/Öğle/Akşam).
  @HiveField(2)
  MealType mealType;

  /// Tarifte kullanılan malzemelerin listesi.
  @HiveField(3)
  List<Ingredient> ingredients;

  /// Yapılışın adım adım anlatımı. Her eleman, listedeki bir adımı temsil
  /// eder. Örn: `["Fırını 200 derecede ısıtın.", "Tavuğu baharatlayın."]`
  @HiveField(4)
  List<String> steps;

  /// Tarifin besin değerleri (kalori, protein, karbonhidrat, yağ).
  @HiveField(5)
  Nutrient nutrient;

  /// Bu tarif için en pratik pişirme yöntemi (Airfryer, Fırın, Ocak vb.)
  @HiveField(6)
  CookingMethod cookingMethod;

  /// Kaç kişilik olduğu (porsiyon sayısı).
  @HiveField(7)
  int servings;

  /// Hazırlık süresi (dakika). Örn: doğrama, marine etme.
  @HiveField(8)
  int prepTimeMinutes;

  /// Pişirme süresi (dakika).
  @HiveField(9)
  int cookTimeMinutes;

  /// Bu tarifin ne zaman oluşturulduğu. İleride "son eklenen tarifler" gibi
  /// sıralamalarda kullanılabilir.
  @HiveField(10)
  DateTime createdAt;

  /// Gemini AI'dan dönen ham JSON cevabını `Recipe` nesnesine çevirir.
  /// Adım 2'de yazacağımız `GeminiService`, AI'dan cevap aldıktan sonra bu
  /// factory'yi çağıracak.
  ///
  /// `id` ve `mealType` parametrelerini JSON'ın DIŞINDA ayrıca veriyoruz
  /// çünkü bunlar AI'ın ürettiği içerik değil, uygulamanın kendisinin
  /// belirlediği (hangi slota tıklandığı, hangi ID atandığı) bilgiler.
  factory Recipe.fromJson(
    Map<String, dynamic> json, {
    required String id,
    required MealType mealType,
  }) {
    return Recipe(
      id: id,
      title: json['title'] as String? ?? 'İsimsiz Tarif',
      mealType: mealType,
      ingredients: (json['ingredients'] as List<dynamic>? ?? [])
          .map((e) => Ingredient.fromJson(e as Map<String, dynamic>))
          .toList(),
      steps: (json['steps'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      nutrient: Nutrient.fromJson(
        json['nutrient'] as Map<String, dynamic>? ?? {},
      ),
      cookingMethod: CookingMethod.fromString(
        json['cookingMethod'] as String?,
      ),
      servings: (json['servings'] as num? ?? 1).toInt(),
      prepTimeMinutes: (json['prepTimeMinutes'] as num? ?? 0).toInt(),
      cookTimeMinutes: (json['cookTimeMinutes'] as num? ?? 0).toInt(),
    );
  }

  /// Bu nesneyi JSON (Map) formatına çevirir.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'mealType': mealType.name,
      'ingredients': ingredients.map((e) => e.toJson()).toList(),
      'steps': steps,
      'nutrient': nutrient.toJson(),
      'cookingMethod': cookingMethod.name,
      'servings': servings,
      'prepTimeMinutes': prepTimeMinutes,
      'cookTimeMinutes': cookTimeMinutes,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
