/// AI tarif üretiminde ortak kısıtlar (tekrar etme, süre, diyet vb.).
class RecipeConstraints {
  const RecipeConstraints({
    this.excludeTitles = const [],
    this.maxTotalMinutes,
    this.preferFewIngredients = false,
    this.noOven = false,
    this.vegetarian = false,
    this.glutenFree = false,
    this.airFryerOnly = false,
    this.noSpicy = false,
  });

  final List<String> excludeTitles;
  final int? maxTotalMinutes;
  final bool preferFewIngredients;
  final bool noOven;
  final bool vegetarian;
  final bool glutenFree;
  final bool airFryerOnly;
  final bool noSpicy;

  bool get hasAny =>
      excludeTitles.isNotEmpty ||
      maxTotalMinutes != null ||
      preferFewIngredients ||
      noOven ||
      vegetarian ||
      glutenFree ||
      airFryerOnly ||
      noSpicy;

  RecipeConstraints merge(RecipeConstraints? other) {
    if (other == null) return this;
    return RecipeConstraints(
      excludeTitles: {...excludeTitles, ...other.excludeTitles}.toList(),
      maxTotalMinutes: other.maxTotalMinutes ?? maxTotalMinutes,
      preferFewIngredients: preferFewIngredients || other.preferFewIngredients,
      noOven: noOven || other.noOven,
      vegetarian: vegetarian || other.vegetarian,
      glutenFree: glutenFree || other.glutenFree,
      airFryerOnly: airFryerOnly || other.airFryerOnly,
      noSpicy: noSpicy || other.noSpicy,
    );
  }

  String toPromptSection() {
    if (!hasAny) return '';
    final lines = <String>['Ek kısıtlar (zorunlu):'];
    if (excludeTitles.isNotEmpty) {
      lines.add(
        '- Şu yemekleri ÖNERME / TEKRAR ÜRETME (bu hafta planda var): '
        '${excludeTitles.take(20).map((e) => '"$e"').join(', ')}',
      );
    }
    if (maxTotalMinutes != null) {
      lines.add(
        '- Toplam süre (hazırlık + pişirme) en fazla $maxTotalMinutes dakika olsun.',
      );
    }
    if (preferFewIngredients) {
      lines.add('- Mümkün olduğunca az malzemeli, pratik bir tarif olsun (ideal ≤ 8 malzeme).');
    }
    if (noOven || airFryerOnly) {
      lines.add(
        '- Fırın KULLANMA. cookingMethod tercihen airfryer, stovetop, grill veya no_cook.',
      );
    }
    if (airFryerOnly) {
      lines.add('- Mümkünse airfryer ile pişir (cookingMethod: airfryer).');
    }
    if (vegetarian) {
      lines.add('- TAMAMEN vejetaryen olsun: et, tavuk, balık, et suyu KULLANMA.');
    }
    if (glutenFree) {
      lines.add('- Glutensiz olsun: un, makarna, bulgur, ekmek gibi glutenli malzemeler kullanma (veya glutensiz alternatif yaz).');
    }
    if (noSpicy) {
      lines.add('- Acı baharat / acı biber kullanma.');
    }
    return '\n${lines.join('\n')}\n';
  }
}
