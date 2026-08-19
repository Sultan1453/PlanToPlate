import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../data/services/weekly_summary_service.dart';

Future<void> showWeeklySummarySheet(
  BuildContext context, {
  required WeeklySummary summary,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      final maxHeight = MediaQuery.sizeOf(ctx).height * 0.85;
      final stats = summary.stats;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Haftalık özet',
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  summary.weekLabel,
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textMuted,
                      ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                icon: Icons.local_fire_department_outlined,
                                title: 'Kalori',
                                value: stats.plannedMeals == 0
                                    ? '—'
                                    : '${stats.totalCalories.round()}',
                                subtitle: stats.plannedMeals == 0
                                    ? 'Öğün ekle'
                                    : 'kcal / hafta\nOrt. ${stats.avgDailyCalories.round()} kcal/gün',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatCard(
                                icon: Icons.account_balance_wallet_outlined,
                                title: 'Bütçe',
                                value: stats.shoppingItemCount == 0
                                    ? '—'
                                    : stats.budgetLabel,
                                subtitle: stats.shoppingItemCount == 0
                                    ? 'Liste boş'
                                    : 'tahmini alışveriş\n${stats.shoppingItemCount} kalem',
                              ),
                            ),
                          ],
                        ),
                        if (stats.plannedMeals > 0) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _MacroChip(
                                  label: 'Protein',
                                  value: '${stats.totalProtein.round()}g',
                                ),
                                _MacroChip(
                                  label: 'Karb',
                                  value: '${stats.totalCarbs.round()}g',
                                ),
                                _MacroChip(
                                  label: 'Yağ',
                                  value: '${stats.totalFat.round()}g',
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (stats.topCostLines.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            'En maliyetli kalemler',
                            style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 8),
                          for (final line in stats.topCostLines)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  Expanded(child: Text(line.label)),
                                  Text(
                                    '~₺${line.tryAmount.round()}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryGreenDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Text(
                            'Fiyatlar tahmindir; markete göre değişir.',
                            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textMuted,
                                ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Text(
                          'Menü',
                          style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${summary.plannedMeals} / ${summary.totalSlots} öğün',
                                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              if (summary.dayLines.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                for (final line in summary.dayLines) ...[
                                  Text(line),
                                  const SizedBox(height: 4),
                                ],
                              ] else
                                Text(
                                  'Bu hafta henüz yemek yok.',
                                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                                        color: AppColors.textMuted,
                                      ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: summary.plannedMeals == 0
                      ? null
                      : () async {
                          await Share.share(
                            summary.shareText,
                            subject:
                                'PlanToPlate — Haftalık özet (${summary.weekLabel})',
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Özeti paylaş'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primaryGreenDark, size: 22),
          const SizedBox(height: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.textMuted,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                ),
          ),
        ],
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  const _MacroChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
              ),
        ),
      ],
    );
  }
}
