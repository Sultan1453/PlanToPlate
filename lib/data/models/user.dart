import 'package:hive/hive.dart';

import '../../core/utils/date_utils.dart';
import 'weekly_plan.dart';

part 'user.g.dart';

/// Kullanıcının abonelik durumunu belirtir: Ücretsiz, Aylık Premium veya
/// Yıllık Premium.
///
/// RevenueCat (Adım 4'te ekleyeceğimiz `purchases_flutter` paketi), Google
/// Play üzerinden gerçek satın alma/aboneliği YÖNETEN asıl kaynaktır (source
/// of truth). Bu alan ise sadece uygulamanın İNTERNET OLMADAN da (örn. uçak
/// modunda) "bu kullanıcı premium mu?" sorusuna hızlıca cevap verebilmesi
/// için cihazda tutulan YEREL bir kopyadır (cache).
///
/// `typeId: 9` kullanıyoruz çünkü 0-8 numaraları önceki modellerde
/// (Nutrient, Ingredient, Recipe, WeeklyPlan dosyalarında) kullanıldı.
@HiveType(typeId: 9)
enum SubscriptionPlan {
  /// Ücretsiz kullanıcı: haftalık 3 AI tarifi + 1 fotoğraf yükleme hakkı ve
  /// reklamlarla sınırlıdır.
  @HiveField(0)
  free,

  /// Aylık Premium abone: reklamsız ve sınırsız AI hakkı.
  @HiveField(1)
  monthly,

  /// Yıllık Premium abone (yüzde 50 indirimli plan): reklamsız ve sınırsız
  /// AI hakkı.
  @HiveField(2)
  yearly;

  /// Bu plan "premium" sayılır mı? Sadece `free` DEĞİLSE premium kabul
  /// ederiz. Paywall ekranında ve reklam gösterim kararında bu getter'ı
  /// kullanacağız.
  bool get isPaidPlan => this != SubscriptionPlan.free;
}

/// Uygulamadaki TEK kullanıcıyı temsil eden model.
///
/// NOT: Bu uygulamada sunucu tarafı bir hesap sistemi (email/şifre girişi)
/// YOK; her kullanıcı kendi telefonunda tek bir `User` kaydına sahip olur
/// (Hive'da hep aynı sabit ID ile saklanır, örn. "local_user"). Bu kayıt;
/// abonelik durumunu, haftalık AI/foto kullanım sayaçlarını ve alışveriş
/// bildirim tercihini tutar. Yani bu sınıf aslında bir "hesap" değil, daha
/// çok kullanıcının cihazdaki KİŞİSEL AYAR VE HAK DURUMU (entitlement)
/// kaydıdır.
///
/// `HiveObject`'i extend ediyoruz çünkü bu nesneyi Hive kutusunda (box)
/// saklayıp `.save()` ile güncelleyeceğiz (örn. her AI tarifi üretiminde
/// sayaç bir artacak ve hemen diske kaydedilecek).
@HiveType(typeId: 10)
class User extends HiveObject {
  User({
    required this.id,
    this.subscriptionPlan = SubscriptionPlan.free,
    this.premiumExpiryDate,
    this.weeklyRecipeGenerationCount = 0,
    this.weeklyPhotoUploadCount = 0,
    this.bonusRecipeCredits = 0,
    DateTime? currentWeekStartDate,
    this.shoppingReminderEnabled = false,
    this.shoppingReminderDay,
    this.shoppingReminderHour,
    this.shoppingReminderMinute,
  }) : currentWeekStartDate = currentWeekStartDate ?? startOfWeek(DateTime.now());

  /// Kullanıcının kimliği. Sunucu hesabı olmadığı için bunu sabit bir
  /// metin (örn. "local_user") olarak kullanacağız; tek amacı Hive
  /// kutusunda bu kaydı bulmaktır.
  @HiveField(0)
  final String id;

  /// Şu anki abonelik planı (free / monthly / yearly).
  @HiveField(1)
  SubscriptionPlan subscriptionPlan;

  /// Premium aboneliğin ne zaman sona ereceği (RevenueCat'ten gelen bilgiyle
  /// güncellenir). `free` kullanıcılarda bu değer `null` olur.
  @HiveField(2)
  DateTime? premiumExpiryDate;

