import 'dart:math';

import '../models/recipe.dart';
import 'feed_variety_store.dart';
import 'mock_recipe_dataset.dart';

/// Keşfet / gece krizi ruh halleri.
enum FeedMood {
  all,
  salty,
  sweet,
  protein,
  cold,
  breadTop,
  quick,
  light,
  comfort,
}

extension FeedMoodLabel on FeedMood {
  String get label {
    switch (this) {
      case FeedMood.all:
        return 'Hepsi';
      case FeedMood.salty:
        return 'Tuzlu';
      case FeedMood.sweet:
        return 'Tatlı';
      case FeedMood.protein:
        return 'Protein';
      case FeedMood.cold:
        return 'Soğuk';
      case FeedMood.breadTop:
        return 'Ekmek üstü';
      case FeedMood.quick:
        return 'Hızlı';
      case FeedMood.light:
        return 'Hafif';
      case FeedMood.comfort:
        return 'Doyurucu';
    }
  }
}

/// Geniş yerel katalog — mock/AI fallback ve Keşfet destesi için.
class SnackDiscoverCatalog {
  SnackDiscoverCatalog._();

  /// Gece atıştırmalıkları (mood etiketli).
  static final List<Map<String, dynamic>> snacks = [
    _snack(
      'Ballı Yoğurt Kasesi',
      moods: [FeedMood.sweet, FeedMood.cold, FeedMood.quick],
      cal: 220,
      p: 12,
      c: 28,
      f: 6,
      mins: 3,
      method: 'no_cook',
      ings: [
        _ing('Yoğurt', 1, 'kase', 'dairy'),
        _ing('Bal', 1, 'yemek kaşığı', 'pantry'),
        _ing('Ceviz', 4, 'adet', 'pantry'),
      ],
      steps: ['Yoğurdu kaseye koy.', 'Bal gezdir, ceviz serpiştir.'],
    ),
    _snack(
      'Muzlu Fıstık Ezmesi Toast',
      moods: [FeedMood.sweet, FeedMood.breadTop, FeedMood.quick, FeedMood.protein],
      cal: 310,
      p: 10,
      c: 36,
      f: 14,
      mins: 5,
      method: 'no_cook',
      ings: [
        _ing('Ekmek', 1, 'dilim', 'bakery'),
        _ing('Fıstık ezmesi', 1, 'yemek kaşığı', 'pantry'),
        _ing('Muz', 0.5, 'adet', 'produce'),
      ],
      steps: ['Ekmeğe fıstık ezmesi sür.', 'Muz dilimle.'],
    ),
    _snack(
      'Çikolatalı Sütlü İrmik',
      moods: [FeedMood.sweet, FeedMood.comfort, FeedMood.quick],
      cal: 280,
      p: 8,
      c: 40,
      f: 9,
      mins: 8,
      method: 'stovetop',
      ings: [
        _ing('Süt', 1, 'su bardağı', 'dairy'),
        _ing('İrmik', 2, 'yemek kaşığı', 'pantry'),
        _ing('Kakao', 1, 'tatlı kaşığı', 'pantry'),
        _ing('Şeker', 1, 'tatlı kaşığı', 'pantry'),
      ],
      steps: [
        'Sütü ısıt, irmik ve kakaoyu çırp.',
        'Kıvam alınca şekeri ekle, 1 dk daha pişir.',
      ],
    ),
    _snack(
      'Hurma & Badem',
      moods: [FeedMood.sweet, FeedMood.cold, FeedMood.quick, FeedMood.protein],
      cal: 190,
      p: 5,
      c: 28,
      f: 8,
      mins: 1,
      method: 'no_cook',
      ings: [
        _ing('Hurma', 3, 'adet', 'produce'),
        _ing('Badem', 8, 'adet', 'pantry'),
      ],
      steps: ['Hurma ve bademi bir tabakta birleştir.'],
    ),
    _snack(
      'Tarçınlı Elma Dilimleri',
      moods: [FeedMood.sweet, FeedMood.light, FeedMood.quick],
      cal: 95,
      p: 1,
      c: 22,
      f: 0,
      mins: 4,
      method: 'no_cook',
      ings: [
        _ing('Elma', 1, 'adet', 'produce'),
        _ing('Tarçın', 1, 'tutam', 'pantry'),
      ],
      steps: ['Elmayı dilimle, tarçın serp.'],
    ),
    _snack(
      'Peynirli Domates Kanape',
      moods: [FeedMood.salty, FeedMood.breadTop, FeedMood.quick, FeedMood.cold],
      cal: 240,
      p: 12,
      c: 18,
      f: 12,
      mins: 5,
      method: 'no_cook',
      ings: [
        _ing('Ekmek', 2, 'dilim', 'bakery'),
        _ing('Beyaz peynir', 40, 'g', 'dairy'),
        _ing('Domates', 1, 'adet', 'produce'),
        _ing('Zeytin', 4, 'adet', 'pantry'),
      ],
      steps: ['Ekmeğe peynir koy, domates ve zeytin ekle.'],
    ),
    _snack(
      'Avokadolu Yumurta Toast',
      moods: [FeedMood.salty, FeedMood.breadTop, FeedMood.protein, FeedMood.quick],
      cal: 340,
      p: 16,
      c: 22,
      f: 22,
      mins: 8,
      method: 'stovetop',
      ings: [
        _ing('Ekmek', 1, 'dilim', 'bakery'),
        _ing('Avokado', 0.5, 'adet', 'produce'),
        _ing('Yumurta', 1, 'adet', 'dairy'),
        _ing('Tuz', 1, 'tutam', 'pantry'),
      ],
      steps: [
        'Yumurtayı haşla veya sahanda pişir.',
        'Avokadoyu ez, ekmeğe sür, yumurtayı üzerine koy.',
      ],
    ),
    _snack(
      'Humus + Havuç Stick',
      moods: [FeedMood.salty, FeedMood.cold, FeedMood.light, FeedMood.quick],
      cal: 180,
      p: 6,
      c: 20,
      f: 8,
      mins: 4,
      method: 'no_cook',
      ings: [
        _ing('Humus', 3, 'yemek kaşığı', 'pantry'),
        _ing('Havuç', 1, 'adet', 'produce'),
      ],
      steps: ['Havucu çubuk doğra, humusa batır.'],
    ),
    _snack(
      'Ton Balıklı Mısır Salatası Mini',
      moods: [FeedMood.salty, FeedMood.protein, FeedMood.cold, FeedMood.quick],
      cal: 260,
      p: 22,
      c: 14,
      f: 12,
      mins: 6,
      method: 'no_cook',
      ings: [
        _ing('Ton balığı', 1, 'kutu', 'pantry'),
        _ing('Mısır', 3, 'yemek kaşığı', 'pantry'),
        _ing('Limon', 0.5, 'adet', 'produce'),
        _ing('Zeytinyağı', 1, 'tatlı kaşığı', 'pantry'),
      ],
      steps: ['Ton ve mısırı karıştır, limon + yağ gezdir.'],
    ),
    _snack(
      'Sıcak Sütlü Kakao',
      moods: [FeedMood.sweet, FeedMood.comfort, FeedMood.quick],
      cal: 160,
      p: 7,
      c: 22,
      f: 5,
      mins: 5,
      method: 'stovetop',
      ings: [
        _ing('Süt', 1, 'su bardağı', 'dairy'),
        _ing('Kakao', 1, 'tatlı kaşığı', 'pantry'),
        _ing('Bal', 1, 'tatlı kaşığı', 'pantry'),
      ],
      steps: ['Sütü ısıt, kakao ve balı çırp.'],
    ),
    _snack(
      'Lorlu Salatalık Dilimi',
      moods: [FeedMood.salty, FeedMood.protein, FeedMood.light, FeedMood.cold],
      cal: 140,
      p: 14,
      c: 6,
      f: 7,
      mins: 4,
      method: 'no_cook',
      ings: [
        _ing('Lor peynir', 80, 'g', 'dairy'),
        _ing('Salatalık', 1, 'adet', 'produce'),
        _ing('Dereotu', 1, 'tutam', 'produce'),
      ],
      steps: ['Salatalığı dilimle, lor ve dereotu koy.'],
    ),
    _snack(
      'Hardallı Hindi Rulo',
      moods: [FeedMood.salty, FeedMood.protein, FeedMood.cold, FeedMood.quick],
      cal: 200,
      p: 24,
      c: 4,
      f: 10,
      mins: 5,
      method: 'no_cook',
      ings: [
        _ing('Hindi füme', 4, 'dilim', 'butcher'),
        _ing('Hardal', 1, 'tatlı kaşığı', 'pantry'),
        _ing('Marul', 2, 'yaprak', 'produce'),
      ],
      steps: ['Dilime hardal sür, marul koyup rulo yap.'],
    ),
    _snack(
      'Haşlanmış Yumurta + Baharat',
      moods: [FeedMood.salty, FeedMood.protein, FeedMood.quick],
      cal: 155,
      p: 13,
      c: 1,
      f: 11,
      mins: 9,
      method: 'stovetop',
      ings: [
        _ing('Yumurta', 2, 'adet', 'dairy'),
        _ing('Tuz', 1, 'tutam', 'pantry'),
        _ing('Karabiber', 1, 'tutam', 'pantry'),
      ],
      steps: ['Yumurtaları 7–8 dk haşla, soy, baharatla ye.'],
    ),
    _snack(
      'Süzme Yoğurt + Salatalık',
      moods: [FeedMood.salty, FeedMood.light, FeedMood.cold, FeedMood.protein],
      cal: 120,
      p: 11,
      c: 8,
      f: 4,
      mins: 3,
      method: 'no_cook',
      ings: [
        _ing('Süzme yoğurt', 3, 'yemek kaşığı', 'dairy'),
        _ing('Salatalık', 0.5, 'adet', 'produce'),
        _ing('Sarımsak', 0.5, 'diş', 'produce'),
      ],
      steps: ['Yoğurda rende salatalık ve sarımsak karıştır.'],
    ),
    _snack(
      'Peynirli Lavaş Rulo',
      moods: [FeedMood.salty, FeedMood.breadTop, FeedMood.comfort, FeedMood.quick],
      cal: 290,
      p: 14,
      c: 28,
      f: 13,
      mins: 6,
      method: 'no_cook',
      ings: [
        _ing('Lavaş', 1, 'adet', 'bakery'),
        _ing('Kaşar', 40, 'g', 'dairy'),
        _ing('Marul', 2, 'yaprak', 'produce'),
      ],
      steps: ['Lavaşın içine kaşar ve marul koy, sar.'],
    ),
    _snack(
      'Zeytinli Mini Omlet',
      moods: [FeedMood.salty, FeedMood.protein, FeedMood.quick],
      cal: 230,
      p: 15,
      c: 3,
      f: 18,
      mins: 7,
      method: 'stovetop',
      ings: [
        _ing('Yumurta', 2, 'adet', 'dairy'),
        _ing('Zeytin', 5, 'adet', 'pantry'),
        _ing('Zeytinyağı', 1, 'tatlı kaşığı', 'pantry'),
      ],
      steps: ['Yumurtayı çırp, zeytin ekle, tavada pişir.'],
    ),
    _snack(
      'Çilekli Yoğurt',
      moods: [FeedMood.sweet, FeedMood.cold, FeedMood.light, FeedMood.quick],
      cal: 150,
      p: 9,
      c: 20,
      f: 3,
      mins: 3,
      method: 'no_cook',
      ings: [
        _ing('Yoğurt', 1, 'kase', 'dairy'),
        _ing('Çilek', 5, 'adet', 'produce'),
      ],
      steps: ['Çileği doğra, yoğurda karıştır.'],
    ),
    _snack(
      'Tahin-Pekmez Kaşığı',
      moods: [FeedMood.sweet, FeedMood.quick, FeedMood.comfort],
      cal: 210,
      p: 5,
      c: 22,
      f: 12,
      mins: 1,
      method: 'no_cook',
      ings: [
        _ing('Tahin', 1, 'yemek kaşığı', 'pantry'),
        _ing('Pekmez', 1, 'yemek kaşığı', 'pantry'),
      ],
      steps: ['Tahin ve pekmezi karıştırıp ye.'],
    ),
    _snack(
      'Mısır Gevreği + Süt Mini',
      moods: [FeedMood.sweet, FeedMood.quick, FeedMood.cold],
      cal: 200,
      p: 7,
      c: 34,
      f: 4,
      mins: 2,
      method: 'no_cook',
      ings: [
        _ing('Mısır gevreği', 1, 'avuç', 'pantry'),
        _ing('Süt', 0.5, 'su bardağı', 'dairy'),
      ],
      steps: ['Gevreğe süt dök, hemen ye.'],
    ),
    _snack(
      'Biberli Beyaz Peynir',
      moods: [FeedMood.salty, FeedMood.protein, FeedMood.cold, FeedMood.light],
      cal: 170,
      p: 12,
      c: 5,
      f: 11,
      mins: 3,
      method: 'no_cook',
      ings: [
        _ing('Beyaz peynir', 60, 'g', 'dairy'),
        _ing('Kırmızı biber', 0.5, 'adet', 'produce'),
      ],
      steps: ['Peyniri ve biberi dilimle, birlikte ye.'],
    ),
    _snack(
      'Sıcak Çay + Simit Dilimi',
      moods: [FeedMood.salty, FeedMood.breadTop, FeedMood.comfort, FeedMood.quick],
      cal: 250,
      p: 8,
      c: 38,
      f: 7,
      mins: 5,
      method: 'stovetop',
      ings: [
        _ing('Simit', 0.5, 'adet', 'bakery'),
        _ing('Çay', 1, 'bardak', 'pantry'),
      ],
      steps: ['Çayı demle, simidi ısıtıp ye.'],
    ),
    _snack(
      'Ketçaplı Patates Küpleri (mikrodalga)',
      moods: [FeedMood.salty, FeedMood.comfort, FeedMood.quick],
      cal: 220,
      p: 4,
      c: 40,
      f: 5,
      mins: 9,
      method: 'other',
      ings: [
        _ing('Patates', 1, 'adet', 'produce'),
        _ing('Zeytinyağı', 1, 'tatlı kaşığı', 'pantry'),
        _ing('Ketçap', 1, 'yemek kaşığı', 'pantry'),
      ],
      steps: [
        'Patatesi küp doğra, yağla kapla.',
        'Mikrodalgada 6–7 dk pişir, ketçapla servis et.',
      ],
    ),
    _snack(
      'Cevizli İncir',
      moods: [FeedMood.sweet, FeedMood.cold, FeedMood.quick],
      cal: 160,
      p: 3,
      c: 26,
      f: 6,
      mins: 2,
      method: 'no_cook',
      ings: [
        _ing('Kuru incir', 2, 'adet', 'pantry'),
        _ing('Ceviz', 2, 'adet', 'pantry'),
      ],
      steps: ['İnciri aç, içine ceviz koy.'],
    ),
    _snack(
      'Sıcak Süt + Galeta',
      moods: [FeedMood.sweet, FeedMood.comfort, FeedMood.quick],
      cal: 210,
      p: 8,
      c: 28,
      f: 7,
      mins: 4,
      method: 'stovetop',
      ings: [
        _ing('Süt', 1, 'su bardağı', 'dairy'),
        _ing('Galeta', 2, 'adet', 'bakery'),
      ],
      steps: ['Sütü ısıt, galetayı batırarak ye.'],
    ),
  ];

