import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'data/services/ads_service.dart';
import 'data/services/hive_service.dart';
import 'data/services/notification_service.dart';
import 'data/services/subscription_service.dart';
import 'features/shell/app_shell.dart';

/// Uygulamanın giriş noktası.
///
/// `main()` fonksiyonunu `async` yaptık ve içine `await` ekledik çünkü artık
/// uygulama açılmadan ÖNCE Hive veritabanını hazırlamamız gerekiyor
/// (`HiveService.init()`); bu iş bitmeden ekranı göstermeye çalışırsak,
/// veritabanına erişen kodlar "kutu henüz açılmadı" hatasıyla çökebilir.
Future<void> main() async {
  // Flutter motorunun (native Android/iOS tarafıyla iletişim kurabilmesi
  // için) hazır olduğundan emin oluyoruz. `Hive.initFlutter()` gibi native
  // dosya sistemine erişen bir işlem çağırmadan önce bu satır ZORUNLUDUR.
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // Hive / AdMob / bildirimler hazır olana kadar native splash ekranını
  // (krem arka plan + logo) ekranda tutar; aksi halde kullanıcı kısa bir
  // beyaz boşluk görebilir.
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // `.env` dosyasını okuyup içindeki `GEMINI_API_KEY` değerini belleğe
  // yüklüyoruz. Bu satır sayesinde `dotenv.env['GEMINI_API_KEY']`
  // uygulamanın HER YERİNDEN okunabilir hale gelir (bkz.
  // `data/services/recipe_ai_service_provider.dart`). API anahtarı kodun
  // içine hiçbir zaman YAZILMAZ; sadece bu dosyadan okunur.
  //
  // `isOptional: true`: `.env` dosyası her nasılsa eksik/bozuksa bile
  // uygulama ÇÖKMEZ; sadece API anahtarını boş kabul edip Mock motoruna
  // (bkz. Adım 2) güvenle geri döner.
  await dotenv.load(fileName: '.env', isOptional: true);

  await HiveService.init();

  // Bildirim eklentisini ve saat dilimi veritabanını hazırlıyoruz. Bu
  // sadece ALTYAPIYI kurar; kullanıcıdan bildirim İZNİ isteme ve gerçek
  // hatırlatmayı kurma işlemi, Ayarlar ekranında kullanıcı "Haftalık
  // hatırlatmayı aç" dediğinde yapılır (bkz. `SettingsScreen`).
  await NotificationService.init();

  // RevenueCat (Premium abonelik) altyapısını başlatıyoruz. `.env`'de
  // henüz gerçek bir `REVENUECAT_API_KEY` yoksa bu çağrı sessizce hiçbir
  // şey yapmaz (bkz. `SubscriptionService.init`); uygulama Premium
  // özellikleri olmadan sorunsuz çalışmaya devam eder.
  await SubscriptionService.init(dotenv.env['REVENUECAT_API_KEY']?.trim() ?? '');

  // Google AdMob SDK'sını başlatıyoruz. Bu çağrı, gerçek/test reklam
  // kimliklerinden BAĞIMSIZ olarak her zaman güvenle yapılabilir.
  await AdsService.init();

  // Altyapı hazır → splash'i kaldır, asıl arayüzü göster.
  FlutterNativeSplash.remove();

  runApp(
    // `ProviderScope`, Riverpod'un TÜM `Provider`larının (örn. Adım 2'de
    // yazdığımız `recipeAiServiceProvider`) uygulama genelinde
    // erişilebilir olmasını sağlayan kök widget'tır. Uygulamanın en
    // dışında, TEK BİR KERE sarmalanır.
    const ProviderScope(child: MyApp()),
  );
}

/// Uygulamanın kök widget'ı: `MaterialApp`'i tek renk/yazı tipi kaynağımız
/// olan `AppTheme.light` ile kurar ve doğrudan `AppShell`'i (alt gezinme
/// çubuğu + 3 sekme) ana ekran olarak gösterir.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PlanToPlate: AI Meal Planner',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AppShell(),
    );
  }
}
