import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/recipe_constraints.dart';
import 'hive_service.dart';

/// Kullanıcının kalıcı diyet / mutfak tercihleri.
class HouseholdPrefs {
  const HouseholdPrefs({
    this.vegetarian = false,
    this.glutenFree = false,
    this.airFryerOnly = false,
    this.noSpicy = false,
  });

  final bool vegetarian;
  final bool glutenFree;
  final bool airFryerOnly;
  final bool noSpicy;

  bool get hasAny => vegetarian || glutenFree || airFryerOnly || noSpicy;

  HouseholdPrefs copyWith({
    bool? vegetarian,
    bool? glutenFree,
    bool? airFryerOnly,
    bool? noSpicy,
  }) {
    return HouseholdPrefs(
      vegetarian: vegetarian ?? this.vegetarian,
      glutenFree: glutenFree ?? this.glutenFree,
      airFryerOnly: airFryerOnly ?? this.airFryerOnly,
      noSpicy: noSpicy ?? this.noSpicy,
    );
  }

  Map<String, dynamic> toJson() => {
        'vegetarian': vegetarian,
        'glutenFree': glutenFree,
        'airFryerOnly': airFryerOnly,
        'noSpicy': noSpicy,
      };

  factory HouseholdPrefs.fromJson(Map<String, dynamic> json) {
    return HouseholdPrefs(
      vegetarian: json['vegetarian'] == true,
      glutenFree: json['glutenFree'] == true,
      airFryerOnly: json['airFryerOnly'] == true,
      noSpicy: json['noSpicy'] == true,
    );
  }

  RecipeConstraints toConstraints() {
    return RecipeConstraints(
      vegetarian: vegetarian,
      glutenFree: glutenFree,
      airFryerOnly: airFryerOnly,
      noSpicy: noSpicy,
      noOven: airFryerOnly,
    );
  }
}

class HouseholdPrefsNotifier extends StateNotifier<HouseholdPrefs> {
  HouseholdPrefsNotifier() : super(_load());

  static const _key = 'household_prefs';

  static HouseholdPrefs _load() {
    final raw = HiveService.settingsBox.get(_key);
    if (raw is Map) {
      return HouseholdPrefs.fromJson(Map<String, dynamic>.from(raw));
    }
    return const HouseholdPrefs();
  }

  void _persist() => HiveService.settingsBox.put(_key, state.toJson());

  void update(HouseholdPrefs prefs) {
    state = prefs;
    _persist();
  }
}

final householdPrefsProvider =
    StateNotifierProvider<HouseholdPrefsNotifier, HouseholdPrefs>((ref) {
  return HouseholdPrefsNotifier();
});