  /// Keşfet için ekstra ana yemek çeşitleri (mock setine ek).
  static final List<Map<String, dynamic>> discoverExtras = [
    _meal(
      'Yoğurtlu Semizotu',
      MealType.lunch,
      cal: 180,
      p: 8,
      c: 12,
      f: 10,
      prep: 10,
      cook: 0,
      method: 'no_cook',
      ings: [
        _ing('Semizotu', 1, 'demet', 'produce'),
        _ing('Yoğurt', 1, 'kase', 'dairy'),
        _ing('Sarımsak', 1, 'diş', 'produce'),
      ],
      steps: ['Semizotunu yıka, yoğurt-sarımsak sosla karıştır.'],
    ),
    _meal(
      'Fırınlanmış Sebze Tabağı',
      MealType.dinner,
      cal: 260,
      p: 7,
      c: 30,
      f: 12,
      prep: 15,
      cook: 25,
      method: 'oven',
      ings: [
        _ing('Kabak', 1, 'adet', 'produce'),
        _ing('Patlıcan', 1, 'adet', 'produce'),
        _ing('Biber', 2, 'adet', 'produce'),
        _ing('Zeytinyağı', 2, 'yemek kaşığı', 'pantry'),
      ],
      steps: ['Sebzeleri doğra, yağla harmanla, 200°C 25 dk pişir.'],
    ),
    _meal(
      'Nohutlu Pilav',
      MealType.lunch,
      cal: 420,
      p: 14,
      c: 68,
      f: 10,
      prep: 10,
      cook: 25,
      method: 'stovetop',
      ings: [
        _ing('Pirinç', 1, 'su bardağı', 'pantry'),
        _ing('Haşlanmış nohut', 1, 'su bardağı', 'pantry'),
        _ing('Tereyağı', 1, 'yemek kaşığı', 'dairy'),
      ],
      steps: ['Pirinci kavur, nohut ve su ekle, pişir.'],
    ),
    _meal(
      'Çılbır',
      MealType.breakfast,
      cal: 290,
      p: 16,
      c: 8,
      f: 20,
      prep: 5,
      cook: 10,
      method: 'stovetop',
      ings: [
        _ing('Yumurta', 2, 'adet', 'dairy'),
        _ing('Yoğurt', 1, 'kase', 'dairy'),
        _ing('Tereyağı', 1, 'yemek kaşığı', 'dairy'),
        _ing('Pul biber', 1, 'tatlı kaşığı', 'pantry'),
      ],
      steps: [
        'Yumurtaları poşe et.',
        'Yoğurt üzerine koy, biberli tereyağı gezdir.',
      ],
    ),
    _meal(
      'Ispanaklı Omlet',
      MealType.breakfast,
      cal: 280,
      p: 18,
      c: 6,
      f: 20,
      prep: 5,
      cook: 8,
      method: 'stovetop',
      ings: [
        _ing('Yumurta', 3, 'adet', 'dairy'),
        _ing('Ispanak', 1, 'avuç', 'produce'),
        _ing('Zeytinyağı', 1, 'yemek kaşığı', 'pantry'),
      ],
      steps: ['Ispanakı sotele, yumurtayı ekle, omlet yap.'],
    ),
    _meal(
      'Kinoa Salata Kasesi',
      MealType.lunch,
      cal: 340,
      p: 12,
      c: 42,
      f: 12,
      prep: 15,
      cook: 15,
      method: 'stovetop',
      ings: [
        _ing('Kinoa', 0.5, 'su bardağı', 'pantry'),
        _ing('Salatalık', 1, 'adet', 'produce'),
        _ing('Domates', 1, 'adet', 'produce'),
        _ing('Limon', 0.5, 'adet', 'produce'),
      ],
      steps: ['Kinoayı haşla, sebzelerle karıştır, limon gezdir.'],
    ),
    _meal(
      'Somonlu Avokado Bowl',
      MealType.dinner,
      cal: 480,
      p: 32,
      c: 18,
      f: 30,
      prep: 10,
      cook: 12,
      method: 'stovetop',
      ings: [
        _ing('Somon fileto', 150, 'g', 'butcher'),
        _ing('Avokado', 0.5, 'adet', 'produce'),
        _ing('Pirinç', 0.5, 'su bardağı', 'pantry'),
      ],
      steps: ['Pirinci pişir, somonu tavada pişir, avokadoyla servis et.'],
    ),
    _meal(
      'Mercimek Köftesi',
      MealType.lunch,
      cal: 320,
      p: 14,
      c: 45,
      f: 8,
      prep: 20,
      cook: 20,
      method: 'stovetop',
      ings: [
        _ing('Kırmızı mercimek', 1, 'su bardağı', 'pantry'),
        _ing('İnce bulgur', 0.5, 'su bardağı', 'pantry'),
        _ing('Soğan', 1, 'adet', 'produce'),
      ],
      steps: ['Mercimeği haşla, bulgur ekle, soğanlı harçla yoğur, şekil ver.'],
    ),
    _meal(
      'Sebzeli Şakşuka',
      MealType.dinner,
      cal: 300,
      p: 8,
      c: 22,
      f: 20,
      prep: 15,
      cook: 25,
      method: 'stovetop',
      ings: [
        _ing('Patlıcan', 2, 'adet', 'produce'),
        _ing('Biber', 2, 'adet', 'produce'),
        _ing('Domates sosu', 1, 'su bardağı', 'pantry'),
      ],
      steps: ['Sebzeleri kızart, domates sosunda kaynat.'],
    ),
    _meal(
      'Tavuklu Wrap',
      MealType.lunch,
      cal: 390,
      p: 28,
      c: 32,
      f: 14,
      prep: 10,
      cook: 12,
      method: 'stovetop',
      ings: [
        _ing('Tavuk göğsü', 150, 'g', 'butcher'),
        _ing('Lavaş', 1, 'adet', 'bakery'),
        _ing('Yoğurt', 2, 'yemek kaşığı', 'dairy'),
      ],
      steps: ['Tavuğu sotele, yoğurtla lavasa sar.'],
    ),
    _meal(
      'Peynirli Gözleme',
      MealType.breakfast,
      cal: 360,
      p: 16,
      c: 40,
      f: 14,
      prep: 10,
      cook: 10,
      method: 'stovetop',
      ings: [
        _ing('Yufka', 1, 'adet', 'bakery'),
        _ing('Beyaz peynir', 80, 'g', 'dairy'),
        _ing('Maydanoz', 1, 'tutam', 'produce'),
      ],
      steps: ['Yufkaya peynir-maydanoz koy, katla, tavada pişir.'],
    ),
    _meal(
      'Zeytinyağlı Enginar',
      MealType.dinner,
      cal: 220,
      p: 5,
      c: 18,
      f: 14,
      prep: 15,
      cook: 30,
      method: 'stovetop',
      ings: [
        _ing('Enginar', 2, 'adet', 'produce'),
        _ing('Havuç', 1, 'adet', 'produce'),
        _ing('Bezelye', 0.5, 'su bardağı', 'produce'),
        _ing('Zeytinyağı', 3, 'yemek kaşığı', 'pantry'),
      ],
      steps: ['Sebzeleri zeytinyağında kısık ateşte pişir.'],
    ),
  ];

