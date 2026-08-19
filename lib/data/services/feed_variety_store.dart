import 'hive_service.dart';

/// Keşfet / gece krizi için son gösterilen başlıkları tutar — tekrar azalır.
class FeedVarietyStore {
  FeedVarietyStore._();

  static const _discoverKey = 'discover_seen_titles';
  static const _snackKey = 'snack_seen_titles';
  static const _maxKept = 48;

  static List<String> recentDiscoverTitles() => _read(_discoverKey);
  static List<String> recentSnackTitles() => _read(_snackKey);

  static void markDiscoverShown(Iterable<String> titles) =>
      _append(_discoverKey, titles);
  static void markSnackShown(Iterable<String> titles) =>
      _append(_snackKey, titles);

  static List<String> _read(String key) {
    final raw = HiveService.settingsBox.get(key);
    if (raw is! List) return [];
    return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
  }

  static void _append(String key, Iterable<String> titles) {
    final next = <String>[
      ...titles.map((t) => t.trim()).where((t) => t.isNotEmpty),
      ..._read(key),
    ];
    final seen = <String>{};
    final unique = <String>[];
    for (final t in next) {
      final k = t.toLowerCase();
      if (seen.add(k)) unique.add(t);
      if (unique.length >= _maxKept) break;
    }
    HiveService.settingsBox.put(key, unique);
  }

  /// Başlık çakışması (normalize, kısmi eşleşme).
  static bool clashes(String title, Iterable<String> excluded) {
    final t = _norm(title);
    if (t.isEmpty) return false;
    for (final e in excluded) {
      final n = _norm(e);
      if (n.isEmpty) continue;
      if (t == n || t.contains(n) || n.contains(t)) return true;
    }
    return false;
  }

  static String _norm(String s) =>
      s.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
}
