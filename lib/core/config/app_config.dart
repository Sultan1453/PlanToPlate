/// Derleme zamanı yapılandırması (`--dart-define` / `--dart-define-from-file`).
///
/// `.env` APK içine GÖMÜLMEZ. Yerel geliştirme:
/// `flutter run --dart-define-from-file=.env`
/// Release:
/// `flutter build appbundle --dart-define-from-file=.env --release`
class AppConfig {
  AppConfig._();

  static const String geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const String revenueCatApiKey =
      String.fromEnvironment('REVENUECAT_API_KEY');
  static const String admobBannerAdUnitId =
      String.fromEnvironment('ADMOB_BANNER_AD_UNIT_ID');
  static const String admobRewardedAdUnitId =
      String.fromEnvironment('ADMOB_REWARDED_AD_UNIT_ID');
  static const String sentryDsn = String.fromEnvironment('SENTRY_DSN');
  static const String privacyPolicyUrl =
      String.fromEnvironment('PRIVACY_POLICY_URL');

  /// Affiliate / deep link takip parametreleri.
  static const String affiliateRefId =
      String.fromEnvironment('AFFILIATE_REF_ID');
  static const String affiliateTag =
      String.fromEnvironment('AFFILIATE_TAG', defaultValue: 'plantoplate');

  static bool get hasSentry => sentryDsn.trim().isNotEmpty;
  static bool get hasPrivacyPolicyUrl => privacyPolicyUrl.trim().isNotEmpty;
}
