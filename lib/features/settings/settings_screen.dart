import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/user.dart';
import '../../data/models/weekly_plan.dart';
import '../../data/services/ads_service.dart';
import '../../data/services/fridge_inventory_provider.dart';
import '../../data/services/household_prefs_provider.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/recipe_ai_service_provider.dart';
import '../../data/services/shopping_list_service.dart';
import '../../data/services/subscription_service.dart';
import '../../data/services/user_provider.dart';
import '../../data/services/weekly_plan_provider.dart';
import '../favorites/favorites_screen.dart';
import '../paywall/paywall_screen.dart';

/// Ayarlar ekranı: alışveriş hatırlatma bildirimi, abonelik durumu ve
/// hangi AI motorunun (Mock/Gemini) aktif olduğu bilgisi.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late bool _reminderEnabled;
  late DayOfWeek _reminderDay;
  late TimeOfDay _reminderTime;
  bool _isSavingReminder = false;
  bool _isRestoringPurchases = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(userProvider);
    _reminderEnabled = user.shoppingReminderEnabled;
    _reminderDay = user.shoppingReminderDay ?? DayOfWeek.saturday;
    _reminderTime = TimeOfDay(
      hour: user.shoppingReminderHour ?? 10,
      minute: user.shoppingReminderMinute ?? 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final isUsingRealAi = ref.watch(isUsingRealAiProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            title: 'Favoriler',
            icon: Icons.favorite_outline,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.favorite, color: Colors.redAccent),
                title: const Text('Favori tariflerim'),
                subtitle: const Text('Kalple kaydettiğin tarifler'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const FavoritesScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Mutfak tercihleri',
            icon: Icons.restaurant_outlined,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Vejetaryen'),
                value: ref.watch(householdPrefsProvider).vegetarian,
                onChanged: (v) {
                  final p = ref.read(householdPrefsProvider);
                  ref.read(householdPrefsProvider.notifier).update(
                        p.copyWith(vegetarian: v),
                      );
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Glutensiz'),
                value: ref.watch(householdPrefsProvider).glutenFree,
                onChanged: (v) {
                  final p = ref.read(householdPrefsProvider);
                  ref.read(householdPrefsProvider.notifier).update(
                        p.copyWith(glutenFree: v),
                      );
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Sadece airfryer'),
                subtitle: const Text('Fırın önermesin'),
                value: ref.watch(householdPrefsProvider).airFryerOnly,
                onChanged: (v) {
                  final p = ref.read(householdPrefsProvider);
                  ref.read(householdPrefsProvider.notifier).update(
                        p.copyWith(airFryerOnly: v),
                      );
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Acı istemem'),
                value: ref.watch(householdPrefsProvider).noSpicy,
                onChanged: (v) {
                  final p = ref.read(householdPrefsProvider);
                  ref.read(householdPrefsProvider.notifier).update(
                        p.copyWith(noSpicy: v),
                      );
                },
              ),
              Text(
                'Bu tercihler tüm AI yemek önerilerine otomatik uygulanır.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Abonelik',
            icon: Icons.workspace_premium_outlined,
            children: [
              if (user.isPremium)
                _InfoRow(
                  label: 'Plan',
                  value: user.subscriptionPlan == SubscriptionPlan.yearly
                      ? 'Premium (Yıllık)'
                      : 'Premium (Aylık)',
                )
              else
                _InfoRow(label: 'Plan', value: 'Ücretsiz'),
              const SizedBox(height: 12),
              if (!user.isPremium)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.workspace_premium),
                    label: const Text('Premium\'a Geç'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PaywallScreen()),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isRestoringPurchases ? null : _restorePurchases,
                  child: _isRestoringPurchases
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Satın Alımları Geri Yükle'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Alışveriş Hatırlatması',
            icon: Icons.notifications_outlined,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _reminderEnabled,
                title: const Text('Haftalık hatırlatmayı aç'),
                subtitle: const Text('Seçtiğin gün ve saatte "Alışveriş günün geldi!" bildirimi al.'),
                onChanged: (value) => setState(() => _reminderEnabled = value),
              ),
              if (_reminderEnabled) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<DayOfWeek>(
                  key: ValueKey(_reminderDay),
                  initialValue: _reminderDay,
                  decoration: const InputDecoration(labelText: 'Gün'),
                  items: DayOfWeek.values
                      .map((day) => DropdownMenuItem(value: day, child: Text(day.displayName)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _reminderDay = value);
                  },
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule),
                  title: const Text('Saat'),
                  trailing: Text(
                    _reminderTime.format(context),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onTap: _pickTime,
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSavingReminder ? null : _saveReminder,
                  child: _isSavingReminder
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Kaydet'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Yapay Zeka Motoru',
            icon: Icons.smart_toy_outlined,
            children: [
              _InfoRow(
                label: 'Durum',
                value: isUsingRealAi ? 'Google Gemini (Gerçek AI)' : 'Lokal Yapay Zeka Veri Seti (Mock)',
              ),
              const SizedBox(height: 8),
              Text(
                isUsingRealAi
                    ? 'Tarifler doğrudan Google Gemini API\'sinden üretiliyor.'
                    : 'Geçerli bir GEMINI_API_KEY ile derlediğinde (scripts/run_dev.ps1) uygulama otomatik olarak gerçek Gemini AI\'ya geçer.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Reklamlar (AdMob)',
            icon: Icons.ondemand_video_outlined,
            children: [
              _InfoRow(
                label: 'Durum',
                value: AdsService.isUsingRealAdUnits ? 'Gerçek Reklamlar' : 'Test Reklamları',
              ),
              const SizedBox(height: 8),
              Text(
                AdsService.isUsingRealAdUnits
                    ? 'Release derlemede kendi AdMob reklam birimlerin kullanılıyor.'
                    : 'Geliştirme sırasında (debug) her zaman Google\'ın test reklamları gösterilir. Play Store release derlemesinde dart-define ile gerçek birim kimlikleri eklenince otomatik devreye girer.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
          if (AppConfig.hasPrivacyPolicyUrl) ...[
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Yasal',
              icon: Icons.privacy_tip_outlined,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.open_in_new),
                  title: const Text('Gizlilik politikası'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _openPrivacyPolicy,
                ),
              ],
            ),
          ],
          if (kDebugMode) ...[
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Geliştirici',
              icon: Icons.bug_report_outlined,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.send_outlined),
                  title: const Text('Sentry test hatası gönder'),
                  subtitle: Text(
                    AppConfig.hasSentry
                        ? 'Sentry paneline bir test event yollar'
                        : 'SENTRY_DSN yok — dart-define ile derle',
                  ),
                  enabled: AppConfig.hasSentry,
                  onTap: AppConfig.hasSentry ? _sendSentryTestEvent : null,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _sendSentryTestEvent() async {
    await Sentry.captureException(
      Exception('PlanToPlate Sentry test — ${DateTime.now().toIso8601String()}'),
      stackTrace: StackTrace.current,
    );
    // Event kuyruğa alındı; ağ gönderimi için kısa bekleme.
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sentry test gönderildi. 1–2 dk içinde Issues’a bak.'),
      ),
    );
  }

  Future<void> _openPrivacyPolicy() async {
    final uri = Uri.tryParse(AppConfig.privacyPolicyUrl.trim());
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gizlilik politikası açılamadı.')),
      );
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _reminderTime);
    if (picked != null) setState(() => _reminderTime = picked);
  }

  Future<void> _saveReminder() async {
    setState(() => _isSavingReminder = true);
    try {
      if (_reminderEnabled) {
        final granted = await NotificationService.requestPermission();
        if (!granted) {
          if (!mounted) return;
          setState(() => _reminderEnabled = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bildirim izni verilmedi. Hatırlatma alabilmek için telefon ayarlarından izin vermelisin.'),
            ),
          );
          return;
        }

        await NotificationService.scheduleWeeklyShoppingReminder(
          day: _reminderDay,
          hour: _reminderTime.hour,
          minute: _reminderTime.minute,
          uncheckedItemCount: ShoppingListService.countUncheckedItems(
            ref.read(weeklyPlanProvider),
            ownedAtHome: ref.read(fridgeInventoryProvider).map((e) => e.name),
          ),
        );
        ref.read(userProvider.notifier).updateShoppingReminder(
              enabled: true,
              day: _reminderDay,
              hour: _reminderTime.hour,
              minute: _reminderTime.minute,
            );
      } else {
        await NotificationService.cancelShoppingReminder();
        ref.read(userProvider.notifier).updateShoppingReminder(enabled: false);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ayarlar kaydedildi.')));
    } finally {
      if (mounted) setState(() => _isSavingReminder = false);
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _isRestoringPurchases = true);
    try {
      final customerInfo = await SubscriptionService.restorePurchases();
      ref.read(userProvider.notifier).applyCustomerInfo(customerInfo);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Satın alımların kontrol edildi.')),
      );
    } on PurchaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _isRestoringPurchases = false);
    }
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.icon, required this.children});

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primaryGreenDark),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}
