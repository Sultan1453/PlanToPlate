import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../models/user.dart';
import '../models/weekly_plan.dart';
import 'hive_service.dart';
import 'subscription_service.dart';

/// `User` kaydını (Kural 1-2-3'ün TÜM limit/abonelik durumunu tutan
/// kayıt) uygulama genelinde okunabilir/güncellenebilir hale getiren
/// Riverpod katmanı.
///
/// NEDEN `StateNotifier`? `User` bir `HiveObject` olduğu için ZATEN
/// mutable'dır (değiştirilebilir): `user.weeklyRecipeGenerationCount += 1`
/// gibi bir satır, nesneyi YERİNDE değiştirir. Ama Riverpod/Flutter bu
/// değişikliği KENDİLİĞİNDEN fark edip ekranı yeniden çizmez; bu yüzden
/// her değişiklikten SONRA `state = state` yazarak Riverpod'a "durum
/// değişti, dinleyen widget'ları yeniden çiz" sinyalini ELLE veriyoruz
/// (`state_notifier` paketi, aynı referans bile olsa her atamada
/// dinleyicileri bilgilendirir).
class UserNotifier extends StateNotifier<User> {
  UserNotifier() : super(HiveService.getOrCreateLocalUser());

  /// En son [tryConsumeRecipeGeneration] çağrısında hangi kaynaktan
  /// (bonus mu, haftalık hak mı) harcama yapıldığını hatırlar; bir hata
  /// durumunda [refundLastRecipeGeneration] bu bilgiyi kullanarak DOĞRU
  /// kaynağa iade yapar. `null` ise henüz iade edilecek bir harcama yok.
  bool? _lastConsumptionUsedBonus;

  void _persistAndNotify() {
    if (state.isInBox) {
      state.save();
    }
    // ignore: avoid_self_assignment (bilerek: Riverpod'a "değişti" demek için)
    state = state;
  }

  /// Kullanıcı yeni bir AI tarifi üretmek istediğinde ÖNCE bu metod
  /// çağrılır (Kural 1 + Kural 2). Hakkı varsa ilgili sayaç/bonus düşülür
  /// ve `true` döner (ekran üretime devam eder); hakkı yoksa hiçbir şey
  /// değiştirilmeden `false` döner (ekran bu durumda Paywall'ı açar).
  bool tryConsumeRecipeGeneration() {
    state.resetWeeklyUsageIfNeeded();
    if (!state.canGenerateRecipe) {
      _persistAndNotify();
      return false;
    }
    _lastConsumptionUsedBonus = state.bonusRecipeCredits > 0;
    state.recordRecipeGeneration();
    _persistAndNotify();
    return true;
  }

  /// Az önce [tryConsumeRecipeGeneration] ile harcanan hakkı GERİ verir.
  /// Kullanıcı yemek adını yazmaktan vazgeçtiğinde veya AI üretimi bir
  /// HATA ile başarısız olduğunda çağrılır.
  void refundLastRecipeGeneration() {
    final usedBonus = _lastConsumptionUsedBonus;
    if (usedBonus == null) return;
    state.undoRecipeGeneration(usedBonus: usedBonus);
    _lastConsumptionUsedBonus = null;
    _persistAndNotify();
  }

  /// Aynı mantığın fotoğraf yükleme (Kural 1) için karşılığı.
  bool tryConsumePhotoUpload() {
    state.resetWeeklyUsageIfNeeded();
    if (!state.canUploadPhoto) {
      _persistAndNotify();
      return false;
    }
    state.recordPhotoUpload();
    _persistAndNotify();
    return true;
  }

  /// Kullanıcı ödüllü reklamı sonuna kadar izleyip ödülü kazandığında
  /// çağrılır (Kural 2-B: "Reklam İzle, +1 AI Tarifi Kazan").
  void grantRewardedAdCredit() {
    state.grantRewardedAdCredit();
    _persistAndNotify();
  }

  /// RevenueCat'ten gelen güncel abonelik bilgisini `User` kaydına işler
  /// (satın alma / geri yükleme / arka planda otomatik yenileme sonrası).
  void applyCustomerInfo(CustomerInfo customerInfo) {
    SubscriptionService.applyCustomerInfoToUser(state, customerInfo);
    _persistAndNotify();
  }

  /// Ayarlar ekranından alışveriş hatırlatma tercihini günceller.
  /// Bildirimin GERÇEKTEN kurulması/iptal edilmesi (`NotificationService`)
  /// bu metodun DIŞINDA, Ayarlar ekranında yapılır; bu metod sadece
  /// TERCİHİ kalıcı olarak saklar.
  void updateShoppingReminder({
    required bool enabled,
    DayOfWeek? day,
    int? hour,
    int? minute,
  }) {
    state.shoppingReminderEnabled = enabled;
    state.shoppingReminderDay = day;
    state.shoppingReminderHour = hour;
    state.shoppingReminderMinute = minute;
    _persistAndNotify();
  }
}

/// Uygulama genelinde `ref.watch(userProvider)` ile GÜNCEL kullanıcıyı
/// okumak, `ref.read(userProvider.notifier)` ile de yukarıdaki metodları
/// çağırmak için kullanılan TEK giriş noktası.
final userProvider = StateNotifierProvider<UserNotifier, User>((ref) {
  return UserNotifier();
});
