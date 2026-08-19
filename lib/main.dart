import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'data/services/ads_service.dart';
import 'data/services/hive_service.dart';
import 'data/services/notification_service.dart';
import 'data/services/subscription_service.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/shell/app_shell.dart';

/// Uygulamanın giriş noktası.
Future<void> main() async {
  // Sentry 9+: binding'i Sentry üzerinden kur (WidgetsFlutterBinding değil).
  final widgetsBinding = SentryWidgetsFlutterBinding.ensureInitialized();

  Future<void> startApp() async {
    FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

    await HiveService.init();
    await NotificationService.init();

    try {
      await SubscriptionService.init(AppConfig.revenueCatApiKey.trim());
    } catch (_) {
      // Açılışı asla engelleme.
    }

    try {
      await AdsService.init();
    } catch (_) {
      // Reklamsız devam.
    }

    FlutterNativeSplash.remove();

    runApp(
      const ProviderScope(child: MyApp()),
    );
  }

  if (AppConfig.hasSentry) {
    await SentryFlutter.init(
      (options) {
        options.dsn = AppConfig.sentryDsn;
        options.environment = kReleaseMode ? 'production' : 'debug';
        options.tracesSampleRate = kReleaseMode ? 0.15 : 0.0;
        options.sendDefaultPii = false;
      },
      appRunner: startApp,
    );
  } else {
    await startApp();
  }
}

/// Uygulamanın kök widget'ı.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PlanToPlate: AI Meal Planner',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: HiveService.hasCompletedOnboarding
          ? const AppShell()
          : const OnboardingScreen(),
    );
  }
}
