import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Alt menü sekme indeksi (bildirim / derin link için).
/// 0 Plan · 1 Alışveriş · 2 Evdekiler · 3 Ayarlar
final shellTabIndexProvider = StateProvider<int>((ref) => 0);
