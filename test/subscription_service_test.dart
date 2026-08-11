import 'package:flutter_test/flutter_test.dart';
import 'package:plan_to_plate/data/models/user.dart';
import 'package:plan_to_plate/data/services/subscription_service.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Bu test dosyası, RevenueCat'e (gerçek ağ isteği / mağaza penceresi
/// AÇMADAN) bağlanmadan `SubscriptionService.applyCustomerInfoToUser`
/// metodunun doğru çalıştığını kanıtlar: RevenueCat'ten "bu kullanıcı
/// premium" bilgisi geldiğinde, bizim basit `User.isPremium` alanımızın
/// da doğru güncellendiğini doğrular.
void main() {
  EntitlementInfo buildEntitlement({
    required bool isActive,
    required String productIdentifier,
    String? expirationDate,
  }) {
    return EntitlementInfo(
      SubscriptionService.entitlementId,
      isActive,
      true,
      '2026-01-01T00:00:00Z',
      '2026-01-01T00:00:00Z',
      productIdentifier,
      false,
      expirationDate: expirationDate,
    );
  }

  CustomerInfo buildCustomerInfo({EntitlementInfo? activeEntitlement}) {
    final activeMap = activeEntitlement == null
        ? <String, EntitlementInfo>{}
        : {SubscriptionService.entitlementId: activeEntitlement};

    return CustomerInfo(
      EntitlementInfos(activeMap, activeMap),
      const {},
      const [],
      const [],
      const [],
      '2026-01-01T00:00:00Z',
      'local_user',
      const {},
      '2026-01-01T00:00:00Z',
    );
  }

  test('Aktif "yearly" ürünü olan bir yetki, kullanıcıyı Premium (yıllık) yapmalı', () {
    final user = User(id: 'local_user');
    final customerInfo = buildCustomerInfo(
      activeEntitlement: buildEntitlement(
        isActive: true,
        productIdentifier: 'plan_to_plate_yearly',
        expirationDate: '2027-01-01T00:00:00Z',
      ),
    );

    SubscriptionService.applyCustomerInfoToUser(user, customerInfo);

    expect(user.isPremium, isTrue);
    expect(user.subscriptionPlan, SubscriptionPlan.yearly);
    expect(user.premiumExpiryDate, DateTime.tryParse('2027-01-01T00:00:00Z'));
  });

  test('Aktif "monthly" ürünü olan bir yetki, kullanıcıyı Premium (aylık) yapmalı', () {
    final user = User(id: 'local_user');
    final customerInfo = buildCustomerInfo(
      activeEntitlement: buildEntitlement(
        isActive: true,
        productIdentifier: 'plan_to_plate_monthly',
      ),
    );

    SubscriptionService.applyCustomerInfoToUser(user, customerInfo);

    expect(user.isPremium, isTrue);
    expect(user.subscriptionPlan, SubscriptionPlan.monthly);
  });

  test('Aktif yetki YOKSA kullanıcı Free planına geri dönmeli', () {
    final user = User(
      id: 'local_user',
      subscriptionPlan: SubscriptionPlan.yearly,
      premiumExpiryDate: DateTime(2027, 1, 1),
    );
    final customerInfo = buildCustomerInfo(); // Hiç aktif yetki yok.

    SubscriptionService.applyCustomerInfoToUser(user, customerInfo);

    expect(user.isPremium, isFalse);
    expect(user.subscriptionPlan, SubscriptionPlan.free);
    expect(user.premiumExpiryDate, isNull);
  });
}
