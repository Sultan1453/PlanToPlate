import 'package:flutter/material.dart';

import '../settings/settings_screen.dart';
import '../shopping_list/shopping_list_screen.dart';
import '../weekly_planner/weekly_planner_screen.dart';

/// Uygulamanın alt gezinme çubuğunu (bottom navigation bar) ve 3 ana
/// sekmesini (Haftalık Plan, Alışveriş Listesi, Ayarlar) barındıran kök
/// iskelet (shell) widget'ı. `main.dart`, `MaterialApp.home`'a doğrudan
/// bunu verir.
///
/// `IndexedStack` kullanıyoruz (basit bir `if/else` yerine) çünkü bu
/// widget, sekmeler arasında geçiş yaparken her ekranın state'ini
/// (örn. Haftalık Planlayıcı'da seçili gün) KORUR — kullanıcı Ayarlar'a
/// gidip geri döndüğünde Haftalık Plan sekmesi baştan çizilmez.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = [
    WeeklyPlannerScreen(),
    ShoppingListScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            activeIcon: Icon(Icons.calendar_month),
            label: 'Haftalık Plan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_outlined),
            activeIcon: Icon(Icons.shopping_cart),
            label: 'Alışveriş Listesi',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Ayarlar',
          ),
        ],
      ),
    );
  }
}