  /// Bu hafta şu ana kadar üretilen AI tarifi sayısı. Ücretsiz kullanıcı
  /// için üst sınır 3'tür (Kural 1).
  @HiveField(3)
  int weeklyRecipeGenerationCount;

  /// Bu hafta şu ana kadar yüklenen fotoğraf sayısı. Ücretsiz kullanıcı
  /// için üst sınır 1'dir (Kural 1).
  @HiveField(4)
  int weeklyPhotoUploadCount;

  /// Ödüllü reklam (Rewarded Ad) izleyerek kazanılan, haftalık limitin
  /// ÜZERİNE eklenen ekstra AI tarifi hakkı. Bu sayaç haftalık sıfırlama
  /// mantığından ETKİLENMEZ; kullanıcı hakkını kullanana kadar elinde
  /// kalır (Kural 2-B: "Reklam İzle, +1 AI Tarifi Kazan").
  @HiveField(5)
  int bonusRecipeCredits;

  /// Haftalık sayaçların (weeklyRecipeGenerationCount,
  /// weeklyPhotoUploadCount) hangi haftaya ait olduğunu tutar. Uygulama her
  /// açıldığında bu tarih güncel haftanın başlangıcıyla karşılaştırılır;
  /// eğer yeni bir haftaya geçilmişse sayaçlar otomatik sıfırlanır
  /// (`resetWeeklyUsageIfNeeded` metoduna bakınız).
  @HiveField(6)
  DateTime currentWeekStartDate;

  /// Alışveriş listesi hatırlatma bildirimi açık mı?
  @HiveField(7)
  bool shoppingReminderEnabled;

  /// Alışveriş hatırlatmasının hangi güne kurulduğu (örn. Cumartesi).
  /// `DayOfWeek` enum'ı `weekly_plan.dart` dosyasında zaten tanımlı; burada
  /// onu tekrar tanımlamak yerine import ederek YENİDEN KULLANIYORUZ (aynı
  /// kavramı iki farklı yerde iki farklı isimle tutmak, ileride veriler
  /// arasında tutarsızlığa yol açar).
  @HiveField(8)
  DayOfWeek? shoppingReminderDay;

  /// Hatırlatma saatinin "saat" kısmı (0-23). Hive, Flutter'ın `TimeOfDay`
  /// sınıfını doğrudan saklayamadığı için saat ve dakikayı iki ayrı `int`
  /// alanına bölerek saklıyoruz.
  @HiveField(9)
  int? shoppingReminderHour;

  /// Hatırlatma saatinin "dakika" kısmı (0-59).
  @HiveField(10)
  int? shoppingReminderMinute;

  /// Kullanıcı şu anda premium mu? Hem seçili planın ücretli olmasını HEM DE
  /// (eğer bir bitiş tarihi kayıtlıysa) bu tarihin henüz geçmemiş olmasını
  /// kontrol eder. `premiumExpiryDate` null ise (örn. RevenueCat'ten henüz
  /// senkronize edilmediyse) sadece plan bilgisine güveniriz.
  bool get isPremium {
    if (!subscriptionPlan.isPaidPlan) return false;
    if (premiumExpiryDate == null) return true;
    return premiumExpiryDate!.isAfter(DateTime.now());
  }

  /// Eğer takvim yeni bir haftaya geçtiyse (bugünün haftası,
  /// `currentWeekStartDate`'te kayıtlı haftadan farklıysa) haftalık
  /// sayaçları sıfırlar. Bu metodu uygulama her açıldığında (main.dart'ta)
  /// ve her AI tarifi/fotoğraf işleminden ÖNCE çağıracağız ki kullanıcı
  /// haftalar sonra uygulamayı açsa bile hakları doğru şekilde tazelensin.
  ///
  /// NOT: `bonusRecipeCredits` (reklam izleyerek kazanılan haklar) BİLEREK
  /// burada sıfırlanmıyor; onlar kullanıcı hakkını kullanana kadar kalıcıdır.
  void resetWeeklyUsageIfNeeded() {
    final thisWeekStart = startOfWeek(DateTime.now());
    if (thisWeekStart.isAfter(currentWeekStartDate)) {
      weeklyRecipeGenerationCount = 0;
      weeklyPhotoUploadCount = 0;
      currentWeekStartDate = thisWeekStart;
    }
  }

