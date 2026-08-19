import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/weekly_plan.dart';

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int shoppingReminderNotificationId = 1;
  static const int prepReminderNotificationIdBase = 2000;
  static const String shoppingPayload = 'shopping';
  static const String prepPayload = 'prep';

  static const String _channelId = 'shopping_reminders';
  static const String _channelName = 'Alışveriş Hatırlatmaları';
  static const String _channelDescription =
      'Haftalık alışveriş listeni kontrol etme hatırlatması';

  static const String _prepChannelId = 'prep_reminders';
  static const String _prepChannelName = 'Ön hazırlık';
  static const String _prepChannelDescription =
      'Buzluk / ön hazırlık hatırlatmaları';

  /// Bildirime tıklanınca (veya soğuk açılışta) çağrılır.
  static void Function(String? payload)? onNotificationOpened;

  static Future<void> init() async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        onNotificationOpened?.call(response.payload);
      },
    );

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.defaultImportance,
    );
    const prepChannel = AndroidNotificationChannel(
      _prepChannelId,
      _prepChannelName,
      description: _prepChannelDescription,
      importance: Importance.defaultImportance,
    );
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(channel);
    await androidPlugin?.createNotificationChannel(prepChannel);
  }

  /// Uygulama bildirimden açıldıysa payload döner.
  static Future<String?> consumeLaunchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp == true) {
      return details!.notificationResponse?.payload;
    }
    return null;
  }

  static Future<bool> requestPermission() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final granted = await androidPlugin?.requestNotificationsPermission();
    return granted ?? false;
  }

  static Future<void> scheduleWeeklyShoppingReminder({
    required DayOfWeek day,
    required int hour,
    required int minute,
    int? uncheckedItemCount,
  }) async {
    final firstOccurrence = _nextInstanceOfDayAndTime(day, hour, minute);
    final body = (uncheckedItemCount != null && uncheckedItemCount > 0)
        ? 'Listende yaklaşık $uncheckedItemCount ürün var. Kontrol et!'
        : 'Listeni kontrol ettin mi?';

    await _plugin.zonedSchedule(
      id: shoppingReminderNotificationId,
      title: 'Alışveriş günün geldi! 🛒',
      body: body,
      scheduledDate: firstOccurrence,
      payload: shoppingPayload,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  static Future<void> cancelShoppingReminder() async {
    await _plugin.cancel(id: shoppingReminderNotificationId);
  }

  /// [hoursFromNow] saat sonra tek seferlik ön hazırlık bildirimi.
  static Future<void> schedulePrepReminder({
    required String recipeTitle,
    required int hoursFromNow,
  }) async {
    final hours = hoursFromNow.clamp(1, 72);
    final when = tz.TZDateTime.now(tz.local).add(Duration(hours: hours));
    final id = prepReminderNotificationIdBase +
        (recipeTitle.hashCode.abs() % 500);

    await _plugin.zonedSchedule(
      id: id,
      title: 'Ön hazırlık zamanı 🧊',
      body: '"$recipeTitle" için hazırlığa başla (buzluk / marine).',
      scheduledDate: when,
      payload: prepPayload,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _prepChannelId,
          _prepChannelName,
          channelDescription: _prepChannelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  static tz.TZDateTime _nextInstanceOfDayAndTime(DayOfWeek day, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    final targetWeekday = _dartWeekdayFor(day);

    while (scheduled.weekday != targetWeekday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

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
