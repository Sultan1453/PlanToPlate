import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/fridge_item.dart';
import 'hive_service.dart';

/// Evdeki malzemeler (öncelik etiketiyle) — settings kutusunda kalıcı.
class FridgeInventoryNotifier extends StateNotifier<List<FridgeItem>> {
  FridgeInventoryNotifier() : super(_load());

  static const _key = 'fridge_ingredients_v2';
  static const _legacyKey = 'fridge_ingredients';

  static List<FridgeItem> _load() {
    final raw = HiveService.settingsBox.get(_key);
    if (raw is List && raw.isNotEmpty) {
      return raw
          .map((e) {
            if (e is Map) {
              return FridgeItem.fromJson(Map<String, dynamic>.from(e));
            }
            return FridgeItem(name: e.toString());
          })
          .where((e) => e.name.trim().isNotEmpty)
          .toList();
    }

    // Eski string listesinden migrasyon
    final legacy = HiveService.settingsBox.get(_legacyKey);
    if (legacy is List) {
      final migrated = legacy
          .map((e) => FridgeItem(name: e.toString().trim()))
          .where((e) => e.name.isNotEmpty)
          .toList();
      if (migrated.isNotEmpty) {
        HiveService.settingsBox.put(
          _key,
          migrated.map((e) => e.toJson()).toList(),
        );
      }
      return migrated;
    }
    return [];
  }

  void _persist() {
    HiveService.settingsBox.put(
      _key,
      state.map((e) => e.toJson()).toList(),
    );
  }

  void add(String name, {FridgeUrgency urgency = FridgeUrgency.normal}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final lower = trimmed.toLowerCase();
    if (state.any((e) => e.name.toLowerCase() == lower)) return;
    state = [...state, FridgeItem(name: trimmed, urgency: urgency)];
    _persist();
  }

  void setUrgency(String name, FridgeUrgency urgency) {
    state = [
      for (final item in state)
        if (item.name == name) item.copyWith(urgency: urgency) else item,
    ];
    _persist();
  }

  void remove(String name) {
    state = state.where((e) => e.name != name).toList();
    _persist();
  }

  void clear() {
    state = [];
    _persist();
  }

  /// AI'ya verilecek isim listesi: önce "Önce tüket", sonra "Yakında".
  List<String> namesForAi() {
    final sorted = [...state]..sort((a, b) {
        return b.urgency.index.compareTo(a.urgency.index);
      });
    return sorted.map((e) => e.name).toList();
  }

  List<String> get names => state.map((e) => e.name).toList();
}

final fridgeInventoryProvider =
    StateNotifierProvider<FridgeInventoryNotifier, List<FridgeItem>>((ref) {
  return FridgeInventoryNotifier();
});