  static List<Map<String, dynamic>> allDiscoverSource() => [
        ...mockRecipeDataset,
        ...discoverExtras,
        ...snacks,
      ];

  static List<Map<String, dynamic>> pickSnacks({
    required int count,
    FeedMood mood = FeedMood.all,
    List<String> excludeTitles = const [],
    int? seed,
  }) {
    final rng = Random(seed ?? DateTime.now().millisecondsSinceEpoch);
    final want = count < 1 ? 1 : count;

    List<Map<String, dynamic>> filter({
      required bool applyExclude,
      required bool applyMood,
    }) {
      return snacks.where((e) {
        final title = e['title']?.toString() ?? '';
        if (applyExclude &&
            FeedVarietyStore.clashes(title, excludeTitles)) {
          return false;
        }
        if (!applyMood || mood == FeedMood.all) return true;
        final tags = (e['moods'] as List?)?.cast<String>() ?? const [];
        return tags.contains(mood.name);
      }).toList();
    }

    var pool = filter(applyExclude: true, applyMood: true);
    if (pool.length < want) {
      pool = filter(applyExclude: true, applyMood: false);
    }
    if (pool.isEmpty) {
      // Tüm başlıklar elenmişse çeşitlilik geçmişini yok say.
      pool = filter(applyExclude: false, applyMood: true);
    }
    if (pool.isEmpty) {
      pool = List.of(snacks);
    }

    final seen = <String>{};
    pool = [
      for (final e in pool)
        if (seen.add((e['title'] ?? '').toString().toLowerCase())) e,
    ];
    pool.shuffle(rng);
    final n = want > pool.length ? pool.length : want;
    return pool.take(n).toList();
  }

