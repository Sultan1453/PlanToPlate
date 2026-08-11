/// "Lokal Yapay Zeka Veri Seti" (Mock AI Data).
///
/// Bu dosya, internete hiç bağlanmadan çalışan SAHTE (ama gerçekçi) bir AI
/// motorunun besleneceği 9 popüler yemeği içerir. Her yemek, gerçek Gemini
/// API'sinin İLERİDE (Adım 5'te) döneceği AYNI FORMATTA (JSON benzeri
/// `Map<String, dynamic>`) yazılmıştır. Bu kasıtlı bir tercih: format
/// bugünden itibaren sabit kalırsa, ileride mock motoru gerçek motorla
/// değiştirdiğimizde `Recipe.fromJson` fabrikasında HİÇBİR değişiklik
/// gerekmez.
///
/// Her yemek kaydında ekstra bir `keywords` alanı vardır (bu alan
/// `Recipe.fromJson` tarafından KULLANILMAZ, sadece bu dosyadaki eşleştirme
/// mantığı için vardır): kullanıcının yazdığı metinde bu kelimelerden biri
/// geçiyorsa, o yemek eşleşmiş sayılır. Bkz. `mock_recipe_ai_service.dart`.
///
/// NOT (fiyat/kalori gibi değerler): Buradaki besin değerleri ve süreler
/// GERÇEKÇİ TAHMİNLERDİR (referans amaçlı); gerçek Gemini API'sine
/// bağlandığımızda bu sayılar AI tarafından dinamik olarak hesaplanacak.
final List<Map<String, dynamic>> mockRecipeDataset = [
  {
    'keywords': ['menemen'],
    'title': 'Menemen',
    'servings': 2,
    'prepTimeMinutes': 10,
    'cookTimeMinutes': 15,
    'cookingMethod': 'stovetop',
    'nutrient': {'calories': 320, 'protein': 14, 'carbs': 12, 'fat': 24},
    'ingredients': [
      {'name': 'Domates', 'quantity': 3, 'unit': 'adet', 'category': 'produce'},
      {'name': 'Yeşil Biber', 'quantity': 2, 'unit': 'adet', 'category': 'produce'},
      {'name': 'Yumurta', 'quantity': 3, 'unit': 'adet', 'category': 'dairy'},
      {'name': 'Zeytinyağı', 'quantity': 2, 'unit': 'yemek kaşığı', 'category': 'pantry'},
      {'name': 'Tuz', 'quantity': 1, 'unit': 'tutam', 'category': 'pantry'},
    ],
    'steps': [
      'Zeytinyağını tavada kısık-orta ateşte ısıtın.',
      'Doğranmış yeşil biberleri ekleyip 3 dakika kavurun.',
      'Küp doğranmış domatesleri ekleyip suyunu çekene kadar (yaklaşık 8 dakika) pişirin.',
      'Yumurtaları kırıp karıştırarak veya kırıldığı gibi bırakarak pişirin.',
      'Tuzunu ekleyip sıcak servis edin.',
    ],
  },
  {
    'keywords': ['omlet'],
    'title': 'Sade Omlet',
    'servings': 1,
    'prepTimeMinutes': 5,
    'cookTimeMinutes': 5,
    'cookingMethod': 'stovetop',
    'nutrient': {'calories': 260, 'protein': 16, 'carbs': 3, 'fat': 20},
    'ingredients': [
      {'name': 'Yumurta', 'quantity': 3, 'unit': 'adet', 'category': 'dairy'},
      {'name': 'Süt', 'quantity': 2, 'unit': 'yemek kaşığı', 'category': 'dairy'},
      {'name': 'Tereyağı', 'quantity': 1, 'unit': 'yemek kaşığı', 'category': 'dairy'},
      {'name': 'Tuz', 'quantity': 1, 'unit': 'tutam', 'category': 'pantry'},
    ],
    'steps': [
      'Yumurtaları süt ve tuzla birlikte çatalla iyice çırpın.',
      'Tavada tereyağını orta ateşte eritin.',
      'Karışımı tavaya dökün, kenarları pişerken hafifçe kaldırıp ortasının da pişmesini sağlayın.',
      'İkiye katlayıp sıcak servis edin.',
    ],
  },
  {
    'keywords': ['mercimek corbasi', 'mercimek'],
    'title': 'Mercimek Çorbası',
    'servings': 4,
    'prepTimeMinutes': 10,
    'cookTimeMinutes': 30,
    'cookingMethod': 'stovetop',
    'nutrient': {'calories': 210, 'protein': 11, 'carbs': 32, 'fat': 4},
    'ingredients': [
      {'name': 'Kırmızı Mercimek', 'quantity': 1, 'unit': 'su bardağı', 'category': 'pantry'},
      {'name': 'Soğan', 'quantity': 1, 'unit': 'adet', 'category': 'produce'},
      {'name': 'Havuç', 'quantity': 1, 'unit': 'adet', 'category': 'produce'},
      {'name': 'Patates', 'quantity': 1, 'unit': 'adet', 'category': 'produce'},
      {'name': 'Tereyağı', 'quantity': 1, 'unit': 'yemek kaşığı', 'category': 'dairy'},
      {'name': 'Un', 'quantity': 1, 'unit': 'yemek kaşığı', 'category': 'pantry'},
      {'name': 'Tuz', 'quantity': 1, 'unit': 'tutam', 'category': 'pantry'},
    ],
    'steps': [
      'Soğanı tereyağında pembeleşene kadar kavurun.',
      'Unu ekleyip 1 dakika kavurmaya devam edin (kekleşmesini önlemek için sürekli karıştırın).',
      'Yıkanmış mercimek, doğranmış havuç ve patatesi ekleyip üzerini geçecek kadar su koyun.',
      'Sebzeler yumuşayana kadar (yaklaşık 25 dakika) kısık ateşte pişirin.',
      'Blenderdan geçirip pürüzsüz hale getirin, tuzunu ekleyip servis edin.',
    ],
  },
  {
    'keywords': ['tavuklu sebze sote', 'sebzeli tavuk', 'sote'],
    'title': 'Tavuklu Sebze Sote',
    'servings': 2,
    'prepTimeMinutes': 15,
    'cookTimeMinutes': 15,
    'cookingMethod': 'stovetop',
    'nutrient': {'calories': 380, 'protein': 38, 'carbs': 14, 'fat': 18},
    'ingredients': [
      {'name': 'Tavuk Göğsü', 'quantity': 300, 'unit': 'gram', 'category': 'butcher'},
      {'name': 'Brokoli', 'quantity': 1, 'unit': 'adet', 'category': 'produce'},
      {'name': 'Havuç', 'quantity': 1, 'unit': 'adet', 'category': 'produce'},
      {'name': 'Soğan', 'quantity': 1, 'unit': 'adet', 'category': 'produce'},
      {'name': 'Zeytinyağı', 'quantity': 2, 'unit': 'yemek kaşığı', 'category': 'pantry'},
      {'name': 'Soya Sosu', 'quantity': 1, 'unit': 'yemek kaşığı', 'category': 'pantry'},
    ],
    'steps': [
      'Tavuk göğsünü küp küp doğrayın.',
      'Zeytinyağını tavada kızdırıp tavuğu her tarafı beyazlaşana kadar (5 dakika) mühürleyin.',
      'Doğranmış sebzeleri ekleyip yüksek ateşte 6-7 dakika daha soteleyin.',
      'Soya sosunu ekleyip 1 dakika karıştırıp servis edin.',
    ],
  },
  {
    'keywords': ['firinda tavuk but', 'tavuk but', 'tavuk'],
    'title': 'Fırında Tavuk But',
    'servings': 4,
    'prepTimeMinutes': 15,
    'cookTimeMinutes': 40,
    'cookingMethod': 'oven',
    'nutrient': {'calories': 450, 'protein': 34, 'carbs': 22, 'fat': 26},
    'ingredients': [
      {'name': 'Tavuk But', 'quantity': 4, 'unit': 'adet', 'category': 'butcher'},
      {'name': 'Patates', 'quantity': 3, 'unit': 'adet', 'category': 'produce'},
      {'name': 'Zeytinyağı', 'quantity': 3, 'unit': 'yemek kaşığı', 'category': 'pantry'},
      {'name': 'Kekik', 'quantity': 1, 'unit': 'tatlı kaşığı', 'category': 'pantry'},
      {'name': 'Tuz', 'quantity': 1, 'unit': 'tutam', 'category': 'pantry'},
    ],
    'steps': [
      'Fırını 200°C\'ye ısıtın.',
      'Tavuk butları ve dilimlenmiş patatesleri zeytinyağı, kekik ve tuzla harmanlayın.',
      'Fırın tepsisine tek sıra halinde dizin.',
      '35-40 dakika, arada bir çevirerek, üzeri altın rengi olana kadar pişirin.',
    ],
  },
  {
    'keywords': ['izgara kofte', 'kofte'],
    'title': 'Izgara Köfte',
    'servings': 4,
    'prepTimeMinutes': 20,
    'cookTimeMinutes': 15,
    'cookingMethod': 'grill',
    'nutrient': {'calories': 320, 'protein': 28, 'carbs': 6, 'fat': 22},
    'ingredients': [
      {'name': 'Kıyma', 'quantity': 400, 'unit': 'gram', 'category': 'butcher'},
      {'name': 'Soğan', 'quantity': 1, 'unit': 'adet', 'category': 'produce'},
      {'name': 'Ekmek İçi', 'quantity': 1, 'unit': 'dilim', 'category': 'bakery'},
      {'name': 'Tuz', 'quantity': 1, 'unit': 'tutam', 'category': 'pantry'},
      {'name': 'Karabiber', 'quantity': 1, 'unit': 'tutam', 'category': 'pantry'},
    ],
    'steps': [
      'Soğanı rendeleyip suyuyla birlikte kıymaya ekleyin.',
      'Ufalanmış ekmek içi, tuz ve karabiberi ekleyip harcı iyice yoğurun.',
      'Harcı 30 dakika buzdolabında dinlendirin, sonra köfte şekli verin.',
      'Izgarada veya ızgara tavasında her yüzünü 4-5 dakika pişirin.',
    ],
  },
  {
    'keywords': ['karniyarik'],
    'title': 'Karnıyarık',
    'servings': 4,
    'prepTimeMinutes': 25,
    'cookTimeMinutes': 35,
    'cookingMethod': 'oven',
    'nutrient': {'calories': 410, 'protein': 22, 'carbs': 18, 'fat': 28},
    'ingredients': [
      {'name': 'Patlıcan', 'quantity': 4, 'unit': 'adet', 'category': 'produce'},
      {'name': 'Kıyma', 'quantity': 300, 'unit': 'gram', 'category': 'butcher'},
      {'name': 'Soğan', 'quantity': 1, 'unit': 'adet', 'category': 'produce'},
      {'name': 'Domates', 'quantity': 2, 'unit': 'adet', 'category': 'produce'},
      {'name': 'Yeşil Biber', 'quantity': 2, 'unit': 'adet', 'category': 'produce'},
      {'name': 'Zeytinyağı', 'quantity': 4, 'unit': 'yemek kaşığı', 'category': 'pantry'},
    ],
    'steps': [
      'Patlıcanları soyup şeritler halinde soyarak (alaca) kızgın yağda hafifçe kızartın.',
      'Kıymayı soğanla kavurup doğranmış domates ve biberle iç harcı hazırlayın.',
      'Patlıcanları fırın tepsisine dizip ortalarını yararak iç harcı doldurun.',
      'Üzerine domates dilimi koyup 180°C fırında 30-35 dakika pişirin.',
    ],
  },
  {
    'keywords': ['sebzeli makarna', 'makarna'],
    'title': 'Sebzeli Makarna',
    'servings': 3,
    'prepTimeMinutes': 10,
    'cookTimeMinutes': 15,
    'cookingMethod': 'stovetop',
    'nutrient': {'calories': 390, 'protein': 15, 'carbs': 58, 'fat': 12},
    'ingredients': [
      {'name': 'Makarna', 'quantity': 250, 'unit': 'gram', 'category': 'pantry'},
      {'name': 'Brokoli', 'quantity': 1, 'unit': 'adet', 'category': 'produce'},
      {'name': 'Havuç', 'quantity': 1, 'unit': 'adet', 'category': 'produce'},
      {'name': 'Mısır', 'quantity': 1, 'unit': 'su bardağı', 'category': 'pantry'},
      {'name': 'Zeytinyağı', 'quantity': 2, 'unit': 'yemek kaşığı', 'category': 'pantry'},
      {'name': 'Kaşar Peyniri', 'quantity': 50, 'unit': 'gram', 'category': 'dairy'},
    ],
    'steps': [
      'Makarnayı tuzlu suda paketindeki süreye göre haşlayın.',
      'Sebzeleri zeytinyağında 5-6 dakika soteleyin.',
      'Süzülmüş makarnayı sebzelerle karıştırın.',
      'Üzerine rendelenmiş kaşar peynirini serpip sıcak servis edin.',
    ],
  },
  {
    'keywords': ['ton balikli salata', 'salata', 'ton balik'],
    'title': 'Ton Balıklı Salata',
    'servings': 2,
    'prepTimeMinutes': 10,
    'cookTimeMinutes': 0,
    'cookingMethod': 'no_cook',
    'nutrient': {'calories': 280, 'protein': 24, 'carbs': 12, 'fat': 16},
    'ingredients': [
      {'name': 'Ton Balığı (konserve)', 'quantity': 1, 'unit': 'kutu', 'category': 'pantry'},
      {'name': 'Marul', 'quantity': 1, 'unit': 'adet', 'category': 'produce'},
      {'name': 'Domates', 'quantity': 1, 'unit': 'adet', 'category': 'produce'},
      {'name': 'Mısır', 'quantity': 3, 'unit': 'yemek kaşığı', 'category': 'pantry'},
      {'name': 'Zeytinyağı', 'quantity': 2, 'unit': 'yemek kaşığı', 'category': 'pantry'},
      {'name': 'Limon', 'quantity': 1, 'unit': 'adet', 'category': 'produce'},
    ],
    'steps': [
      'Marulu didikleyip, domatesi küp küp doğrayın.',
      'Süzülmüş ton balığı ve mısırı ekleyin.',
      'Zeytinyağı ve limon suyuyla harmanlayıp servis edin.',
    ],
  },
];
