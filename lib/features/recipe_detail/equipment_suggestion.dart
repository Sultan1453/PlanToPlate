import '../../data/models/recipe.dart';

/// Pişirme yöntemine göre pratik ekipman önerisi.
class EquipmentSuggestion {
  const EquipmentSuggestion({
    required this.title,
    required this.detail,
    required this.iconName,
  });

  final String title;
  final String detail;

  /// Material icon ipucu (UI tarafında map edilir).
  final String iconName;

  static EquipmentSuggestion forRecipe(Recipe recipe) {
    switch (recipe.cookingMethod) {
      case CookingMethod.airFryer:
        return const EquipmentSuggestion(
          title: 'Airfryer sepeti',
          detail: '4–5 L sepet · tek kat dizim önerilir',
          iconName: 'air',
        );
      case CookingMethod.oven:
        return const EquipmentSuggestion(
          title: 'Fırın tepsisi',
          detail: 'Orta boy tepsi · 180–200°C için uygun',
          iconName: 'oven',
        );
      case CookingMethod.grill:
        return const EquipmentSuggestion(
          title: 'Izgara / grill pan',
          detail: '28 cm döküm veya oluklu tava',
          iconName: 'grill',
        );
      case CookingMethod.stovetop:
        final titleLower = recipe.title.toLowerCase();
        if (titleLower.contains('çorba') || titleLower.contains('corba')) {
          return const EquipmentSuggestion(
            title: 'Derin tencere',
            detail: '3–4 L paslanmaz veya döküm tencere',
            iconName: 'pot',
          );
        }
        if (titleLower.contains('tavuk') ||
            titleLower.contains('et') ||
            titleLower.contains('köfte') ||
            titleLower.contains('kofte')) {
          return const EquipmentSuggestion(
            title: '28 cm döküm tava',
            detail: 'Yüksek ısı tutar · eşit pişirme',
            iconName: 'pan',
          );
        }
        return const EquipmentSuggestion(
          title: '24–28 cm tava / tencere',
          detail: 'Yapışmaz veya döküm tercih edin',
          iconName: 'pan',
        );
      case CookingMethod.noCook:
        return const EquipmentSuggestion(
          title: 'Karıştırma kabı',
          detail: 'Bıçak + kesme tahtası yeterli',
          iconName: 'bowl',
        );
      case CookingMethod.other:
        return const EquipmentSuggestion(
          title: 'Standart mutfak seti',
          detail: 'Tencere + tava kombinasyonu',
          iconName: 'kitchen',
        );
    }
  }
}
