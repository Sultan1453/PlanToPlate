import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/banner_ad_widget.dart';
import '../../data/services/navigation_provider.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/user_provider.dart';
import '../fridge/fridge_screen.dart';
import '../settings/settings_screen.dart';
import '../shopping_list/shopping_list_screen.dart';
import '../weekly_planner/weekly_planner_screen.dart';

/// Alt gezinme çubuğu ve 4 ana sekme.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with WidgetsBindingObserver {
  static const List<Widget> _screens = [
    WeeklyPlannerScreen(),
    ShoppingListScreen(),
    FridgeScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationService.onNotificationOpened = _onNotificationPayload;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final payload = await NotificationService.consumeLaunchPayload();
      _onNotificationPayload(payload);
    });
  }

  void _onNotificationPayload(String? payload) {
    if (!mounted) return;
    if (payload == NotificationService.shoppingPayload) {
      ref.read(shellTabIndexProvider.notifier).state = 1;
    } else if (payload == NotificationService.prepPayload) {
      // Ön hazırlık hatırlatması → Plan sekmesi
      ref.read(shellTabIndexProvider.notifier).state = 0;
    }
  }

  @override
  void dispose() {
    if (NotificationService.onNotificationOpened == _onNotificationPayload) {
      NotificationService.onNotificationOpened = null;
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(userProvider.notifier).ensureWeeklyUsageFresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(shellTabIndexProvider);

    return Scaffold(
      body: IndexedStack(index: selectedIndex, children: _screens),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Banner her zaman mount kalsın; Ayarlar'da Offstage ile gizlenir.
          const BannerAdWidget(),
          BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: selectedIndex,
            onTap: (index) =>
                ref.read(shellTabIndexProvider.notifier).state = index,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.calendar_month_outlined),
                activeIcon: Icon(Icons.calendar_month),
                label: 'Plan',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.shopping_cart_outlined),
                activeIcon: Icon(Icons.shopping_cart),
                label: 'Alışveriş',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.kitchen_outlined),
                activeIcon: Icon(Icons.kitchen),
                label: 'Evdekiler',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings_outlined),
                activeIcon: Icon(Icons.settings),
                label: 'Ayarlar',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
