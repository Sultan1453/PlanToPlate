/// Evdeki malzemenin tüketim önceliği.
enum FridgeUrgency {
  /// Normal — öncelik yok.
  normal,

  /// Birkaç gün içinde bitmeli.
  soon,

  /// Bugün / yarın tüketilmeli.
  today,
}

extension FridgeUrgencyX on FridgeUrgency {
  String get label {
    switch (this) {
      case FridgeUrgency.normal:
        return 'Normal';
      case FridgeUrgency.soon:
        return 'Yakında bitmeli';
      case FridgeUrgency.today:
        return 'Önce tüket';
    }
  }

  String get shortLabel {
    switch (this) {
      case FridgeUrgency.normal:
        return '';
      case FridgeUrgency.soon:
        return 'Yakında';
      case FridgeUrgency.today:
        return 'Önce';
    }
  }
}

/// Evdekiler listesindeki tek ürün.
class FridgeItem {
  const FridgeItem({
    required this.name,
    this.urgency = FridgeUrgency.normal,
  });

  final String name;
  final FridgeUrgency urgency;

  FridgeItem copyWith({String? name, FridgeUrgency? urgency}) {
    return FridgeItem(
      name: name ?? this.name,
      urgency: urgency ?? this.urgency,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'urgency': urgency.name,
      };

  factory FridgeItem.fromJson(Map<String, dynamic> json) {
    return FridgeItem(
      name: (json['name'] ?? '').toString(),
      urgency: FridgeUrgency.values.firstWhere(
        (e) => e.name == json['urgency'],
        orElse: () => FridgeUrgency.normal,
      ),
    );
  }
}