  /// Kullanıcı şu an yeni bir AI tarifi üretebilir mi? (Kural 1 + Kural 2-B)
  /// Premium kullanıcılar için her zaman `true`. Ücretsiz kullanıcılar için:
  /// haftalık hakkı (3) bitmediyse VEYA elinde reklam karşılığı kazanılmış
  /// bonus hakkı varsa `true` döner.
  bool get canGenerateRecipe {
    if (isPremium) return true;
    return weeklyRecipeGenerationCount < 3 || bonusRecipeCredits > 0;
  }

  /// Kullanıcı şu an fotoğraf yükleyebilir mi? (Kural 1) Premium
  /// kullanıcılar sınırsızdır; ücretsiz kullanıcılar haftada en fazla 1
  /// fotoğraf yükleyebilir.
  bool get canUploadPhoto {
    if (isPremium) return true;
    return weeklyPhotoUploadCount < 1;
  }

  /// Bir AI tarifi üretimi GERÇEKLEŞTİKTEN sonra çağrılır; ilgili sayacı
  /// günceller. Premium kullanıcılarda sayaç hiç artırılmaz (zaten sınırsız
  /// oldukları için gereksiz). Ücretsiz kullanıcıda önce BONUS hak varsa o
  /// harcanır (kullanıcı reklam izleyerek kazandığı hakkı önce tüketsin,
  /// haftalık hakkı en son kullanılsın); bonus hak yoksa haftalık sayaç bir
  /// artar.
  void recordRecipeGeneration() {
    if (isPremium) return;
    if (bonusRecipeCredits > 0) {
      bonusRecipeCredits -= 1;
    } else {
      weeklyRecipeGenerationCount += 1;
    }
  }

  /// [recordRecipeGeneration]'ın "geri alma" (undo) karşılığı.
  ///
  /// AI tarif üretimi bir HATA ile başarısız olduğunda veya kullanıcı
  /// yemek adı girmekten vazgeçtiğinde çağrılır: kullanıcı elinde bir
  /// tarif OLMADAN hakkını kaybetmiş olmasın diye, harcanan hak GERİ
  /// verilir.
  ///
  /// `usedBonus`: [recordRecipeGeneration] çağrıldığında hangi kaynaktan
  /// harcandığını (bonus kredi mi, haftalık hak mı) belirtir; bu bilgiyi
  /// çağıran taraf (`UserNotifier.tryConsumeRecipeGeneration`) saklar,
  /// çünkü hangisinin harcandığı, harcama anındaki `bonusRecipeCredits`
  /// değerine bağlıdır.
  void undoRecipeGeneration({required bool usedBonus}) {
    if (isPremium) return;
    if (usedBonus) {
      bonusRecipeCredits += 1;
    } else if (weeklyRecipeGenerationCount > 0) {
      weeklyRecipeGenerationCount -= 1;
    }
  }

  /// Bir fotoğraf yükleme GERÇEKLEŞTİKTEN sonra çağrılır; ücretsiz
  /// kullanıcıda sayaç bir artar. Premium kullanıcıda sayaç artırılmaz.
  void recordPhotoUpload() {
    if (isPremium) return;
    weeklyPhotoUploadCount += 1;
  }

  /// [recordPhotoUpload]'ın geri alma karşılığı. Fotoğraf seçimi iptal
  /// edildiğinde veya AI üretimi başarısız olduğunda çağrılır.
  void undoPhotoUpload() {
    if (isPremium) return;
    if (weeklyPhotoUploadCount > 0) {
      weeklyPhotoUploadCount -= 1;
    }
  }

  /// Kullanıcı ödüllü reklamı sonuna kadar izleyip ödülü kazandığında
  /// çağrılır (Kural 2-B). Bonus hak sayacını bir artırır.
  void grantRewardedAdCredit() {
    bonusRecipeCredits += 1;
  }
}
