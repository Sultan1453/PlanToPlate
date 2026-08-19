import '../models/recipe.dart';

/// Evdeki malzemelerden üretilen AI öneri sonucu.
class FridgeSuggestionResult {
  const FridgeSuggestionResult({
    required this.recipes,
    this.suggestedBuys = const [],
    this.note,
  });

  /// Önerilen tarifler (genelde 2–3 adet).
  final List<Recipe> recipes;

  /// Az malzeme varsa tamamlamak için alınabilecek küçük ürünler.
  final List<SuggestedBuy> suggestedBuys;

  /// Kullanıcıya kısa açıklama (örn. "Malzemelerinle 2 tarif çıktı").
  final String? note;
}

/// Alınması önerilen küçük / ucuz malzeme.
class SuggestedBuy {
  const SuggestedBuy({required this.name, this.reason});

  final String name;
  final String? reason;
}