  static List<Map<String, dynamic>> pickDiscover({
    required int count,
    FeedMood mood = FeedMood.all,
    MealType? mealType,
    List<String> excludeTitles = const [],
    int? seed,
  }) {
    final rng = Random(seed ?? DateTime.now().millisecondsSinceEpoch);
    final want = count < 1 ? 1 : count;
    final source = allDiscoverSource();

    List<Map<String, dynamic>> filter({
      required bool applyExclude,
      required bool applyMood,
      required bool applyMeal,
    }) {
      return source.where((e) {
        final title = e['title']?.toString() ?? '';
        if (applyExclude &&
            FeedVarietyStore.clashes(title, excludeTitles)) {
          return false;
        }
        if (applyMeal && mealType != null) {
          final mt = (e['mealType'] as String?) ?? _inferMealType(e).name;
          if (mt != mealType.name) return false;
        }
        if (applyMood && !_matchesDiscoverMood(e, mood)) return false;
        return true;
      }).toList();
    }

    var pool = filter(applyExclude: true, applyMood: true, applyMeal: true);
    if (pool.length < want) {
      pool = filter(applyExclude: true, applyMood: false, applyMeal: true);
    }
    if (pool.isEmpty) {
      pool = filter(applyExclude: false, applyMood: true, applyMeal: true);
    }
    if (pool.isEmpty) {
      pool = filter(applyExclude: false, applyMood: false, applyMeal: false);
    }
    if (pool.isEmpty) {
      pool = List.of(source);
    }

    final seen = <String>{};
    pool = [
      for (final e in pool)
        if (seen.add((e['title'] ?? '').toString().toLowerCase())) e,
    ];
    pool.shuffle(rng);
    final n = want > pool.length ? pool.length : want;
    return pool.take(n).toList();
  }

