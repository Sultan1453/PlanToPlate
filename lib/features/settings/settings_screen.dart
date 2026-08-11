import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/user.dart';
import '../../data/models/weekly_plan.dart';
import '../../data/services/ads_service.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/recipe_ai_service_provider.dart';
import '../../data/services/subscription_service.dart';
import '../../data/services/user_provider.dart';
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
                    : '.env dosyana geçerli bir GEMINI_API_KEY eklediğinde uygulama otomatik olarak gerçek Gemini AI\'ya geçer; kod değişikliği gerekmez.',
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
                    : 'Geliştirme sırasında (debug) her zaman Google\'ın test reklamları gösterilir; bu, AdMob hesabını korumak için kasıtlıdır. Play Store\'a yayınlarken (release derleme) .env\'e gerçek kimliklerini ekleyince otomatik devreye girer.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
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
