import 'package:hive/hive.dart';

// build_runner çalıştırıldığında bu dosyanın yanına otomatik olarak
// "nutrient.g.dart" adında bir dosya üretilecek. O dosya, Nutrient
// nesnelerini Hive veritabanının anlayacağı ikili (binary) formata
// çevirme/geri çevirme kodunu içerir. Biz o kodu elle yazmıyoruz,
// build_runner bizim için üretiyor.
part 'nutrient.g.dart';

/// Bir yemeğin besin değerlerini (kalori, protein, karbonhidrat, yağ) tutan
/// model.
///
/// Bu sınıf, Google Gemini AI'dan gelen besin bilgilerini uygulama içinde
/// saklamak ve ekranda göstermek için kullanılır. `HiveObject`'ten
/// türetilmiyor çünkü tek başına bağımsız bir veritabanı kaydı değil; her
/// zaman bir `Recipe` (Tarif) nesnesinin İÇİNE "gömülü" (embedded) olarak
/// saklanacak.
///
/// `@HiveType(typeId: 0)`: Hive'a "bu sınıfı veritabanında saklayabilirsin,
/// ve onu diğer sınıflardan ayırt etmek için 0 numaralı kimliği kullan"
/// diyoruz. Uygulamadaki HER modelin typeId'si BİRBİRİNDEN FARKLI olmalı,
/// yoksa Hive hangi verinin hangi sınıfa ait olduğunu şaşırır.
@HiveType(typeId: 0)
class Nutrient {
  /// Kurucu metod (constructor): Bir Nutrient nesnesi oluştururken bu 4
  /// değerin hepsini vermek ZORUNLUDUR (required). Varsayılan değer
  /// koymuyoruz çünkü besin değerini "tahmin etmek" yanlış olur; bu veri
  /// her zaman AI'dan gerçek bir sayı olarak gelmeli.
  Nutrient({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  /// Kalori miktarı (kcal birimi). Örn: 450.0
  ///
  /// `@HiveField(0)`: Bu alanın, bu sınıf içindeki 0 numaralı "kutucuk"
  /// olduğunu belirtir. Hive, veriyi diskte bu numaralara göre saklar.
  /// ÖNEMLİ KURAL: Bir alanı sildikten sonra numaraları ASLA yeniden
  /// kullanma; yeni alan eklerken hep BİR SONRAKİ boş numarayı kullan.
  @HiveField(0)
  final double calories;

  /// Protein miktarı (gram birimi). Örn: 32.5
  @HiveField(1)
  final double protein;

  /// Karbonhidrat miktarı (gram birimi).
  @HiveField(2)
  final double carbs;

  /// Yağ miktarı (gram birimi).
  @HiveField(3)
  final double fat;

  /// Gemini AI'dan dönen JSON verisini (Dart'ta `Map<String, dynamic>`
  /// olarak temsil edilir) okuyup bir Nutrient nesnesine çeviren "fabrika"
  /// (factory) metodu. Adım 2'de yazacağımız Gemini servisinde bu metodu
  /// kullanacağız.
  ///
  /// `(json['calories'] as num? ?? 0).toDouble()` ifadesinin anlamı:
  /// 1) "calories" anahtarındaki değeri oku,
  /// 2) sayı (num) türünde olduğunu varsay (`as num?`, yoksa null kabul et),
  /// 3) eğer değer yoksa (null ise) varsayılan olarak 0 kullan (`?? 0`),
  /// 4) sonucu double'a çevir (`.toDouble()`), çünkü AI bazen tam sayı
  ///    (450) bazen ondalıklı sayı (450.5) döndürebilir; ikisini de aynı
  ///    tipe (double) sabitleyerek uygulamanın çökmesini engelliyoruz.
  factory Nutrient.fromJson(Map<String, dynamic> json) {
    return Nutrient(
      calories: (json['calories'] as num? ?? 0).toDouble(),
      protein: (json['protein'] as num? ?? 0).toDouble(),
      carbs: (json['carbs'] as num? ?? 0).toDouble(),
      fat: (json['fat'] as num? ?? 0).toDouble(),
    );
  }

  /// Bu nesneyi tekrar JSON (Map) formatına çevirir. İleride bu veriyi
  /// yedekleme, paylaşma veya farklı bir servise gönderme gibi işlemlerde
  /// kullanabiliriz.
  Map<String, dynamic> toJson() {
    return {
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
    };
  }
}