  static bool _matchesDiscoverMood(Map<String, dynamic> e, FeedMood mood) {
    if (mood == FeedMood.all) return true;
    final tags = (e['moods'] as List?)?.cast<String>() ?? const [];
    if (tags.contains(mood.name)) return true;
    final total =
        ((e['prepTimeMinutes'] as num?)?.toInt() ?? 0) +
        ((e['cookTimeMinutes'] as num?)?.toInt() ?? 0);
    final cal = (e['nutrient'] is Map)
        ? ((e['nutrient'] as Map)['calories'] as num?)?.toInt() ?? 0
        : 0;
    switch (mood) {
      case FeedMood.quick:
        return total <= 25;
      case FeedMood.light:
        return cal > 0 && cal <= 320;
      case FeedMood.comfort:
        return cal >= 350;
      case FeedMood.sweet:
      case FeedMood.salty:
      case FeedMood.protein:
      case FeedMood.cold:
      case FeedMood.breadTop:
        return tags.contains(mood.name);
      case FeedMood.all:
        return true;
    }
  }

  static MealType _inferMealType(Map<String, dynamic> e) {
    final raw = e['mealType']?.toString();
    if (raw != null) return MealType.fromString(raw);
    final total =
        ((e['prepTimeMinutes'] as num?)?.toInt() ?? 0) +
        ((e['cookTimeMinutes'] as num?)?.toInt() ?? 0);
    if (total <= 12) return MealType.snack;
    return MealType.dinner;
  }

