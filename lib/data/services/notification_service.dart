import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/weekly_plan.dart';

/// Alışveriş hatırlatma bildirimlerini yöneten servis.
///
/// Kullanılan paket: `flutter_local_notifications`. Bu paket, İNTERNET
/// GEREKTİRMEDEN, doğrudan telefonun kendi bildirim sistemine planlı
/// (zamanlanmış) bildirim ekler — sunucu, push notification altyapısı
/// (Firebase vb.) gerekmez, bu yüzden basit ve ücretsizdir.
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Alışveriş hatırlatma bildirimine SABİT bir kimlik (id) veriyoruz.
  /// Böylece kullanıcı ayarlardan gün/saati değiştirdiğinde, ESKİ
  /// bildirimin üzerine YENİSİNİ planlarız (aynı id ile tekrar
  /// `zonedSchedule` çağırmak, öncekini otomatik değiştirir); iki farklı
  /// bildirim birikip kullanıcıyı rahatsız etmez.
  static const int shoppingReminderNotificationId = 1;

  static const String _channelId = 'shopping_reminders';
  static const String _channelName = 'Alışveriş Hatırlatmaları';
  static const String _channelDescription =
      'Haftalık alışveriş listeni kontrol etme hatırlatması';

  /// Uygulama açılışında (main.dart'ta, Hive'dan sonra) BİR KERE çağrılır.
  /// Bildirim eklentisini başlatır ve saat dilimi (timezone) veritabanını
  /// yükler — zamanlanmış bildirimlerin DOĞRU saatte gelmesi için bu veri
  /// tabanı gereklidir (örn. yaz/kış saati uygulamasını doğru hesaplamak
  /// için).
  static Future<void> init() async {
    tz_data.initializeTimeZones();

    // NOT: Uygulamanın şu anki hedef kitlesi Türkiye olduğu için saat
    // dilimini sabit "Europe/Istanbul" olarak ayarlıyoruz. İleride
    // uygulama başka ülkelere açılırsa, cihazın GERÇEK saat dilimini
    // otomatik algılamak için `flutter_timezone` paketi eklenip bu satır
    // dinamik hale getirilebilir.
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings: initSettings);

    // Android'de bildirimlerin göründüğü "kanalı" (channel) önceden
    // oluşturuyoruz. Android 8.0 (API 26) ve üzerinde her bildirim bir
    // kanala ait OLMAK ZORUNDADIR; kullanıcı bu kanalı (isterse) ayarlardan
    // tamamen kapatabilir, bu da uygulamanın "iyi vatandaş" davranışının
    // bir parçasıdır.
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.defaultImportance,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Android 13 (API 33) ve üzeri sürümlerde, bildirim göstermek için
  /// kullanıcıdan ÇALIŞMA ZAMANINDA (runtime) açık izin istemek ZORUNLUDUR
  /// (eski Android sürümlerinde bildirim izni otomatik verilirdi, artık
  /// değil). Bu metod o izni ister ve kullanıcının kararını (`true`/`false`)
  /// döner.
  ///
  /// Kullanıcı izni REDDEDERSE (`false` dönerse), uygulamanın ÇÖKMEMESİ
  /// gerekir — sadece bildirim gösterilemez, ayarlar ekranında bunu şık bir
  /// mesajla kullanıcıya bildireceğiz (Adım 6/7'de arayüzü yazarken).
  ///
  /// Android 13'ten ESKİ sürümlerde bu metodun çağrılması güvenlidir; paket
  /// gerekmediğini kendisi anlar ve `true` döner.
  static Future<bool> requestPermission() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final granted = await androidPlugin?.requestNotificationsPermission();
    return granted ?? false;
  }

  /// Kullanıcının Ayarlar ekranından seçtiği gün ve saate göre, HER HAFTA
  /// tekrar eden bir alışveriş hatırlatma bildirimi kurar.
  ///
  /// `matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime`
  /// kullanmamızın sebebi: bu ayar, bildirime "sadece BİR KERE değil, her
  /// hafta bu gün ve bu saatte tekrar et" der. Böylece kullanıcı bildirimi
  /// bir kez kurduktan sonra, biz her hafta yeniden kurmak zorunda kalmayız.
  static Future<void> scheduleWeeklyShoppingReminder({
    required DayOfWeek day,
    required int hour,
    required int minute,
  }) async {
    final firstOccurrence = _nextInstanceOfDayAndTime(day, hour, minute);

    await _plugin.zonedSchedule(
      id: shoppingReminderNotificationId,
      title: 'Alışveriş günün geldi! 🛒',
      body: 'Listeni kontrol ettin mi?',
      scheduledDate: firstOccurrence,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      // Kesin/hassas alarm izni (Android 12+ "tam zamanlı alarm" izni)
      // GEREKTİRMEYEN, pil dostu bir zamanlama modu seçiyoruz. Bu
      // hatırlatma için saniyesi saniyesine gelmesi kritik değil; telefon
      // uykudayken bile birkaç dakika içinde ulaşması yeterlidir. Bu
      // seçim, kullanıcıdan EK bir "tam zamanlı alarm" izni istemekten
      // kaçınmamızı sağlar.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  /// Alışveriş hatırlatmasını tamamen kapatır (kullanıcı ayarlardan
  /// bildirimi kapattığında çağrılır).
  static Future<void> cancelShoppingReminder() async {
    await _plugin.cancel(id: shoppingReminderNotificationId);
  }

  /// Verilen `DayOfWeek` ve saatten, "bundan sonraki en yakın" tarih/saat
  /// anını hesaplar. Örn: bugün Çarşamba ve kullanıcı "Cumartesi 10:00"
  /// seçtiyse, bu fonksiyon önümüzdeki Cumartesi 10:00'ı bulur (eğer bugün
  /// zaten Cumartesi ve saat 10:00'ı henüz geçmediyse, BUGÜNÜ döner).
  static tz.TZDateTime _nextInstanceOfDayAndTime(DayOfWeek day, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    final targetWeekday = _dartWeekdayFor(day);

    // Doğru güne denk gelene VE henüz geçmemiş olana kadar, gün gün ileri
    // sarıyoruz. En fazla 7 kere döner (bir haftadan uzun sürmez).
    while (scheduled.weekday != targetWeekday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Bizim `DayOfWeek` enum'ımızı (monday=0..sunday=6), Dart'ın kendi
  /// `DateTime.weekday` değerine (monday=1..sunday=7) çevirir.
  static int _dartWeekdayFor(DayOfWeek day) {
    switch (day) {
      case DayOfWeek.monday:
        return DateTime.monday;
      case DayOfWeek.tuesday:
        return DateTime.tuesday;
      case DayOfWeek.wednesday:
        return DateTime.wednesday;
      case DayOfWeek.thursday:
        return DateTime.thursday;
      case DayOfWeek.friday:
        return DateTime.friday;
      case DayOfWeek.saturday:
        return DateTime.saturday;
      case DayOfWeek.sunday:
        return DateTime.sunday;
    }
  }
}
