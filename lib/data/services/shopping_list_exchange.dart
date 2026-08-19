import 'dart:convert';

import '../models/ingredient.dart';
import '../models/weekly_plan.dart';
import 'ingredient_aggregator_service.dart';
import 'shopping_list_service.dart';

/// Ortak alışveriş listesi: metin olarak paylaş / panodan içe aktar.
/// Sunucu yok; WhatsApp vb. ile kopyala-yapıştır.
class ShoppingListExchange {
  ShoppingListExchange._();

  static const marker = 'PLANTO_PLATE_LIST_V1';

  static String exportPayload(WeeklyPlan plan) {
    final auto = ShoppingListService.buildAutoShoppingList(plan);
    final manual = ShoppingListService.buildManualShoppingList(plan);

    final autoItems = <Map<String, dynamic>>[];
    for (final entries in auto.values) {
      for (final e in entries) {
        autoItems.add({
          'name': e.ingredient.name,
          'quantity': e.ingredient.quantity,
          'unit': e.ingredient.unit,
          'category': e.ingredient.category.name,
          'checked': e.ingredient.isChecked,
          'mergeKey': e.mergeKey,
        });
      }
    }

    final manualItems = manual.map((e) {
      return {
        'name': e.ingredient.name,
        'quantity': e.ingredient.quantity,
        'unit': e.ingredient.unit,
        'category': e.ingredient.category.name,
        'checked': e.ingredient.isChecked,
      };
    }).toList();

    final map = {
      'v': 1,
      'auto': autoItems,
      'manual': manualItems,
      'checkedKeys': plan.checkedAutoItemKeys.toList(),
    };
    final json = jsonEncode(map);
    return '$marker\n$json';
  }

  /// İçe aktarma: manuel ürünleri ekler, işaretleri birleştirir.
  /// [replaceManual] true ise mevcut manuel listeyi siler.
  static String importIntoPlan(
    WeeklyPlan plan,
    String raw, {
    bool replaceManual = false,
  }) {
    final trimmed = raw.trim();
    final start = trimmed.indexOf(marker);
    if (start < 0) {
      throw FormatException('Geçerli bir PlanToPlate listesi bulunamadı.');
    }
    final jsonPart = trimmed.substring(start + marker.length).trim();
    final decoded = jsonDecode(jsonPart);
    if (decoded is! Map) {
      throw FormatException('Liste okunamadı.');
    }
    final map = Map<String, dynamic>.from(decoded);

    if (replaceManual) {
      plan.manualItems.clear();
    }

    final manualRaw = map['manual'];
    if (manualRaw is List) {
      for (final item in manualRaw) {
        if (item is! Map) continue;
        final name = item['name']?.toString().trim() ?? '';
        if (name.isEmpty) continue;
        ShoppingListService.addManualItem(
          plan: plan,
          name: name,
          quantity: (item['quantity'] as num?)?.toDouble() ?? 1,
          unit: item['unit']?.toString() ?? 'adet',
          category: IngredientCategory.values.firstWhere(
            (c) => c.name == item['category'],
            orElse: () => IngredientCategory.other,
          ),
        );
        if (item['checked'] == true) {
          final last = plan.manualItems.last;
          last.isChecked = true;
        }
      }
    }

    final keys = map['checkedKeys'];
    if (keys is List) {
      for (final k in keys) {
        final key = k.toString();
        if (key.isEmpty) continue;
        if (!plan.checkedAutoItemKeys.contains(key)) {
          plan.checkedAutoItemKeys.add(key);
        }
      }
    }

    // Partner işaretli auto satırları (mergeKey yoksa isim|birim üret)
    final autoRaw = map['auto'];
    if (autoRaw is List) {
      for (final item in autoRaw) {
        if (item is! Map || item['checked'] != true) continue;
        var key = item['mergeKey']?.toString();
        if (key == null || key.isEmpty) {
          final fake = Ingredient(
            name: item['name']?.toString() ?? '',
            quantity: 1,
            unit: item['unit']?.toString() ?? 'adet',
            category: IngredientCategory.other,
          );
          key = IngredientAggregatorService.mergeKeyFor(fake);
        }
        if (!plan.checkedAutoItemKeys.contains(key)) {
          plan.checkedAutoItemKeys.add(key);
        }
      }
    }

    ShoppingListService.pruneStaleCheckedKeys(plan);
    return 'Liste içe aktarıldı.';
  }
}