  static Map<String, dynamic> _snack(
    String title, {
    required List<FeedMood> moods,
    required int cal,
    required int p,
    required int c,
    required int f,
    required int mins,
    required String method,
    required List<Map<String, dynamic>> ings,
    required List<String> steps,
  }) {
    final prep = mins <= 3 ? mins : (mins ~/ 2);
    final cook = mins - prep;
    return {
      'title': title,
      'mealType': 'snack',
      'moods': moods.map((m) => m.name).toList(),
      'servings': 1,
      'prepTimeMinutes': prep,
      'cookTimeMinutes': cook,
      'cookingMethod': method,
      'nutrient': {'calories': cal, 'protein': p, 'carbs': c, 'fat': f},
      'ingredients': ings,
      'steps': steps,
      'keywords': [title.toLowerCase()],
    };
  }

  static Map<String, dynamic> _meal(
    String title,
    MealType mealType, {
    required int cal,
    required int p,
    required int c,
    required int f,
    required int prep,
    required int cook,
    required String method,
    required List<Map<String, dynamic>> ings,
    required List<String> steps,
  }) {
    return {
      'title': title,
      'mealType': mealType.name,
      'servings': 2,
      'prepTimeMinutes': prep,
      'cookTimeMinutes': cook,
      'cookingMethod': method,
      'nutrient': {'calories': cal, 'protein': p, 'carbs': c, 'fat': f},
      'ingredients': ings,
      'steps': steps,
      'keywords': [title.toLowerCase()],
    };
  }

  static Map<String, dynamic> _ing(
    String name,
    num qty,
    String unit,
    String category,
  ) =>
      {'name': name, 'quantity': qty, 'unit': unit, 'category': category};
}
