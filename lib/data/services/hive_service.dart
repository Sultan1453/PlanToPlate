import 'package:hive_flutter/hive_flutter.dart';

import '../models/ingredient.dart';
import '../models/nutrient.dart';
import '../models/recipe.dart';
import '../models/user.dart';
import '../models/weekly_plan.dart';

/// Uygulamanın yerel veritabanı (Hive) ile ilgili TÜM kurulum işlerini tek
/// bir yerde topluyoruz.
///
/// NEDEN "Hive"? Kullanıcının verdiği görevde belirtildiği gibi, bu
/// uygulamada sunucu/internet bağlantısı gerektiren bir veritabanı YOK; her
/// şey (haftalık plan, kullanıcı hakları) doğrudan telefonun kendi
/// hafızasında, çok hızlı okunup yazılan bir dosya biçiminde saklanıyor.
/// Hive, Flutter dünyasında bunun için en hafif ve en hızlı çözümlerden
/// biridir; Play Store'da performans açısından sorun yaşatmaz.
///
/// Bu sınıftaki her şey `static` (sınıfa ait, nesne oluşturmaya gerek
/// olmadan çağrılabilir) çünkü uygulamada Hive'ın sadece BİR TANE global
/// örneği olur; "HiveService()" diye ayrı ayrı nesneler oluşturmanın bir
/// anlamı yok.
class HiveService {
  HiveService._(); // Bu sınıftan asla nesne oluşturulamasın diye özel (private) bir kurucu.

  /// Haftalık planların saklandığı "kutu"nun (box - Hive'da bir tablo gibi
  /// düşünülebilir) adı.
  static const String weeklyPlanBoxName = 'weekly_plan_box';

  /// Kullanıcı kaydının saklandığı kutunun adı.
  static const String userBoxName = 'user_box';

  /// Basit ayarlar (onboarding görüldü mü vb.) için tip-bağımsız kutu.
  static const String settingsBoxName = 'settings_box';

  /// Onboarding ekranının en az bir kez tamamlanıp tamamlanmadığı.
  static const String onboardingCompletedKey = 'onboarding_completed';

  /// Uygulamada sunucu hesabı olmadığı için, TEK kullanıcı kaydını hep bu
  /// sabit kimlikle (key) buluruz. Bkz. `data/models/user.dart`.
  static const String localUserId = 'local_user';

  /// Uygulama açılışında (main.dart'ta) BİR KERE çağrılır. Hive'ı başlatır,
  /// tüm modellerin "adaptör"lerini (Hive'a "bu sınıfı nasıl ikili veriye
  /// çevireceğini" öğreten, `build_runner`'ın ürettiği kodları) kaydeder ve
  /// ihtiyacımız olan kutuları açar.
  ///
  /// `Future<void>` ve `async` kullanıyoruz çünkü dosya sistemine erişmek
  /// (kutuları açmak) zaman alabilir; bu yüzden `main()` fonksiyonu bu iş
  /// bitene kadar BEKLEMELİDİR (aksi halde uygulama, veritabanı hazır
  /// olmadan ekran göstermeye çalışıp çökebilir).
  static Future<void> init() async {
    // `Hive.initFlutter()`: Hive'a, verileri telefonun işletim sistemine
    // (Android/iOS) uygun, doğru klasörde saklamasını söyler. Sade
    // `Hive.init()`'ten farkı, bu klasör yolunu Flutter'ın kendisinden
    // otomatik öğrenmesidir.
    await Hive.initFlutter();

    _registerAdapters();

    // `Hive.openBox<T>(isim)`: diskteki dosyayı açar (yoksa oluşturur) ve
    // bellekte kullanıma hazır hale getirir. Kutu açıldıktan sonra
    // `HiveService.weeklyPlanBox` gibi getter'larla her yerden erişilebilir.
    await Hive.openBox<WeeklyPlan>(weeklyPlanBoxName);
    await Hive.openBox<User>(userBoxName);
    await Hive.openBox(settingsBoxName);
  }

  /// Her modelin (ve enum'un) `build_runner` tarafından üretilen
  /// adaptörünü Hive'a tanıtır.
  ///
  /// `Hive.isAdapterRegistered(typeId)` kontrolünü NEDEN yapıyoruz?
  /// Flutter'da "hot restart" yaptığında `main()` fonksiyonu yeniden
  /// çalışabilir; eğer bir adaptörü İKİNCİ KEZ kaydetmeye çalışırsak Hive
  /// hata fırlatır. Bu kontrol sayesinde uygulama, geliştirme sırasında
  /// güvenle "hot restart" edilebilir.
  static void _registerAdapters() {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(NutrientAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(IngredientCategoryAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(IngredientAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(CookingMethodAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(MealTypeAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(RecipeAdapter());
    }
    if (!Hive.isAdapterRegistered(6)) {
      Hive.registerAdapter(DayOfWeekAdapter());
    }
    if (!Hive.isAdapterRegistered(7)) {
      Hive.registerAdapter(PlannedMealAdapter());
    }
    if (!Hive.isAdapterRegistered(8)) {
      Hive.registerAdapter(WeeklyPlanAdapter());
    }
    if (!Hive.isAdapterRegistered(9)) {
      Hive.registerAdapter(SubscriptionPlanAdapter());
    }
    if (!Hive.isAdapterRegistered(10)) {
      Hive.registerAdapter(UserAdapter());
    }
  }

  /// Haftalık planların tutulduğu kutuya kısayol. `Box<T>`, bir
  /// `Map<dynamic, T>` gibi davranır: `.get(key)`, `.put(key, value)`,
  /// `.values` gibi metodlarla kullanılır.
  static Box<WeeklyPlan> get weeklyPlanBox =>
      Hive.box<WeeklyPlan>(weeklyPlanBoxName);

  /// Kullanıcı kaydının tutulduğu kutuya kısayol.
  static Box<User> get userBox => Hive.box<User>(userBoxName);

  /// Basit ayarlar kutusu (onboarding vb.).
  static Box get settingsBox => Hive.box(settingsBoxName);

  static bool get hasCompletedOnboarding =>
      settingsBox.get(onboardingCompletedKey, defaultValue: false) == true;

  static Future<void> markOnboardingCompleted() async {
    await settingsBox.put(onboardingCompletedKey, true);
  }

  /// Kutuda kayıtlı kullanıcıyı getirir; HİÇ kayıt yoksa (uygulama ilk kez
  /// açıldıysa) yeni, "free" planlı bir kullanıcı oluşturup kaydeder ve onu
  /// döner. Bu sayede uygulamanın diğer bölümleri "kullanıcı null mı diye
  /// kontrol etmek" zorunda kalmaz; her zaman geçerli bir `User` nesnesi
  /// garanti edilir.
  static User getOrCreateLocalUser() {
    final existingUser = userBox.get(localUserId);
    if (existingUser != null) {
      // Kullanıcı uygulamayı haftalar sonra tekrar açmış olabilir; haftalık
      // AI/foto haklarının güncel haftaya göre sıfırlanması gerekip
      // gerekmediğini burada kontrol ediyoruz.
      existingUser.resetWeeklyUsageIfNeeded();
      existingUser.save();
      return existingUser;
    }

    final newUser = User(id: localUserId);
    userBox.put(localUserId, newUser);
    return newUser;
  }
}
